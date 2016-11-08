require 'spec_helper'

module Singularity
  describe Runner do
    ################
    before(:each) {
      @runner = Runner.new
      WebMock.stub_request(:delete, /.*/)
    }
    #-------------
    describe "#delete" do
      it "should " do

      end
    end


    #-------------
    ################
  end
end
