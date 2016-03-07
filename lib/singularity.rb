require 'erb'
require 'restclient'
require 'json'
require 'colorize'

module Singularity
  class Request
    attr_accessor :release, :cpus, :mem, :envs, :schedule, :cmd, :arguments, :request_id, :repo, :release_string, :release_id_string

    def get_binding
      binding()
    end
  end

  class Deployer

    def initialize(file, release)
      @file = file
      @release = release
      @config = ERB.new(open(file).read)
      @r = Request.new
      @r.release = @release
      @data = JSON.parse(@config.result(@r.get_binding))
      print @data['id']
    end


    def is_paused
      begin
        resp = RestClient.get "http://singularity.starfleet/singularity/api/requests/request/#{@data['id']}"
        JSON.parse(resp)['state'] == 'PAUSED'
      rescue
        print " CREATING...".blue
        false
      end
    end


    def deploy
      begin
        if is_paused()
          puts " PAUSED, SKIPPING".yellow
          exit
        else
          # create or update the request
          resp = RestClient.post "http://singularity.starfleet/singularity/api/requests", @data.to_json, :content_type => :json
        end
        
        # deploy the request
        @data['requestId'] = @data['id']
        @data['id'] = "#{@release}.#{Time.now.to_i}"
        deploy = {
         'deploy' => @data,
         'user' => `whoami`.chomp,
         'unpauseOnSuccessfulDeploy' => false
        }

        resp = RestClient.post "http://singularity.starfleet/singularity/api/deploys", deploy.to_json, :content_type => :json

        puts " DEPLOYED".green
      rescue Exception => e
        puts " #{e.response}".red
      end
    end
  end
end