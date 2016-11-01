module Singularity
  class Deployer
    def deploy
      begin
        if $request.is_paused($data['id'])
          puts ' PAUSED, SKIPPING.'
          return
        else
          puts ' Deploying request...'.light_green
          # create or update the request
          RestClient.post "#{$uri}/api/requests", $data.to_json, :content_type => :json
          # deploy the request
          $data['requestId'] = $data['id']
          $data['id'] = "#{$release}.#{Time.now.to_i}"
          deploy = {
           'deploy' => $data,
           'user' => `whoami`.chomp,
           'unpauseOnSuccessfulDeploy' => false
          }
          RestClient.post "#{$uri}/api/deploys", deploy.to_json, :content_type => :json
          puts " DEPLOYED".green
        end
      rescue Exception => e
        puts " #{e.response}".red
      end
    end
  end
end
