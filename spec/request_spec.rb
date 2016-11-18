require 'spec_helper'

module Singularity
  describe Request do
    before {
      @request = Request.new(@data, @uri, @release)
    }

    describe '#is_paused' do
      before {
        stub_is_paused(@request, "PAUSED")
        @request.is_paused
      }
      it "should check if the request is paused" do
        expect(WebMock).to have_requested(:get, @uri+'/api/requests/request/'+@id)
      end
    end

    describe '#create' do
      before {
        WebMock.stub_request(:post, /.*/)
        @request.create
      }

      it 'should have created a request' do
        expect(WebMock).to have_requested(:post, @uri+'/api/requests').
          with(body: hash_including({'id' => @id}))
      end
    end

    describe '#delete' do
      before {
        WebMock.stub_request(:delete, /.*/)
        @request.delete
      }
      it 'should delete the request' do
        expect(WebMock).to have_requested(:delete, @uri+'/api/requests/request/'+@id)
      end
    end

    context 'when paused' do
      before {
        stub_is_paused(@request, "PAUSED")
        WebMock.stub_request(:post, /.*/)
        @response = @request.is_paused
        @request.deploy
      }

      it "should check if the request is paused" do
        expect(WebMock).to have_requested(:get, @uri+'/api/requests/request/'+@id).twice
      end

      it "should find PAUSED == true" do
        expect(@response).to equal(true)
      end

      it "should not have deployed the request" do
        expect(WebMock).not_to have_requested(:post, /.*/)
      end

    end

    context 'when not paused' do
      before {
        stub_is_paused(@request, "RUNNING")
        WebMock.stub_request(:post, /.*/)
        @response = @request.is_paused
        @request.deploy
      }

      it "should check if the request is paused" do
        expect(WebMock).to have_requested(:get, @uri+'/api/requests/request/'+@id).twice
      end

      it "should find PAUSED == false" do
        expect(@response).to equal(false)
      end

      it 'should deploy the request' do
        expect(WebMock).to have_requested(:post, @uri+'/api/deploys').
          with(body: hash_including({'user' => `whoami`.chomp}))
      end

    end

  end
end
