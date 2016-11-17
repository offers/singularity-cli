require 'spec_helper'

module Singularity
  describe Runner do
    before(:each) {
      allow(File).to receive(:read).with('.mescal.json').and_return('{"image":"registry.example.com:r01","sshCmd":"/home/user/bootstrap-sshd.sh","cpus":1,"mem":512.0}')

    }

    describe "#waitForTaskToShowUp" do
      before {
        WebMock.stub_request(:get, /.*/).to_return(:body => ["{\"taskRequest\": {\"request\": {\"id\":\"#{@runner.request.data['id']}\"}},\"offer\":{\"url\":{\"address\":{\"ip\":\"127.0.0.1\"}}},\"mesosTask\":{\"container\":{\"docker\":{\"portMappings\":[{\"hostPort\":\"80\"}]}}}}"].to_json, :headers => {"Content-Type"=> "application/json"})
        @commands = ['ls', '-a']
        @runner = Runner.new(@commands, @uri)
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
      }
      describe "#run" do

      end
    end

    context 'when skipping the use of /sbin/my_init' do
      before {
        @commands = ['runx', 'ls', '-a']
        @runner = Runner.new(@commands, @uri)
      }
      describe "#run" do

      end
    end

    context 'when SSHing into the box' do
      before {
        @commands = ['ssh']
        @runner = Runner.new(@commands, @uri)
      }
      describe "#run" do

      end
    end

  end
end
