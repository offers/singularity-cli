require 'spec_helper'

module Singularity
  describe Deleter do
    before(:each) {
      @deleter = Deleter.new
      WebMock.stub_request(:delete, /.*/)
    }
    describe "#delete" do
      it "should delete the request" do
        response = @deleter.delete
        expect(WebMock).to have_requested(:delete, $uri+'/api/requests/request/'+$file.gsub(/\.\/singularity\//, "").gsub(/\.json/, ""))
      end
    end
  end
end
