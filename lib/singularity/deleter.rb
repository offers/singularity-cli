module Deleter
  # Deleter.delete -- arguments are <file>
  def self.delete(file)
    begin
      task_id = "#{file}".gsub(/\.\/singularity\//, "").gsub(/\.json/, "")
      # delete the request
      RestClient.delete "#{$uri}/api/requests/request/#{task_id}"
      print "#{task_id}".light_blue + ' DELETED'.red + "\n"
    rescue
      puts "#{task_id} #{$!.response}"
    end
  end
end
