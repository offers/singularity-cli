require 'erb'
require 'json'
require 'rest-client'
require 'colorize'
require 'yaml'

module Singularity
  class Request
    attr_accessor :release, :cpus, :mem, :envs, :schedule, :cmd, :arguments, :request_id, :repo, :release_string, :release_id_string
    def get_binding
      binding()
    end
  end

  class Deployer
    def initialize(uri, file, release)
      @uri = uri
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
        resp = RestClient.get "#{@uri}/api/requests/request/#{@data['id']}"
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

  class Deleter
    def initialize(uri, file)
      @uri = uri
      @file = file
    end
    # Deleter.delete -- arguments are <uri>, <file>
    def delete
      begin
        task_id = "#{@file}".gsub(/\.\/singularity\//, "").gsub(/\.json/, "")
        # delete the request
        RestClient.delete "#{@uri}/api/requests/request/#{task_id}"
        puts "#{task_id} DELETED"
      rescue
        puts "#{task_id} #{$!.response}"
      end
    end
  end

  class Runner
    def initialize(script)
      # check to see that .mescal.json and mesos-deploy.yml exist
      #
      # TODO
      #

      # read .mescal.json for ssh command, image, release number, cpus, mem
      @mescalData = JSON.parse(ERB.new(open(File.join(Dir.pwd, ".mescal.json")).read).result(Request.new.get_binding))
      @sshCmd = @mescalData['sshCmd']
      @image = @mescalData['image'].split(':')[0]
      @release = @mescalData['image'].split(':')[1]

      # read mesos-deploy.yml for singularity url
      @mesosDeployConfig = YAML.load_file(File.join(Dir.pwd, "mesos-deploy.yml"))
      @uri = @mesosDeployConfig['singularity_url']

      # create request/deploy json data

      @data = {
        'command' => "/sbin/my_init",
        'resources' => {
          'mem' => @mescalData['mem'],
          'cpus' => @mescalData['cpus']
          'numPorts' => 0
        },
        'env' => {
          'APPLICATION_ENV' => "production"
        },
        'containerInfo' => {
          'type' => "DOCKER",
          'docker' => {
            'image' => @mescalData['image']
          }
        }
      }
      # args are either the the ssh command or the script/commands passed to 'singularity run'
      if script == "ssh"
        @data['id'] = "ssh"
        @data['command'] = "#{@sshCmd}"
      else
        @data['id'] = script.join("_")
        @data['arguments'] = ["--"]
        script.each { |i| @data['arguments'].push i }
      end
    end

    def is_paused
      begin
        resp = RestClient.get "#{@uri}/api/requests/request/#{@data['id']}"
        JSON.parse(resp)['state'] == 'PAUSED'
      rescue
        print " CREATING...".blue
        false
      end
    end

    def runner
      begin
        if is_paused()
          puts " PAUSED, SKIPPING".yellow
          return
        else
          # create or update the request
          @data['requestType'] = "RUN_ONCE"
          resp = RestClient.post "#{@uri}/api/requests", @data.to_json, :content_type => :json
        end

        # deploy the request
        @data['requestId'] = @data['id']
        @data['id'] = "#{@release}.#{Time.now.to_i}"
        @deploy = {
         'deploy' => @data,
         'user' => `whoami`.chomp,
         'unpauseOnSuccessfulDeploy' => false
        }
        puts @data.to_json
        puts @deploy.to_json
        resp = RestClient.post "#{@uri}/api/deploys", @deploy.to_json, :content_type => :json
        puts "hi again"

        puts " Deployed and running #{@script}".green
        # the line below needs to be changed to call the output from the API and print it to the calling console
        #
        # TODO
        #
        puts " Task will exit after script is complete, check #{@uri} for the output."
      rescue Exception => e
        puts " #{e.response}".red
      end
    end
  end
end
