require 'socket'
require 'timeout'

module Singularity
  module Util
    def self.port_open?(ip, port, seconds=1)
      Timeout::timeout(seconds) do
        begin
          TCPSocket.new(ip, port).close
          true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          false
        end
      end
    rescue Timeout::Error
      false
    end
  end
end
