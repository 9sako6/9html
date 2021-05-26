module Htimlee
  class Tokenizer
    class Attribute
      include Comparable

      attr_accessor :name, :value

      def initialize(name: '', value: '')
        @name = name
        @value = value
      end

      def eql?(other)
        other.name == @name && other.value == @value
      end

      def <=>(other)
        if @name > other.name then 1
        elsif @name == other.name
          if @value > other.value then 1
          elsif @value == other.value then 0
          else -1
          end
        else -1
        end
      end
    end
  end
end
