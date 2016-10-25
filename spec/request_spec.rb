require 'spec_helper'

module Singularity
  describe Request do
    before(:each) {
      @request = Request.new(@test_url,@test_id)
    }

    context 'when paused' do
      WebMock.stub_request(:get, @test_url).
        to_return(body: hash_including({state: 'PAUSED'}))

      @response = @request.is_paused

      it "should make a GET request" do
        expect(WebMock).to have_requested(:get, @test_url+'/api/requests/request/'+@test_id)
      end
      it "should find PAUSED == true" do
        expect(response).to equal(true)
      end 
    end

    context 'when not paused' do
      WebMock.stub_request(:get, @test_url).
        to_return(body: hash_including({state: 'RUNNING'}))

      @response = @request.is_paused
      
      it "should make a GET request" do
        expect(WebMock).to have_requested(:get, @test_url+'/api/requests/request/'+@test_id)
      end
      it "should find PAUSED == false" do
        expect(response).to equal(false)
      end
    end

  end
end
