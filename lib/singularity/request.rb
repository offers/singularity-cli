module Singularity
  class Request
    attr_accessor :release, :cpus, :mem, :envs, :schedule, :cmd, :arguments, :request_id, :repo, :release_string, :release_id_string, :uri, :singularityRequest, :singularityDeploy

    def initialize(singularityRequest, singularityDeploy, uri, release)
      @singularityRequest = singularityRequest
      @singularityDeploy = singularityDeploy
      @uri = uri
      @release = release
    end

    # checks to see if a request is paused
    def is_paused
      return JSON.parse(RestClient.get "#{@uri}/api/requests/request/#{@singularityRequest['id']}")['state'] == 'PAUSED'
    end

    # creates or updates a request in singularity
    def create
      RestClient.post "#{@uri}/api/requests", @singularityRequest.to_json, :content_type => :json
    end

    # deletes a request in singularity
    def delete
      RestClient.delete "#{@uri}/api/requests/request/#{@singularityDeploy['requestId']||@singularityDeploy['id']}"
      puts ' Deleted request: '.red + "#{@singularityDeploy['requestId']||@singularityDeploy['id']}".light_blue
    end

    # deploys a request in singularity
    def deploy
      if is_paused
        puts ' PAUSED, SKIPPING.'
        return
      else
        @singularityDeploy['requestId'] = @singularityDeploy['id']
        @singularityDeploy['id'] = "#{@release}.#{Time.now.to_i}"
        @singularityDeploy['containerInfo']['docker']['image'] =
          File.exist?('dcos-deploy/config.yml') ?
            YAML.load_file(File.join(Dir.pwd, 'dcos-deploy/config.yml'))['repo']+":#{@release}" :
            "#{JSON.parse(File.read('.mescal.json'))['image'].split(':').first}:#{@release}"
        @deploy = {
         'deploy' => @singularityDeploy,
         'user' => `whoami`.chomp,
         'unpauseOnSuccessfulDeploy' => false
        }
        # deploy the request
        RestClient.post "#{@uri}/api/deploys", @deploy.to_json, :content_type => :json
        puts ' Deploy succeeded: '.green + @singularityDeploy['requestId'].light_blue
      end
    end

  end
end
