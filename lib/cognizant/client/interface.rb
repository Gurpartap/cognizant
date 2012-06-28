module Cognizant
  module Client
    class Interface < EM::Connection
      include EM::Protocols::SASLauthclient
    end
  end
end
