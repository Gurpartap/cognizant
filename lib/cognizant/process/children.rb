module Cognizant
  class Process
    module Children
      def refresh_children!
        # First prune the list of dead children.
        @children.delete_if do |child|
          !child.process_running?
        end

        # Add new found children to the list.
        new_children_pids = Cognizant::System.get_children(@process_pid) - @children.map(&:cached_pid)

        unless new_children_pids.empty?
          Cognizant.log.info "Existing children: #{@children.collect{ |c| c.cached_pid }.join(",")}. Got new children: #{new_children_pids.inspect} for #{@process_pid}."
        end

        # Construct a new process wrapper for each new found children.
        new_children_pids.each do |child_pid|
          create_child_process(child_pid)
        end
      end

      def create_child_process(child_pid)
        name = "<child(pid:#{child_pid})>"
        attributes = @child_process_attributes.merge({ name: name, autostart: false }) # We do not have control over child process' lifecycle, so avoid even attempting to maintain its state with autostart.

        child = Cognizant::Process.new(nil, attributes, &@child_process_block)
        child.write_pid(child_pid)
        @children << child
        child.monitor
      end
    end
  end
end
