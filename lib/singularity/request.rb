module Singularity
  class Request
    attr_accessor :release, :cpus, :mem, :envs, :schedule, :cmd, :arguments, :request_id, :repo, :release_string, :release_id_string

    def is_paused(data_id)
      return JSON.parse(RestClient.get "#{$uri}/api/requests/request/#{data_id}")['state'] == 'PAUSED'
    end

    def get_binding
      binding()
    end
  end
end
