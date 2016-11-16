require 'spec_helper'

module Singularity
  describe Runner do
    before(:each) {
      @commands = ['ls', '-a']
      allow(File).to receive(:read).with('.mescal.json').and_return('{"image":"registry.example.com:r01","sshCmd":"/home/user/bootstrap-sshd.sh","cpus":1,"mem":512.0}')
      @runner = Runner.new(@commands, @uri)
      @request = Request.new(@data, @uri, @release)
    }

    describe "#waitForTaskToShowUp" do
      before {
        @request.data['requestId'] = @id
        WebMock.stub_request(:get, /.*/).to_return(:body => ["{'taskRequest':{'request':{'id':\"#{@id}\"}}}"].to_json)
        @runner.waitForTaskToShowUp
      }
      it "should get the task list" do
        expect(WebMock).to have_requested(:get, @uri+'/api/tasks/active')
      end
    end

    # context 'when executing commands on the box' do

    # end

    # context 'when skipping the use of /sbin/my_init' do

    # end

    # context 'when SSHing into the box' do

    # end

  end
end
