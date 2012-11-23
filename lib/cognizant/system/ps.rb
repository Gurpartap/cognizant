module Cognizant
  module System
    module PS
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Fields to fetch from ps.
        IDX_MAP = {
          :pid  => 0,
          :ppid => 1,
          :pcpu => 2,
          :rss  => 3
        }

        def cpu_usage(pid)
          ps_axu[pid] && ps_axu[pid][IDX_MAP[:pcpu]].to_f
        end

        def memory_usage(pid)
          ps_axu[pid] && ps_axu[pid][IDX_MAP[:rss]].to_f
        end

        def get_children(parent_pid)
          child_pids = Array.new
          ps_axu.each_pair do |pid, chunks|
            child_pids << chunks[IDX_MAP[:pid]].to_i if chunks[IDX_MAP[:ppid]].to_i == parent_pid.to_i
          end
          child_pids
        end

        def reset_data
          store.clear unless store.empty?
        end

        def ps_axu
          # TODO: Need a mutex here?
          store[:ps_axu] ||= begin
            # BSD style ps invocation.
            lines = `ps axo #{IDX_MAP.keys.join(",")}`.split("\n")

            lines.inject(Hash.new) do |mem, line|
              chunks = line.split(/\s+/)
              chunks.delete_if {|c| c.strip.empty? }
              pid = chunks[IDX_MAP[:pid]].strip.to_i
              mem[pid] = chunks
              mem
            end
          end
        end

        private

        def store
          @store ||= Hash.new
        end
      end
    end
  end
end
