require 'spec_helper'

module Singularity
  describe Request do
    before(:each) {
      @request = Request.new(@test_url,@test_id)
    }

    context 'when paused' do
      stub_request(:get, @test_url).
        to_return(body: hash_including({state: 'PAUSED'}))
      it "should find paused == true" do
        response = @request.is_paused
        expect(WebMock).to have_requested(:get, @test_url+'/api/requests/request/'+@test_id))
        expect(response).to equal(true)
      end
    end

    context 'when not paused' do
      stub_request(:get, @test_url).
        to_return(body: hash_including({state: 'RUNNING'}))
      it "should find paused == false" do
        response = @request.is_paused
        expect(WebMock).to have_requested(:get, @test_url+'/api/requests/request/'+@test_id))
        expect(response).to equal(false)
      end
    end

  end
end
