# module Singularity
#   class Deleter
#     def initialize(uri, file)
#       @uri = uri
#       @file = file
#     end
#     # Deleter.delete -- arguments are <uri>, <file>
#     def delete
#       begin
#         task_id = "#{@file}".gsub(/\.\/singularity\//, "").gsub(/\.json/, "")
#         # delete the request
#         RestClient.delete "#{@uri}/api/requests/request/#{task_id}"
#         puts "#{task_id} DELETED"
#       rescue
#         puts "#{task_id} #{$!.response}"
#       end
#     end
#   end
# end

###############################################
require 'spec_helper'

# @uri = 'http://singularity.ocean/singularity'
# @file = 'test-post-run-once.json'

module Singularity
  describe Deleter do
    deleter = Deleter.new(@uri, @file)
    describe "#delete" do
      it "should delete the request" do
        stub_request(:delete, "http://singularity.ocean/singularity/api/requests/request/test-post-run-once").
         with(:headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => "", :headers => {})

        response = RestClient.delete('http://singularity.ocean/singularity/api/requests/request/test-post-run-once')
        expect(response).to be_an_instance_of(String)
      end
    end

  end
end
