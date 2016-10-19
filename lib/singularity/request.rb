module Singularity
  class Request
    attr_accessor :release, :cpus, :mem, :envs, :schedule, :cmd, :arguments, :request_id, :repo, :release_string, :release_id_string

    def is_paused(uri, data_id)
      begin
        resp = RestClient.get "#{uri}/api/requests/request/#{data_id}"
        JSON.parse(resp)['state'] == 'PAUSED'
      rescue
        print ' Deploying request...'.light_green
        false
      end
    end

    def get_binding
      binding()
    end
  end
end
