require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

$:.unshift(File.dirname(__FILE__) + '/../lib/')
require 'singularity'

RSpec.configure do |config|
  config.before(:all) do
    @test_url = 'www.example.com'
    @file = 'TestRequest.json'
    WebMock.stub_request(:get, /.*/).
      to_return(:status => 200, :body => "", :headers => {})
    WebMock.stub_request(:post, /.*/).
      to_return(:status => 200, :body => "", :headers => {})
    WebMock.stub_request(:delete, /.*/).
      to_return(:status => 200, :body => "", :headers => {})
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
