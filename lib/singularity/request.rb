module Singularity
  class Request
    attr_accessor :release, :cpus, :mem, :envs, :schedule, :cmd, :arguments, :request_id, :repo, :release_string, :release_id_string

    def initialize(uri, data_id)
      @uri = uri
      @data_id = data_id
    end

    def is_paused(uri, data_id)
      resp = RestClient.get "#{@uri}/api/requests/request/#{@data_id}"
      if (JSON.parse(resp)['state'] != 'PAUSED')
        print ' Deploying request...'.light_green
        false
      else
        true
      end
    end

    def get_binding
      binding()
    end
  end
end
