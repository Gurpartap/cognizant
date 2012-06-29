module Cognizant
  module System
    def self.drop_privileges(options = {})
      # Cannot drop privileges unless we are superuser.
      if ::Process.euid == 0
        # Drop ~= decrease, since we can only decrease privileges.

        # For clarity.
        uid    = options[:uid]
        gid    = options[:gid]
        groups = options[:groups]

        # Find the user and primary group in the password and group database.
        user  = (uid.is_a? Integer) ? Etc.getpwuid(uid) : Etc.getpwnam(uid) if uid
        group = (gid.is_a? Integer) ? Etc.getgruid(gid) : Etc.getgrnam(gid) if gid
  
        # Collect the secondary groups' GIDs.
        group_ids = groups.map { |g| Etc.getgrnam(g).gid } if groups
  
        # Set the fork's secondary user groups for the spawn process to inherit.
        ::Process.groups = [group.gid] if group # Including the primary group.
        ::Process.groups |= group_ids if groups and !group_ids.empty?
  
        # Set the fork's user and primary group for the spawn process to inherit.
        ::Process.uid = user.uid  if user
        ::Process.gid = group.gid if group
  
        # Find and set the user's HOME environment variable for fun.
        options[:env] = options[:env].merge({ 'HOME' => user.dir }) if user and user.dir

        # Changes the process' idea of the file system root.
        # Dir.chroot(@options[:chroot]) if @options[:chroot]

        # umask and chdir drops are managed by ::Process.spawn.
      end
    end
  end
end
