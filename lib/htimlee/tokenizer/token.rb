module Htimlee
  class Tokenizer
    class Token
      attr_accessor :data

      def initialize(data = '')
        @data = data
      end

      def eql?(other)
        other.data == @data
      end
    end

    class DoctypeToken < Token
      attr_accessor :name, :public_identifier, :system_identifier, :force_quirks_flag

      def initialize(name = '', public_identifier = nil, system_identifier = nil, force_quirks_flag = false)
        @name = name
        @public_identifier = public_identifier
        @system_identifier = system_identifier
        @force_quirks_flag = force_quirks_flag
      end

      def eql?(other)
        other.name == @name &&
          other.public_identifier == @public_identifier &&
          other.system_identifier == @system_identifier &&
          other.force_quirks_flag == @force_quirks_flag
      end
    end

    class StartTagToken < Token
      attr_accessor :name, :attributes, :self_closing_flag

      def initialize(name = '', attributes = [], self_closing_flag = false)
        @name = name
        @attributes = attributes
        @self_closing_flag = self_closing_flag
      end

      def eql?(other)
        other.name == @name && eql_attributes?(other.attributes) && other.self_closing_flag == @self_closing_flag
      end

      def append_to_last_attribute_name(char)
        @attributes.last.name << char
      end

      def append_to_last_attribute_value(char)
        @attributes.last.value << char
      end

      def delete_duplicate_attribute!
        attribute_name_count = Hash.new(0)
        uniq_attributes = []

        @attributes.each do |attribute|
          uniq_attributes << attribute if attribute_name_count[attribute.name].zero?
          attribute_name_count[attribute.name] += 1
        end

        @attributes = uniq_attributes
        self
      end

      private

      def eql_attributes?(other_attributes)
        return false if other_attributes.length != @attributes.length

        other_attributes.sort.zip(@attributes.sort).all? do |other_attribute, attribute|
          other_attribute.eql?(attribute)
        end
      end
    end

    class EndTagToken < Token
      attr_accessor :name

      def initialize(name = '')
        @name = name
      end

      def eql?(other)
        other.name == @name
      end
    end

    CommentToken = Class.new(Token)
    CharacterToken = Class.new(Token)

    class EndOfFileToken < Token
      attr_reader :data

      def initialize
        @data = 'end-of-file'
      end
    end
  end
end
