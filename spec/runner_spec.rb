require 'spec_helper'

module Singularity
  describe Runner do
    before(:each) {
      allow(File).to receive(:read).with('.mescal.json').and_return('{"image":"registry.example.com:r01","sshCmd":"/home/user/bootstrap-sshd.sh","cpus":1,"mem":512.0}')
      WebMock.stub_request(:post, /.*/)
      WebMock.stub_request(:delete, /.*/)
    }

    describe "#waitForTaskToShowUp" do
      before {
        @commands = ['ls', '-a']
        @runner = Runner.new(@commands, @uri)
        stub_get_tasks(@runner)
        @runner.request.data['requestId'] = @runner.request.data['id']
        @runner.waitForTaskToShowUp
      }
      it "should get the task list" do
        expect(WebMock).to have_requested(:get, @uri+'/api/tasks/active')
      end

      it "should have the correct IP" do
        expect(@runner.ip).to eq('127.0.0.1')
      end

      it "should have the correct port" do
        expect(@runner.port).to eq('80')
      end
    end

    context 'when executing commands on the box' do
      before {
        @commands = ['ls', '-a']
        @runner = Runner.new(@commands, @uri)
        stub_get_tasks(@runner)
        stub_get_task_state(@runner)
        stub_STDOUT_output(@runner)
        stub_STDERR_output(@runner)
        stub_is_paused(@runner.request, "RUNNING")
        @runner.run
      }
      describe "#run" do
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
          expect(WebMock).to have_requested(:delete, @uri+"/api/requests/request/"+@runner.request.data['requestId'])
        end
      end
    end

    context 'when executing commands on the box' do
      before {
        @commands = ['runx', 'ls', '-a']
        @runner = Runner.new(@commands, @uri)
        stub_get_tasks(@runner)
        stub_get_task_state(@runner)
        stub_STDOUT_output(@runner)
        stub_STDERR_output(@runner)
        stub_is_paused(@runner.request, "RUNNING")
        @runner.run
      }
      describe "#run" do
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
          expect(WebMock).to have_requested(:delete, @uri+"/api/requests/request/"+@runner.request.data['requestId'])
        end
      end
    end

    # context 'when SSHing into the box' do
    #   before {
    #     @commands = ['ssh']
    #     @runner = Runner.new(@commands, @uri)
    #     @runner.run
    #   }
    #   describe "#run" do
    #     it "should create the request" do
    #       expect(WebMock).to have_requested(:post, @uri+"/api/requests")
    #     end
    #     it "should deploy the request" do
    #       expect(WebMock).to have_requested(:post, @uri+"/api/api/deploys")
    #     end

    #     # it "should open a shell to the box" do

    #     # end

    #     it "should delete the request after complete" do
    #       expect(WebMock).to have_requested(:delete, @uri+"/api/requests/request/"+@runner.request.data['id'])
    #     end
    #   end
    # end
  end
end
