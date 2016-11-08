module Singularity
  class Runner
    def initialize(commands)
      @commands = commands
      # establish 'id', 'command', and 'args' for filling in the @data hash below
      commandId = @commands.join('-').tr('@/\*?% []#$', '_')
      args = ''
      case @commands[0]
        when 'ssh'
          # the command becomes running the ssh bootstrap script
          commandId = @directoryName + '_SSH'
          command = "#{@mescaljson['sshCmd']}"
        when 'runx'
          # if 'runx' is passed, skip use of /sbin/my_init
          command = @commands[1]
          @commands.shift.each { |i| args.push i }
        else
          # else join /sbin/my_init with your commands
          command = '/sbin/my_init'
          args = '--'
          @commands.each { |i| args.push i }
      end

      # create request/deploy json data
      @data = {
        'id' => "#{commandId}",
        'command' => "#{command}",
        'arguments' => "#{args}",
        'resources' => {
          'memoryMb' => @mescaljson['mem'],
          'cpus' => @mescaljson['cpus'],
          'numPorts' => 1
        },
        'env' => {
          'APPLICATION_ENV' => 'production'
        },
        'requestType' => 'RUN_ONCE',
        'containerInfo' => {
          'type' => 'DOCKER',
          'docker' => {
            'image' => @mescaljson['image'],
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
    end

    def waitForTaskToShowUp
      # repeatedly poll API for active tasks until ours shows up so we can get IP/PORT for SSH
      begin
        @thisTask = ''
        @tasks = JSON.parse(RestClient.get "#{$uri}/api/tasks/active", :content_type => :json)
        @tasks.each do |entry|
          if entry['taskRequest']['request']['id'] == @data['requestId']
            @thisTask = entry
          end
        end
      end until @thisTask != ''
      @ip = @thisTask['offer']['url']['address']['ip']
      @port = @thisTask['mesosTask']['container']['docker']['portMappings'][0]['hostPort']
    end

    def createRequest
      RestClient.post "#{$uri}/api/requests", @data.to_json, :content_type => :json
    end

    def deployRequest

    end

    def deleteRequest
      RestClient.delete "#{$uri}/api/requests/request/#{@data['requestId']}"
    end

    def printOutput(source, offset, color)
      @output = JSON.parse(RestClient.get "#{$uri}/api/sandbox/#{@thisTask['taskId']['id']}/read",
        {params: {path: source, length: 30000, offset: offset}})['data']
      outLength = @output.bytes.to_a.size
      if @output.length > 0
        color == 'light_cyan' ? print @output.light_cyan : print @output.light_magenta
        offset += outLength
      end
    end

    def run
      if $request.is_paused(@data['id'])
        puts ' PAUSED, SKIPPING.'.yellow
        return
      end

      createRequest()
      deployRequest()
      waitForTaskToShowUp()

      # SSH into the machine
      if @commands == 'ssh'
        puts " Opening a shell to #{@directoryName}, please wait a moment...".light_blue
        # 'begin end until' makes sure that the image has completely started so the SSH command succeeds
        begin end until system "ssh -o LogLevel=quiet -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@#{@ip} -p #{@port}"
      else
        puts " Deployed and running #{@data['command']} #{@data['arguments']}".light_green
        print ' STDOUT'.light_cyan + ' and' + ' STDERR'.light_magenta + ":\n"

        # offset (place saving) variables
        @stdoutOffset = 0
        @stderrOffset = 0
        begin
          # gets most recent task state & wait for "TASK_RUNNING" before we can ask for STDOUT/STDERR
          @taskState = JSON.parse(RestClient.get "#{$uri}/api/history/task/#{@thisTask['taskId']['id']}")
          @taskState['taskUpdates'].each do |update|
            @taskState = update['taskState']
          end
          if @taskState == 'TASK_RUNNING'
            printOutput('stdout', @stdoutOffset, 'light_cyan')
            printOutput('stderr', @stderrOffset, 'light_magenta')
          end
        end until @taskState == 'TASK_FINISHED'
      end

      deleteRequest()

    rescue Exception => e
      puts " #{e.response}".red
    end
  end
end
