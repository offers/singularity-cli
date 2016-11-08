require 'spec_helper'

module Singularity
  describe Deployer do
    before {
      @deployer = Deployer.new
      $request = Request.new
    }

    context 'when request is paused' do
      before {
        WebMock.stub_request(:get, /.*/).to_return(:body => '{"state":"PAUSED"}')
        WebMock.stub_request(:post, /.*/)
        @deployer.deploy
      }

      it 'should check if the request is paused' do
        expect(WebMock).to have_requested(:get, $uri+'/api/requests/request/'+$id)
      end

      it 'should not make any POST requests' do
        expect(WebMock).not_to have_requested(:post, /.*/)
      end
    end

    context 'when request is NOT paused' do
      before {
        WebMock.stub_request(:get, /.*/).to_return(:body => '{"state":"RUNNING"}')
        WebMock.stub_request(:post, /.*/)
        @hash = @deployer.deploy
      }
      it 'should check if the request is paused' do
        expect(WebMock).to have_requested(:get, $uri+'/api/requests/request/'+$id)
      end

      it 'should create or update the request' do
        expect(WebMock).to have_requested(:post, $uri+'/api/requests').
          with(body: hash_including({'id' => $id}))
      end

      it 'should deploy the request' do
        expect(WebMock).to have_requested(:post, $uri+'/api/deploys').
          with(body: hash_including({'user' => `whoami`.chomp}))
      end

    end

  end
end
