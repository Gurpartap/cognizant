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
  end
end
