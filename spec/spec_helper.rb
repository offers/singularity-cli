require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

$:.unshift(File.dirname(__FILE__) + '/../lib/')
require 'singularity'

RSpec.configure do |config|
  config.before(:all) do
    @uri = 'www.example.com'
    @file = 'TestRequest.json'
    @id = 'testId'
    @release = 'r01'
  end
  config.before(:each) do
    @data = {'id' => @id}
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
