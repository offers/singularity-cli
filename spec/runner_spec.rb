require 'spec_helper'

# override the Kernel.system call for testing purposes
module Kernel
  def system(cmd)
    puts "The test kernel called: #{cmd}"
    return true
  end
end

module Singularity
  describe Runner do
    before(:each) {
      allow(File).to receive(:read).with('.mescal.json').and_return('{"image":"registry.example.com/department/projectname:r01","sshCmd":"/home/user/bootstrap-sshd.sh","cpus":1,"mem":512.0}')
      WebMock.stub_request(:post, /.*/)
      WebMock.stub_request(:delete, /.*/)
    }

    describe "#waitForTaskToShowUp" do
      before {
        @commands = ['ls', '-a']
        @runner = Runner.new(@commands, @uri)
        stub_get_tasks(@runner)
        @runner.request.data['requestId'] = @runner.request.data['id']
        @runner.send(:waitForTaskToShowUp)
      }
      it "should get the task list" do
        expect(WebMock).to have_requested(:get, @uri+'/api/tasks/active')
      end

      it "should have the correct IP" do
        expect(@runner.ip).to eq('127.0.0.1')
      end

      it "should have the correct port" do
        expect(@runner.port).to eq(80)
      end
    end

    describe "#run" do
      context 'when executing a command that fails' do
        before {
          @commands = ['ls', '-a']
          @runner = Runner.new(@commands, @uri)
          stub_get_tasks(@runner)
          stub_get_task_state_failed(@runner)
          stub_STDOUT_output(@runner)
          stub_STDERR_output(@runner)
          stub_is_paused(@runner.request, "RUNNING")
          @exit_code = @runner.run
        }

        it "should return a failure error code" do
          expect(@exit_code).to eq(1)
        end

        it "should delete the request after it fails" do
          expect(WebMock).to have_requested(:delete, @uri+"/api/requests/request/"+@runner.request.data['requestId']).once
        end
      end

      context 'when an exception occurs' do
        it "should output the exception message"
        # do
        #   dbl = double
        #   allow(dbl).to receive(:foo).and_raise("EXPLODING KITTENS!")
        #   dbl.foo
        # end
      end

      context 'when executing successful commands on the container' do
        before {
          @commands = ['ls', '-a']
          @runner = Runner.new(@commands, @uri)
          stub_get_tasks(@runner)
          stub_get_task_state(@runner)
          stub_STDOUT_output(@runner)
          stub_STDERR_output(@runner)
          stub_is_paused(@runner.request, "RUNNING")
          @exit_code = @runner.run
        }

        it "should return a success error code" do
          expect(@exit_code).to eq(0)
        end

        it "should create the request" do
          expect(WebMock).to have_requested(:post, @uri+"/api/requests")
        end
        it "should deploy the request" do
          expect(WebMock).to have_requested(:post, @uri+"/api/deploys")
        end

        it "should check if task is running" do
          expect(WebMock).to have_requested(:get, @uri+"/api/history/task/"+@runner.request.data['requestId']).twice
        end

        it "should get STDOUT and STDERR text" do
          expect(WebMock).to have_requested(:get, /.*sandbox.*read/).twice
        end

        it "should delete the request after complete" do
          expect(WebMock).to have_requested(:delete, @uri+"/api/requests/request/"+@runner.request.data['requestId']).once
        end
      end

      context 'when executing commands on the container as SINGULARITY_USER' do
        before {
          ENV['SINGULARITY_USER'] = 'testuser'
          @commands = ['runx', 'ls', '-a']
          @runner = Runner.new(@commands, @uri)
          stub_get_tasks(@runner)
          stub_get_task_state(@runner)
          stub_STDOUT_output(@runner)
          stub_STDERR_output(@runner)
          stub_is_paused(@runner.request, "RUNNING")
          @runner.run
        }

        it "should create the request" do
          expect(WebMock).to have_requested(:post, @uri+"/api/requests")
        end

        context "when creating the request" do
          it "should put the project name, tag, SINGULARITY_USER, and timestamp in the id" do
            expect(@runner.request.data['requestId']).to match(/projectname:r01_runx-ls--a_#{ENV['SINGULARITY_USER']}_[0-9]{10}/)
          end
        end

        it "should deploy the request" do
          expect(WebMock).to have_requested(:post, @uri+"/api/deploys")
        end

        it "should check if task is running" do
          expect(WebMock).to have_requested(:get, @uri+"/api/history/task/" + @runner.request.data['requestId']).twice
        end

        it "should get STDOUT and STDERR text" do
          expect(WebMock).to have_requested(:get, /.*sandbox.*read/).twice
        end

        it "should delete the request after complete" do
          expect(WebMock).to have_requested(:delete, @uri + "/api/requests/request/" + @runner.request.data['requestId']).once
        end
      end

      context 'when executing commands on the container as `whoami`' do
        before {
          ENV['SINGULARITY_USER'] = nil
          @commands = ['runx', 'ls', '-a']
          @runner = Runner.new(@commands, @uri)
          stub_get_tasks(@runner)
          stub_get_task_state(@runner)
          stub_STDOUT_output(@runner)
          stub_STDERR_output(@runner)
          stub_is_paused(@runner.request, "RUNNING")
          @runner.run
        }

        context "when creating the request" do
          it "should put the project name, tag, username, and timestamp in the id" do
            username = `whoami`.chomp
            @runner.run
            expect(@runner.request.data['requestId']).to match(/projectname:r01_runx-ls--a_#{username}_[0-9]{10}/)
          end
        end
      end

      context 'when SSHing into the container' do
        before {
          @commands = ['ssh']
          @runner = Runner.new(@commands, @uri)
          stub_get_tasks(@runner)
          stub_is_paused(@runner.request, "RUNNING")
          allow(Util).to receive(:port_open?).and_return(true)
          @runner.run
        }

        it "should create the request" do
          expect(WebMock).to have_requested(:post, @uri+"/api/requests")
        end
        it "should deploy the request" do
          expect(WebMock).to have_requested(:post, @uri+"/api/deploys")
        end

        it "should open a shell to the container" do
          @runner.request.data['id'] = @runner.request.data['requestId']
          expect{@runner.run}.to output(/test kernel/).to_stdout
        end

        it "should delete the request after complete" do
          expect(WebMock).to have_requested(:delete, @uri+"/api/requests/request/" + @runner.request.data['requestId'])
        end
      end
    end
  end
end
