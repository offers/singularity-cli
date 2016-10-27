require 'spec_helper'

module Singularity
  describe Deleter do
    before(:each) {
      @deleter = Deleter.new(@test_url, @test_file)
      WebMock.stub_request(:delete, /.*/)
    }
    describe "#delete" do
      it "should delete the request" do
        response = @deleter.delete
        expect(WebMock).to have_requested(:delete, @test_url+'/api/requests/request/'+@test_file.gsub(/\.\/singularity\//, "").gsub(/\.json/, ""))
      end
    end
  end
end
