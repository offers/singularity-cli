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
          'numPorts' => 1
        },
        'env' => {
          'APPLICATION_ENV' => "production"
        },
        'requestType' => "RUN_ONCE",
        'containerInfo' => {
          'type' => "DOCKER",
          'docker' => {
            'image' => @configData['image'],
            'network' => "BRIDGE",
            'portMappings' => [{
              'containerPortType': "LITERAL",
              'containerPort': 22,
              'hostPortType': "FROM_OFFER",
              'hostPort': 0
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
          @data['id'] = @script.join("-").tr('@/\*?% []#$', '_')
          @data['id'][0] = ''
          @script.shift
        # else join /sbin/my_init with your commands
        else
          @data['arguments'] = ["--"]
          @data['id'] = @script.join("-").tr('@/\*?% []#$', '_')
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
        print " Deploying request...".light_green
        false
      end
    end

    def runner
      begin
        if is_paused()
          puts " PAUSED, SKIPPING.".yellow
          return
        else
          # create or update the request
          RestClient.post "#{@uri}/api/requests", @data.to_json, :content_type => :json
        end

        # deploy the request
        @data['requestId'] = @data['id']
        @data['id'] = "#{@release}.#{Time.now.to_i}"
        @deploy = {
         'deploy' => @data,
         'user' => `whoami`.chomp,
         'unpauseOnSuccessfulDeploy' => false
        }
        RestClient.post "#{@uri}/api/deploys", @deploy.to_json, :content_type => :json
        puts " Deploy succeeded.".green

        # get active tasks until ours shows up so we can get IP/PORT
        begin
          @thisTask = ''
          @tasks = RestClient.get "#{@uri}/api/tasks/active", :content_type => :json
          @tasks = JSON.parse(@tasks)
          @tasks.each do |entry|
            if entry['taskRequest']['request']['id'] == @data['requestId']
              @thisTask = entry
            end
          end
        end until @thisTask != ''
        @ip = @thisTask['offer']['url']['address']['ip']
        @port = @thisTask['mesosTask']['container']['docker']['portMappings'][0]['hostPort']

        # SSH into the machine
        if @script == "ssh"
          # uses "begin end until" because "system" will keep returning "false" unless the command exits with success
          # this makes sure that the docker image has completely started and the SSH command succeeds
          where = Dir.pwd.split('/').last
          puts " Opening a shell to #{where}, please wait a moment...".light_blue
          puts " STDOUT / STDERR will print to console when session is over.".light_blue
          begin end until system "ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@#{@ip} -p #{@port}"
        else
          puts " Deployed and running #{@data['command']} #{@data['arguments']}".light_green
        end

        # need to wait for "task_finished" or "task_running & ssh" before we can ask for STDOUT/STDERR
        begin
          @taskState = RestClient.get "#{@uri}/api/history/task/#{@thisTask['taskId']['id']}"
          @taskState = JSON.parse(@taskState)
          @taskState["taskUpdates"].each do |update|
            @taskState = update['taskState']
          end
        end until @taskState == "TASK_FINISHED" || (@taskState == "TASK_RUNNING" and @script == "ssh")

        # output STDOUT / STDERR to shell
        puts ""
        stdout = RestClient.get "#{@uri}/api/sandbox/#{@thisTask['taskId']['id']}/read", {params: {path: "stdout", length: 30000, offset: 0}}
        stdout = JSON.parse(stdout)
        puts "stdout: ".cyan
        puts stdout['data'].light_cyan
        stderr = RestClient.get "#{@uri}/api/sandbox/#{@thisTask['taskId']['id']}/read", {params: {path: "stderr", length: 30000, offset: 0}}
        stderr = JSON.parse(stderr)
        puts "stderr: ".red
        puts stderr['data'].light_magenta

        # finally, delete the request (which also deletes the corresponding task)
        RestClient.delete "#{@uri}/api/requests/request/#{@data['requestId']}"

      rescue Exception => e
        puts " #{e.response}".red
      end
    end
  end
end
