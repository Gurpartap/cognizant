require "fileutils"

require "cognizant/system/signal"
require "cognizant/system/ps"

module Cognizant
  module System
    extend self

    include Cognizant::System::Signal
    include Cognizant::System::PS

    def pid_running?(pid)
      return false unless pid and pid != 0
      signal(0, pid)
      # It's running since no exception was raised.
      true
    rescue Errno::ESRCH
      # No such process.
      false
    rescue Errno::EPERM
      # Probably running, but we're not allowed to pass signals.
      # TODO: Is this a sign of problems ahead?
      true
    else
      # Possibly running.
      true
    end

    def unlink_file(path)
      begin
        File.unlink(path) if path
      rescue Errno::ENOENT
        nil
      end
    end

    def mkdir(*directories)
      [*directories].each do |directory|
        FileUtils.mkdir_p(File.expand_path(directory))
      end
    end
  end
end
