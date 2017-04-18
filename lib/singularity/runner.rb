module Singularity
  class Runner
    attr_accessor :request, :ip, :port, :thisIsANewRequest, :thisTask, :projectName

    def initialize(commands, uri)
      @commands = commands
      @uri = uri
      @ip = 0
      @port = 0
      @thisTask = ''
      @thisIsANewRequest = true

      mescaljson = JSON.parse(File.read('.mescal.json'))
      @cpus = mescaljson['cpus']
      @mem = mescaljson['mem']
      @image = mescaljson['image']

      @projectName = @image.split('/').last
      user = (ENV['SINGULARITY_USER'] || `whoami`).chomp

      # establish 'id', 'command', and 'args' for filling in the data hash below
      case @commands[0]
        when 'ssh'
          # the 'command' becomes 'run the ssh bootstrap script'
          commandId = 'SSH'
          command = "#{mescaljson['sshCmd']}"
        when 'runx'
          # if 'runx' is passed, skip use of /sbin/my_init
          commandId = @commands.join('-').tr('@/\*?% []#$', '-')
          @commands.shift
          command = @commands.shift
          @args = []
          @setargs = true
          @commands.each { |i| @args.push i }
        else
          # else join /sbin/my_init with your commands
          commandId = @commands.join('-').tr('@/\*?% []#$', '-')
          command = '/sbin/my_init'
          @args = ['--']
          @setargs = true
          @commands.each { |i| @args.push i }
      end

      # create request/deploy json data
      data = {
        'id' => "#{@projectName}_#{commandId}_#{user}_#{Time.now.to_i.to_s}",
        'command' => "#{command}",
        'resources' => {
          'memoryMb' => @mem,
          'cpus' => @cpus,
          'numPorts' => 1
        },
        'env' => {
          'APPLICATION_ENV' => 'production'
        },
        'requestType' => 'RUN_ONCE',
        'containerInfo' => {
          'type' => 'DOCKER',
          'docker' => {
            'image' => @image,
            'network' => 'BRIDGE',
            'portMappings' => [{
              'containerPortType' => 'LITERAL',
              'containerPort' => 22,
              'hostPortType' => 'FROM_OFFER',
              'hostPort' => 0
            }]
          }
        }
      }
      if @setargs
        data['arguments'] = @args
      end
      @request = Request.new(data, @uri, @image.split(':')[1])
    end

    def run
      exit_code = 0
      if @thisIsANewRequest
        @request.create
        @request.deploy
        waitForTaskToShowUp
      end
      getIPAndPort

      if @commands[0] == 'ssh'
        runSsh
      else
        exit_code = runCmd
      end
    rescue Exception
      puts $!.red
      exit_code = 1
    ensure
      @request.delete rescue nil
      return exit_code
    end

    protected

    def waitForTaskToShowUp
      # repeatedly poll API for active tasks until ours shows up so we can get IP/PORT for SSH
      begin
        @tasks = JSON.parse(RestClient.get "#{@uri}/api/tasks/active", :content_type => :json)

        @tasks.each do |entry|
          if entry['taskRequest']['request']['id'] == @request.data['requestId']
            @thisTask = entry
          end
        end
      end until @thisTask != ''
    end

    def getIPAndPort
      @ip = @thisTask['offer']['url']['address']['ip']
      @port = @thisTask['mesosTask']['container']['docker']['portMappings'][0]['hostPort']
    end

    def runSsh
      puts " Opening a shell to ".light_blue + @projectName.yellow + " (root@#{@ip}:#{@port}), please wait a moment...".light_blue
      cmd = "ssh -o LogLevel=error -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@#{@ip} -p #{@port}"

      # wait for sshd to come online
      loop do
        break if Util.port_open?(@ip, @port)
        sleep 0.25
      end

      system(cmd)
    end

    #
    # Returns an exit code (0 for success, 1 for failure)
    #
    def runCmd
      puts " Deployed and running #{@request.data['command']} #{@request.data['arguments']}".light_green
      print ' STDOUT'.light_cyan + ' and' + ' STDERR'.light_magenta + ":\n"

      # offset (place saving) variables
      @stdoutOffset = 0
      @stderrOffset = 0
      begin
        # get most recent task state
        # need to wait for "task_running" before we can ask for STDOUT/STDERR
        @taskState = JSON.parse(RestClient.get "#{@uri}/api/history/task/#{@thisTask['taskId']['id']}")
        @taskState["taskUpdates"].each do |update|
          @taskState = update['taskState']
        end
        if @taskState == "TASK_FAILED"
          return 1 # failure
        end
        if @taskState == "TASK_RUNNING"
          sleep 1
          # print stdout
          @stdout = JSON.parse(RestClient.get "#{@uri}/api/sandbox/#{@thisTask['taskId']['id']}/read", {params: {path: "stdout", length: 30000, offset: @stdoutOffset}})['data']
          outLength = @stdout.bytes.to_a.size
          if @stdout.length > 0
            print @stdout.light_cyan
            @stdoutOffset += outLength
          end
          # print stderr
          @stderr = JSON.parse(RestClient.get "#{@uri}/api/sandbox/#{@thisTask['taskId']['id']}/read", {params: {path: "stderr", length: 30000, offset: @stderrOffset}})['data']
          errLength = @stderr.bytes.to_a.size
          if @stderr.length > 0
            print @stderr.light_magenta
            @stderrOffset += errLength
          end
        end
      end until @taskState == "TASK_FINISHED"

      return 0 # success
    end

  end
end
