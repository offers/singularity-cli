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

  def stub_get_tasks(runner)
    WebMock.stub_request(:get, @uri+"/api/tasks/active").
      to_return(:body => ["{\"taskId\": {\"id\": \"#{runner.request.data['id']}\"},\"taskRequest\": {\"request\": {\"id\":\"#{runner.request.data['id']}\"}},\"offer\":{\"url\":{\"address\":{\"ip\":\"127.0.0.1\"}}},\"mesosTask\":{\"container\":{\"docker\":{\"portMappings\":[{\"hostPort\":\"80\"}]}}}}"].to_json, :headers => {"Content-Type"=> "application/json"})
  end

  def stub_get_task_state(runner)
    WebMock.stub_request(:get, @uri+"/api/history/task/"+runner.request.data['id']).to_return(
      {:body => {"taskUpdates":[{"taskState": "TASK_RUNNING"}]}.to_json},
      {:body => {"taskUpdates":[{"taskState": "TASK_FINISHED"}]}.to_json})
  end

  def stub_STDOUT_output(runner)
    WebMock.stub_request(:get, /.*sandbox.*stdout/).to_return({:body => {"data": "test stdout output\n"}.to_json, :headers => {"Content-Type"=> "application/json"}},{:body => {"data": ""}.to_json, :headers => {"Content-Type"=> "application/json"}})
  end

  def stub_STDERR_output(runner)
    WebMock.stub_request(:get, /.*sandbox.*stderr/).to_return({:body => {"data": "test stderr output\n"}.to_json, :headers => {"Content-Type"=> "application/json"}},{:body => {"data": ""}.to_json, :headers => {"Content-Type"=> "application/json"}})
  end

  def stub_is_paused(request, state)
    WebMock.stub_request(:get, @uri+"/api/requests/request/"+request.data['id']).to_return(:body => "{\"state\":\"#{state}\"}")
  end
end
