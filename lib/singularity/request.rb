module Singularity
  class Request
    attr_accessor :release, :cpus, :mem, :envs, :schedule, :cmd, :arguments, :request_id, :repo, :release_string, :release_id_string

    def initialize(data, file, uri)
      @data = data
      @file = file
      @uri = uri

    end

    def deploy
      if is_paused
        puts ' PAUSED, SKIPPING.'
        return
      else
        @data['requestId'] = @data['id']
        @data['id'] = "#{@mescaljson['image'].split(':')[1]}.#{Time.now.to_i}"
        @deploy = {
         'deploy' => @data,
         'user' => `whoami`.chomp,
         'unpauseOnSuccessfulDeploy' => false
        }
        # deploy the request
        RestClient.post "#{$uri}/api/deploys", @deploy.to_json, :content_type => :json
        puts ' Deploy succeeded.'.green
      end
    end

    def delete

    end

    def is_paused
      return JSON.parse(RestClient.get "#{$uri}/api/requests/request/#{data_id}")['state'] == 'PAUSED'
    end

    def get_binding
      binding()
    end
  end
end
