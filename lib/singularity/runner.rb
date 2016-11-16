module Singularity
  class Runner
    def initialize(commands, uri)
      @commands = commands
      @uri = uri
      @projectName = Dir.pwd.split('/').last

      mescaljson = JSON.parse(File.read('.mescal.json'))
      @cpus = mescaljson['cpus']
      @mem = mescaljson['mem']
      @image = mescaljson['image']

      # establish 'id', 'command', and 'args' for filling in the data hash below
      case @commands[0]
        when 'ssh'
          # the 'command' becomes 'run the ssh bootstrap script'
          commandId = @projectName + '_SSH'
          command = "#{mescaljson['sshCmd']}"
        when 'runx'
          # if 'runx' is passed, skip use of /sbin/my_init
          commandId = @commands.join('_').tr('@/\*?% []#$', '_')
          @commands.shift
          command = @commands[0]
          @args = []
          @commands.each { |i| @args.push i }
        else
          # else join /sbin/my_init with your commands
          commandId = @commands.join('_').tr('@/\*?% []#$', '_')
          command = '/sbin/my_init'
          @args = ['--']
          @setargs = true
          @commands.each { |i| @args.push i }
      end

      # create request/deploy json data
      data = {
        'id' => "#{commandId}",
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

    def waitForTaskToShowUp
      # repeatedly poll API for active tasks until ours shows up so we can get IP/PORT for SSH
      begin
        @thisTask = ''
        @tasks = JSON.parse(RestClient.get "#{@uri}/api/tasks/active", :content_type => :json)
        @tasks.each do |entry|
          puts "hi".red
          puts "hi".red
          puts "@request.data['requestId']: " + @request.data['requestId']
          puts "entry['taskRequest']['request']['id']: "+entry['taskRequest']['request']['id']
          puts "hi".red
          puts "hi".red
          if entry['taskRequest']['request']['id'] == @request.data['requestId']
            @thisTask = entry
          end
        end
      end until @thisTask != ''
      @ip = @thisTask['offer']['url']['address']['ip']
      @port = @thisTask['mesosTask']['container']['docker']['portMappings'][0]['hostPort']
    end

    def run
      @request.create
      @request.deploy
      waitForTaskToShowUp()
      # SSH into the machine
      if @commands[0] == 'ssh'
        puts " Opening a shell to #{@projectName}, please wait a moment...".light_blue
        # 'begin end until' makes sure that the image has completely started so the SSH command succeeds
        begin end until system "ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@#{@ip} -p #{@port}"
      else
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
          if @taskState == "TASK_RUNNING"
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
      end

      @request.delete

    rescue Exception => e
      puts " #{e.response}".red
    end
  end
end
