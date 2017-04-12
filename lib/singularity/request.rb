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
      tasks = JSON.parse(RestClient.get "#{@uri}/api/tasks/active", :content_type => :json)

      count = 1
      tasks.each do |entry|
        taskId = entry['taskRequest']['request']['id']
        if taskId.include?("SSH")
          ip = entry['offer']['url']['address']['ip']
          port = entry['mesosTask']['container']['docker']['portMappings'][0]['hostPort']

          puts "#{count}: ".light_green + "#{taskId}: ".light_blue + "root".yellow + " @ ".light_blue + "#{ip}".light_magenta + " : ".light_blue + "#{port}".light_cyan
          count = count + 1
        end
      end

      puts "Would you like to (k)ill or (c)onnect to any of these sessions? (n or Ctrl+C to exit) "
      resp = 'x'

      while !['n','k','kill','c','con','conn','connect'].include?(resp)
        resp = gets
      end

      case resp
        when 'n'
          message = RestClient.get "http://bit.ly/2p9K3sI"
          message = message.chop.chop.chop + "\""
          puts RestClient.get "http://bit.ly/2otyRsW", :message => "#{message}", :format => "text"
        when 'k','kill'

        when 'c','con','conn','connect'
          # please enter the session number

      #   # wrap the below in error checking
      #   num = gets.to_i


      #   while resp != (y|n)
      #     puts "SSH into <> (y/n)?"
      #     resp = getc
      #   end
      #  if resp == "y"
      #   Singularity::Runner ->ssh
      #  else
      # end

      # if (k)
      #   please enter a comma-separated list of which numbers you'd like to kill
      #   list = gets
      #   list = list.remove(" ").split(",")
      #   list.each do |process_index|
      #     tasks[process_index-1]
      #     "!!".red + " Are you sure you want to KILL " + "#{taskId}}".red + "?" + "!!".red
      #   end
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
