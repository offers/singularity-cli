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

    def list_ssh
      activeTasksList = JSON.parse(RestClient.get "#{@uri}/api/tasks/active", :content_type => :json)

      count = 1
      activeTasksList.each do |entry|
        taskId = entry['taskRequest']['request']['id']
        if taskId.include?("SSH")
          ip = entry['offer']['url']['address']['ip']
          port = entry['mesosTask']['container']['docker']['portMappings'][0]['hostPort']

          puts "#{count}: ".light_green + "#{taskId}: ".light_blue + "root".yellow + " @ ".light_blue + "#{ip}".light_magenta + " : ".light_blue + "#{port}".light_cyan
          count = count + 1
        end
      end

      puts "Would you like to (k)ill or (c)onnect to any of these sessions? (x to exit) "
      resp = ' '

      while !['x','k','kill','c','con','conn','connect'].include?(resp)
        resp = gets.chomp
      end

      case resp
        when 'x'
          exit 0
        when 'k','kill'
          puts 'Please enter a comma-separated list of which numbers from the above list you would like to kill (or x to exit)'
          killList = gets.chomp
          if killList == 'x'
            exit 0
          end
          killList = killList.delete(' ').split(',')
          killList.each do |task_index|
            thisTask = activeTasksList[task_index.to_i-1]
            puts '!! '.red + 'Are you sure you want to KILL ' + "#{taskId}}".red + '? (y/n)' + ' !!'.red
            if gets.chomp == 'y'
              RestClient.delete "#{@uri}/api/requests/request/#{thisTask['taskId']['requestId']}"
              puts ' KILLED and DELETED: '.red + "#{thisTask['taskId']['requestId']}".light_blue
            end
          end
        when 'c','con','conn','connect'
          num = 0
          while num <= 0
            puts 'Please enter session number from the above list (or x to exit)'
            num = gets.chomp
            num == 'x' ? (exit 0) : (num = Integer(num))
          end
          puts "SSH into #{activeTasksList[num-1]['taskId']['requestId']} (y/n)?"
            if gets.chomp == 'y'
              Singularity::Runner.new()
      #   while resp != (y|n)
      #     resp = gets.chomp
      #   end
      #  if resp == "y"
      #   Singularity::Runner ->ssh
      #  else
      # end



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

  end
end
