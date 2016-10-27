require 'spec_helper'

module Singularity
  describe Deployer do
    before {
      @deployer = Deployer.new(@test_url, @test_file, @test_release)
    }


    context 'when request is paused' do
      before {
        WebMock.stub_request(:get, /.*/).
          to_return(:body => '{"state":"PAUSED"}')
      }
      it 'should check if the request is paused' do
        expect(WebMock).to have_requested(:get, @test_url+'/api/requests/request/'+@test_id)
      end

      it 'should not make any POST requests' do
        expect(WebMock).should_not have_requested(:post, /.*/)
      end
    end

    context 'when request is not paused' do

    end

  end
end
