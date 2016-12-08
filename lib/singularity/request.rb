module Singularity
  class Request
    attr_accessor :release, :cpus, :mem, :envs, :schedule, :cmd, :arguments, :request_id, :repo, :release_string, :release_id_string, :uri, :data

    def initialize(data, uri, release)
      @data = data
      @uri = uri
      @release = release
    end

    # checks to see if a request is paused
    def is_paused
      return JSON.parse(RestClient.get "#{@uri}/api/requests/request/#{@data['id']}")['state'] == 'PAUSED'
    end

    # creates or updates a request in singularity
    def create
      RestClient.post "#{@uri}/api/requests", @data.to_json, :content_type => :json
    end

    # deletes a request in singularity
    def delete
      RestClient.delete "#{@uri}/api/requests/request/#{@data['requestId']||@data['id']}"
      puts ' Deleted request: '.red + "#{@data['requestId']||@data['id']}".light_blue
    end

    # deploys a request in singularity
    def deploy
      if is_paused
        puts ' PAUSED, SKIPPING.'
        return
      else
        @data['requestId'] = @data['id']
        @data['id'] = "#{@release}.#{Time.now.to_i}"
        @deploy = {
         'deploy' => @data,
         'user' => `whoami`.chomp,
         'unpauseOnSuccessfulDeploy' => false
        }
        # deploy the request
        RestClient.post "#{@uri}/api/deploys", @deploy.to_json, :content_type => :json
        puts ' Deploy succeeded: '.green + @data['requestId'].light_blue
      end
    end

  end
end
