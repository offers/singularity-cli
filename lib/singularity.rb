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
      #########################################################
      # TODO
      # check to see that .mescal.json and mesos-deploy.yml exist
      #########################################################
      @script = script
      # read .mescal.json for ssh command, image, release number, cpus, mem
      @configData = JSON.parse(ERB.new(open(File.join(Dir.pwd, ".mescal.json")).read).result(Request.new.get_binding))
      @sshCmd = @configData['sshCmd']
      @image = @configData['image'].split(':')[0]
      @release = @configData['image'].split(':')[1]

      # read mesos-deploy.yml for singularity url
      @mesosDeployConfig = YAML.load_file(File.join(Dir.pwd, "mesos-deploy.yml"))
      @uri = @mesosDeployConfig['singularity_url']

      # create request/deploy json data
      @data = {
        'command' => "/sbin/my_init",
        'resources' => {
          'memoryMb' => @configData['mem'],
          'cpus' => @configData['cpus'],
          'numPorts' => 0
        },
        'env' => {
          'APPLICATION_ENV' => "production"
        },
        'containerInfo' => {
          'type' => "DOCKER",
          'docker' => {
            'image' => @configData['image'],
            'network' => "BRIDGE",
            'portMappings' => [{
              'containerPortType': "LITERAL",
              'containerPort': 22,
              'hostPortType': "LITERAL",
              'hostPort': 2200
            }]
          }
        }
      }
      # either we typed 'singularity ssh'
      if @script == "ssh"
        @data['id'] = Dir.pwd.split('/').last + "_SSH"
        @data['command'] = "#{@sshCmd}"
      # or we passed a script/commands to 'singularity run'
      else 
        # if we passed "runx", then skip use of /sbin/my_init
        if @script[0] == "runx"
          @data['arguments'] = [] # don't use "--" as first argument
          @data['command'] = @script[1] #remove "runx" from commands
          @script.shift
          @data['id'] = @script.join("_").tr('@/\*?% []#$', '_')
          @data['id'][0] = ''
          @script.shift
        else
          @data['arguments'] = ["--"]
          @data['id'] = @script.join("_").tr('@/\*?% []#$', '_')
          @data['id'][0] = ''
        end 
        @script.each { |i| @data['arguments'].push i }
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
        resp = RestClient.post "#{@uri}/api/deploys", @deploy.to_json, :content_type => :json
        resp = JSON.parse(resp)
        puts "DEPLOY POST:".red
        puts resp
        
        tasks = RestClient.get "#{@uri}/api/history/request/#{@data['requestId']}/tasks"
        tasks = JSON.parse(tasks)
        puts "tasks[0]:".red
        puts tasks[0]

        reqtasks = RestClient.get "#{@uri}/api/tasks/scheduled/request/#{@data['requestId']}"
        reqtasks = JSON.parse(reqtasks)
        puts "Scheduled tasks for #{@data['requestId']}".red
        puts reqtasks

        # SSH into box & delete task afterward
        if @script == "ssh"
          ip = 
          port = 2200
          exec "ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@#{ip} -p #{port}"
          RestClient.delete "#{@uri}/api/requests/request/#{@data['requestId']}"
        else
          # or provide link to task in browser so we can see output
          puts " Deployed and running #{@script}".green
          #########################################################
          # TODO: the line below needs to be changed to call the output from the API and print it to the calling console
          #########################################################
          puts " Task will exit after script is complete, check the link below for the output."
          puts " #{@uri}/request/#{@data['requestId']}".light_blue
          puts ""
        end

        ########################################################
        # NEED TO DELETE THE REQUEST AFTER ALL OF THIS IS OVER
        # have to figure out how to confirm that it completed first
        # the above SSH line (Restclient.delete) can be taken away if we figure out how to confirm task complete via API
        ########################################################
        # puts "DELETED REQUEST: ".yellow
        # puts RestClient.delete "#{@uri}/api/requests/request/#{@data['requestId']}" 

      rescue Exception => e
        puts " #{e.response}".red
      end
    end
  end
end
