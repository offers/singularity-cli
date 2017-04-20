module Singularity
  class Request
    attr_accessor :release, :cpus, :mem, :envs, :schedule, :cmd, :arguments, :request_id, :repo, :release_string, :release_id_string, :uri, :data

    def initialize(data, uri, release)
      @data = data
      @uri = uri
      @release = release
    end

    # checks to see if a request is paused
    def is_paused
      return JSON.parse(RestClient.get "#{@uri}/api/requests/request/#{@data['id']}")['state'] == 'PAUSED'
    end

    # creates or updates a request in singularity
    def create
      RestClient.post "#{@uri}/api/requests", @data.to_json, :content_type => :json
    end

    # deletes a request in singularity
    def delete
      RestClient.delete "#{@uri}/api/requests/request/#{@data['requestId']||@data['id']}"
      puts ' Deleted request: '.red + "#{@data['requestId']||@data['id']}".light_blue
    end

    # deploys a request in singularity
    def deploy
      if is_paused
        puts ' PAUSED, SKIPPING.'
        return
      else
        @data['requestId'] = @data['id']
        @data['id'] = "#{@release}.#{Time.now.to_i}"
        @data['containerInfo']['docker']['image'] = "#{JSON.parse(File.read('.mescal.json'))['image'].split(':').first}:#{@release}"
        @deploy = {
          'deploy' => @data,
          'user' => `whoami`.chomp,
          'unpauseOnSuccessfulDeploy' => false
        }
        # deploy the request
        RestClient.post "#{@uri}/api/deploys", @deploy.to_json, :content_type => :json
        puts ' Deploy succeeded: '.green + @data['requestId'].light_blue
      end
    end

    def list_ssh
      activeTasksList = JSON.parse(RestClient.get "#{@uri}/api/tasks/active", :content_type => :json)

      taskId = ''

      count = 0
      activeTasksList.each do |entry|
        taskId = entry['taskRequest']['request']['id']
        if taskId.include?("SSH")
          ip = entry['offer']['url']['address']['ip']
          port = entry['mesosTask']['container']['docker']['portMappings'][0]['hostPort']

          puts "#{count+1}: ".light_green + "#{taskId}: ".light_blue + "root".yellow + " @ ".light_blue + "#{ip}".light_magenta + " : ".light_blue + "#{port}".light_cyan
          count = count + 1
        end
      end

      if count == 0
        puts "There were no running SSH sessions on #{@uri.split("/")[1]}"
        exit 0
      end

      puts "Would you like to (k)ill or (c)onnect to any of these sessions? (x to exit)"
      resp = STDIN.gets.chomp

      while !['x','k','kill','c','con','conn','connect'].include?(resp)
        puts "Incorrect input, please enter c, k, or x"
        resp = STDIN.gets.chomp
      end

      case resp
      when 'x'
        puts 'Exiting...'.light_magenta
        exit 0
      when 'k','kill'
        puts 'Please enter a comma-separated list of which numbers from the above list you would like to kill (or x to exit)'
        killList = STDIN.gets.chomp
        if killList == 'x'
          exit 0
        end
        killList = killList.delete(' ').split(',')
        killList.each do |task_index|
          thisTask = activeTasksList[task_index.to_i-1]
          puts '!! '.red + 'Are you sure you want to KILL ' + "#{thisTask['taskId']['requestId']}".red + '? (y/n)' + ' !!'.red
          if STDIN.gets.chomp == 'y'
            RestClient.delete "#{@uri}/api/requests/request/#{thisTask['taskId']['requestId']}"
            puts ' KILLED and DELETED: '.red + "#{thisTask['taskId']['requestId']}".light_blue
          end
        end
      when 'c','con','conn','connect'
        taskIndex = -1

        def getTaskIndex
          n = 0
          while n <= 0
            puts 'Please enter session number to SSH into from the above list (or x to exit)'
            n = STDIN.gets.chomp
            n == 'x' ? (puts "Exiting..."; exit 0) : (n = Integer(n))
          end
          return n-1
        end

        def pickTask
          taskIndex = getTaskIndex

          puts "SSH into #{activeTasksList[taskIndex]['taskId']['requestId']}? (y = yes, p = pick another task number, or x = exit)"
          input = STDIN.gets.chomp

          while !["x","y","p"].include?(input)
            puts "Please enter: y, p, or x"
            input = STDIN.gets.chomp
          end

          case input
          when 'x'
            puts "Exiting..."
            exit 0
          when 'p'
            pickTask
          when 'y'
            puts "Just a moment... connecting you to the instance."
          end

        end

        pickTask

        # create fresh Runner, which normally creates a new request when it runs
        # so we assign values to it to "turn it into" our currently running SSH task
        runner = Singularity::Runner.new('ssh', @uri)
        runner.thisIsANewRequest = false # so that we don't create & deploy a new request
        runner.thisTask = activeTasksList[taskIndex]
        runner.projectName = activeTasksList[taskIndex]['taskId']['requestId']
        # then run it, which only does getIPAndPort and runSsh
        runner.run
      end
    end
  end
end
