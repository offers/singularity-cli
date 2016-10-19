require 'spec_helper'

module Singularity
  describe Deleter do
    before(:each) {
      @deleter = Deleter.new(@test_url, @file)
    }
    describe "#delete" do
      it "should delete the request" do
        response = @deleter.delete
        expect(WebMock).to have_requested(:delete, @test_url+'/api/requests/request/'+@file.gsub(/\.\/singularity\//, "").gsub(/\.json/, ""))
      end
    end
  end
end
