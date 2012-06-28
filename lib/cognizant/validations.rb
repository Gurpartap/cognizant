module Cognizant
  module Validations
    class ValidationError < StandardError; end

    def self.validate_file_writable(file)
      file = File.expand_path(file)

      begin
        filetype = File.ftype(file)

        unless filetype.eql?("file")
          raise ValidationError, "\"#{file}\" is a #{filetype}. File required."
        end
      rescue Errno::ENOENT
        self.validate_directory_writable(File.dirname(file))

        begin
          unless File.open(file, "w")
            raise ValidationError, "The file \"#{file}\" is not writable."
          end
        rescue Errno::EACCES
          raise ValidationError, "The file \"#{file}\" could not be created due to the lack of privileges."
        end
      end

      unless File.owned?(file) or File.grpowned?(file)
        raise ValidationError, "The file \"#{file}\" is not owned by the process user."
      end
    end

    def self.validate_directory_writable(directory)
      directory = File.expand_path(directory)

      begin
        filetype = File.ftype(directory)

        unless filetype.eql?("directory")
          raise ValidationError, "\"#{directory}\" is a #{filetype}. Directory required."
        end
      rescue Errno::ENOENT
        begin
          FileUtils.mkdir_p(directory)
        rescue Errno::EACCES
          raise ValidationError, "The directory \"#{directory}\" could not be created due to the lack of privileges."
        end
      end

      unless File.owned?(directory) or File.grpowned?(directory)
        raise ValidationError, "The directory \"#{directory}\" is not owned by the process user."
      end
    end

    def self.validate_includes(variable, types)
      unless [*types].include?(variable)
        raise ValidationError, "#{variable} is an invalid option type. It must be one of the following: #{[*types].join(', ')}."
      end
    end

    def self.validate_env(@env)
      if not @env.respond_to?(:is_a?) or @env.is_a?(Hash)
        raise Validations::ValidationError, %{"env" needs to be a hash. e.g. { "PATH" => "/usr/local/bin" }}
      end
    end

    def self.validate_umask(@umask)
      Float(@umask) rescue raise Validations::ValidationError, %{The umask "#{@umask}" is invalid.}
    end

    def self.validate_user(@uid)
      begin
        if Float(@uid) rescue false
          Etc.getpwuid(@uid)
        else
          Etc.getpwnam(@uid)
        end
      rescue ArgumentError
        raise Validations::ValidationError, %{The uid "#{@uid}" does not exist.}
      end
    end
    
    def self.validate_user_group(@gid)
      begin
        if Float(@gid) rescue false
          Etc.getgrgid(@gid)
        else
          Etc.getgrname(@gid)
        end
      rescue ArgumentError
        raise Validations::ValidationError, %{The gid "#{@gid}" does not exist.}
      end
    end
  end
end
