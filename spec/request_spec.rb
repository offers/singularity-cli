require 'spec_helper'

module Singularity
  describe Request do
    before {
      @request = Request.new(@test_url)
    }

    context 'when paused' do
      before {
        WebMock.stub_request(:get, /.*/).
          to_return(:body => '{"state":"PAUSED"}')
        @response = @request.is_paused(@test_id)
      }

      it "should make a GET request" do
        expect(WebMock).to have_requested(:get, @test_url+'/api/requests/request/'+@test_id)
      end
      it "should find PAUSED == true" do
        expect(@response).to equal(true)
      end
    end

    context 'when not paused' do
      before {
        WebMock.stub_request(:get, /.*/).
          to_return(:body => '{"state":"RUNNING"}')
        @response = @request.is_paused(@test_id)
      }

      it "should make a GET request" do
        expect(WebMock).to have_requested(:get, @test_url+'/api/requests/request/'+@test_id)
      end
      it "should find PAUSED == false" do
        expect(@response).to equal(false)
      end
    end

  end
end
