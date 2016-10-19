module Singularity
  class Deployer
    def initialize(uri, file, release)
      @uri = uri
      @config = ERB.new(open(file).read)
      @request = Request.new
      @request.release = release
      @data = JSON.parse(@config.result(@request.get_binding))
      print @data['id']
    end

    def deploy
      begin
        if @request.is_paused(@uri, @data['id'])
          puts " PAUSED, SKIPPING".yellow
          return
        else
          # create or update the request
          resp = RestClient.post "#{@uri}/api/requests", @data.to_json, :content_type => :json
        end
        # deploy the request
        @data['requestId'] = @data['id']
        @data['id'] = "#{@release}.#{Time.now.to_i}"
        deploy = {
         'deploy' => @data,
         'user' => `whoami`.chomp,
         'unpauseOnSuccessfulDeploy' => false
        }
        resp = RestClient.post "#{@uri}/api/deploys", deploy.to_json, :content_type => :json
        puts " DEPLOYED".green
      rescue Exception => e
        puts " #{e.response}".red
      end
    end
  end
end
