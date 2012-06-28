module Cognizant
  module Validations
    class ValidationError < StandardError; end

    # Validations the user/group ownership to the given file. Attempts to
    # create the directory+file if it doesn't already exist.
    # @param [String] file Path to a file
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

    # Validations the user/group ownership to the given directory. Attempts to
    # create the directory if it doesn't already exist.
    # @param [String] directory Path to a directory
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

    # Validates the inclusion of a value in an array.
    # @param [Object] value The value to validate.
    # @param [Array] array The array of allowed values.
    def self.validate_includes(value, array)
      unless [*array].include?(value)
        raise ValidationError, "#{value} is an invalid option type. It must be one of the following: #{[*array].join(', ')}."
      end
    end

    # Validates the env variable to be a hash.
    # @param [Object] env The value to validate.
    def self.validate_env(env)
      return unless env
      if not env.respond_to?(:is_a?) or not env.is_a?(Hash)
        raise Validations::ValidationError, %{"env" needs to be a hash. e.g. { "PATH" => "/usr/local/bin" }}
      end
    end

    # Validates the umask variable to be a number.
    # @param [Object] umask The value to validate.
    def self.validate_umask(umask)
      return unless umask
      Float(umask) rescue raise Validations::ValidationError, %{The umask "#{umask}" is invalid.}
    end

    # Validates the existence of the user in the system.
    # @param [String, Integer] uid The user ID or name to validate.
    def self.validate_user(uid)
      return unless uid
      begin
        if self.is_number?(uid)
          Etc.getpwuid(uid)
        else
          Etc.getpwnam(uid)
        end
      rescue ArgumentError
        raise Validations::ValidationError, %{The uid "#{uid}" does not exist.}
      end
    end
    
    # Validates the existence of the user group in the system.
    # @param [String, Integer] gid The user group ID or name to validate.
    def self.validate_user_group(gid)
      return unless gid
      begin
        if self.is_number?(gid)
          Etc.getgrgid(gid)
        else
          Etc.getgrname(gid)
        end
      rescue ArgumentError
        raise Validations::ValidationError, %{The gid "#{gid}" does not exist.}
      end
    end

    private

    def self.is_number?(value)
      true if Float(value) rescue false
    end
  end
end
