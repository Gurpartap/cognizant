module Cognizant
  module Commands
    command('help', 'Print out available commands') do
"You are speaking to the Cognizant command socket. You can run the following commands:

#{command_descriptions}
"
    end
  end
end
