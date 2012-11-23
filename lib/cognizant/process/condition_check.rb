require "cognizant/process/conditions"
require "cognizant/util/rotational_array"

module Cognizant
  class Process
    class ConditionCheck
      class HistoryValue < Struct.new(:value, :critical); end

      # No need to recreate one every tick.
      EMPTY_ARRAY = [].freeze

      attr_accessor :condition_name
      def initialize(condition_name, options = {}, &block)
        @condition_name = condition_name

        if block
          @do = Array(block)
        else
          @do = options.has_key?(:do) ? Array(options.delete(:do)) : [:restart]
        end

        @every = options.delete(:every)
        @times = options.delete(:times) || [1, 1]
        @times = [@times, @times] unless @times.is_a?(Array) # handles :times => 5

        clear_history!

        @condition = Cognizant::Process::Conditions[@condition_name].new(options)
      end

      def run(pid, tick_number = Time.now.to_i)
        if @last_ran_at.nil? || (@last_ran_at + @every) <= tick_number
          @last_ran_at = tick_number

          value = @condition.run(pid)
          @history << HistoryValue.new(@condition.format_value(value), @condition.check(value))
          # puts self.to_s

          return @do if failed_check?
        end
        EMPTY_ARRAY
      end

      def clear_history!
        @history = Util::RotationalArray.new(@times.last)
      end

      def failed_check?
        @history.count { |v| v and v.critical } >= @times.first
      end

      def to_s
        data = @history.collect { |v| v and "#{v.value}#{'*' unless v.critical}" }.join(", ")
        "#{@condition_name}: [#{data}]\n"
      end
    end
  end
end
