require_relative 'tokenizer/attribute'
require_relative 'tokenizer/named_character'
require_relative 'tokenizer/token'
require_relative 'character'
require 'strscan'

module Htimlee
  # Class for tokenizing text to a sequence of tokens of HTML.
  #
  # 13.2.5 Tokenization
  # https://html.spec.whatwg.org/multipage/parsing.html#tokenization
  class Tokenizer
    include Character

    EOF = EndOfFileToken.new

    def initialize(text)
      @text = text
      @scanner = StringScanner.new(text.force_encoding(Encoding::UTF_8))
      @buffer = []
    end

    def next_token
      return @buffer.shift if @buffer.any?

      token = data_state
      token.delete_duplicate_attribute! if token.is_a?(StartTagToken)

      @buffer << token
      @buffer.shift
    end

    private

    # 13.2.5.1 Data state
    # https://html.spec.whatwg.org/multipage/parsing.html#data-state
    def data_state
      case current_input_character = get_byte
      when AMPERSAND
        set_return_state(__method__)
        character_reference_state
      when LESS_THAN_SIGN
        tag_open_state
      when NULL
        # NOTE: unexpected-null-character parse error
        CharacterToken.new(current_input_character)
      when nil
        EOF
      else
        CharacterToken.new(current_input_character)
      end
    end

    # 13.2.5.2 RCDATA state
    # https://html.spec.whatwg.org/multipage/parsing.html#rcdata-state
    def rcdata_state
      case current_input_character = get_byte
      when AMPERSAND
        set_return_state(__method__)
        character_reference_state
      when LESS_THAN_SIGN
        rcdata_less_than_sign_state
      when NULL
        # NOTE: unexpected-null-character parse error
        CharacterToken.new(REPLACEMENT_CHARACTER)
      when nil
        EOF
      else
        CharacterToken.new(current_input_character)
      end
    end

    # 13.2.5.6 Tag open state
    # https://html.spec.whatwg.org/multipage/parsing.html#tag-open-state
    def tag_open_state
      case get_byte
      when EXCLAMATION_MARK
        markup_declaration_open_state
      when SOLIDUS
        end_tag_open_state
      when /[A-Za-z]/
        back_byte
        tag_name_state(StartTagToken.new)
      when QUESTION_MARK
        # NOTE: unexpected-question-mark-instead-of-tag-name parse error
        back_byte
        bogus_comment_state(CommentToken.new)
      when nil
        # NOTE: eof-before-tag-name parse error
        CharacterToken.new(LESS_THAN_SIGN)
      else
        # NOTE: invalid-first-character-of-tag-name parse error
        back_byte
        CharacterToken.new(LESS_THAN_SIGN)
      end
    end

    # 13.2.5.7 End tag open state
    # https://html.spec.whatwg.org/multipage/parsing.html#end-tag-open-state
    def end_tag_open_state
      case get_byte
      when /[A-Za-z]/
        back_byte
        tag_name_state(EndTagToken.new)
      when GREATER_THAN_SIGN
        # NOTE: missing-end-tag-name parse error
        data_state
      when nil
        # NOTE: eof-before-tag-name parse error
        @buffer << CharacterToken.new(LESS_THAN_SIGN)
        CharacterToken.new(SOLIDUS)
      else
        # NOTE: invalid-first-character-of-tag-name parse error
        back_byte
        bogus_comment_state(CommentToken.new)
      end
    end

    # 13.2.5.8 Tag name state
    # https://html.spec.whatwg.org/multipage/parsing.html#tag-name-state
    def tag_name_state(current_token)
      loop do
        case current_input_character = get_byte
        when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
          return before_attribute_name_state(current_token)
        when SOLIDUS
          return self_closing_start_tag_state(current_token)
        when GREATER_THAN_SIGN
          return current_token
        when /[A-Z]/
          current_token.name << current_input_character.downcase
        when NULL
          # NOTE: unexpected-null-character parse error
          current_token.name << REPLACEMENT_CHARACTER
        when nil
          # NOTE: eof-in-tag parse error
          return EOF
        else
          current_token.name << current_input_character
        end
      end
    end

    # 13.2.5.32 Before attribute name state
    # https://html.spec.whatwg.org/multipage/parsing.html#before-attribute-name-state
    def before_attribute_name_state(current_token)
      loop do
        case current_input_character = get_byte
        when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
        when SOLIDUS, GREATER_THAN_SIGN, nil
          back_byte
          return after_attribute_name_state(current_token)
        when EQUALS_SIGN
          # NOTE: unexpected-equals-sign-before-attribute-name parse error
          current_token.attributes << Attribute.new(name: current_input_character) if current_token.is_a?(StartTagToken)
          return attribute_name_state(current_token)
        else
          current_token.attributes << Attribute.new if current_token.is_a?(StartTagToken)
          back_byte
          return attribute_name_state(current_token)
        end
      end
    end

    # 13.2.5.33 Attribute name state
    # https://html.spec.whatwg.org/multipage/parsing.html#attribute-name-state
    def attribute_name_state(current_token)
      loop do
        case current_input_character = get_byte
        when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE, SOLIDUS, GREATER_THAN_SIGN, nil
          back_byte
          return after_attribute_name_state(current_token)
        when EQUALS_SIGN
          return before_attribute_value_state(current_token)
        when /[A-Z]/
          current_token.append_to_last_attribute_name(current_input_character.downcase) if current_token.is_a?(StartTagToken)
        when NULL
          # NOTE: unexpected-null-character parse error
          current_token.append_to_last_attribute_name(REPLACEMENT_CHARACTER) if current_token.is_a?(StartTagToken)
        when QUOTATION_MARK, APOSTROPHE, LESS_THAN_SIGN
          # NOTE: unexpected-character-in-attribute-name parse error
          current_token.append_to_last_attribute_name(current_input_character) if current_token.is_a?(StartTagToken)
        else
          current_token.append_to_last_attribute_name(current_input_character) if current_token.is_a?(StartTagToken)
        end
      end
    rescue ArgumentError
      # the error: "`===': invalid byte sequence in UTF-8 (ArgumentError)"
      back_byte
      current_token.append_to_last_attribute_name(get_byte) if current_token.is_a?(StartTagToken)
      attribute_name_state(current_token)
    end

    # 13.2.5.34 After attribute name state
    # https://html.spec.whatwg.org/multipage/parsing.html#after-attribute-name-state
    def after_attribute_name_state(current_token)
      loop do
        case get_byte
        when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
          # ignore the character
        when SOLIDUS
          return self_closing_start_tag_state(current_token)
        when EQUALS_SIGN
          return before_attribute_value_state(current_token)
        when GREATER_THAN_SIGN
          return current_token
        when nil
          # NOTE: eof-in-tag parse error
          return EOF
        else
          current_token.attributes << Attribute.new if current_token.is_a?(StartTagToken)
          back_byte
          return attribute_name_state(current_token)
        end
      end
    end

    # 13.2.5.35 Before attribute value state
    # https://html.spec.whatwg.org/multipage/parsing.html#before-attribute-value-state
    def before_attribute_value_state(current_token)
      loop do
        case get_byte
        when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
        when QUOTATION_MARK
          return attribute_value_double_quoted_state(current_token)
        when APOSTROPHE
          return attribute_value_single_quoted_state(current_token)
        when GREATER_THAN_SIGN
          # NOTE: missing-attribute-value parse error
          return current_token
        else
          back_byte
          return attribute_value_unquoted_state(current_token)
        end
      end
    end

    # 13.2.5.36 Attribute value (double-quoted) state
    # https://html.spec.whatwg.org/multipage/parsing.html#attribute-value-(double-quoted)-state
    def attribute_value_double_quoted_state(current_token)
      loop do
        case current_input_character = get_byte
        when QUOTATION_MARK
          return after_attribute_value_quoted_state(current_token)
        when AMPERSAND
          set_return_state(__method__)
          return character_reference_state(current_token)
        when NULL
          # NOTE: unexpected-null-character parse error
          current_token.append_to_last_attribute_value(REPLACEMENT_CHARACTER) if current_token.is_a?(StartTagToken)
        when nil
          # NOTE: eof-in-tag parse error
          return EOF
        else
          current_token.append_to_last_attribute_value(current_input_character) if current_token.is_a?(StartTagToken)
        end
      end
    end

    # 13.2.5.37 Attribute value (single-quoted) state
    # https://html.spec.whatwg.org/multipage/parsing.html#attribute-value-(single-quoted)-state
    def attribute_value_single_quoted_state(current_token)
      loop do
        case current_input_character = get_byte
        when APOSTROPHE
          return after_attribute_value_quoted_state(current_token)
        when AMPERSAND
          set_return_state(__method__)
          return character_reference_state(current_token)
        when NULL
          # NOTE: unexpected-null-character parse error
          last_attribute(current_token).value << REPLACEMENT_CHARACTER if current_token.is_a?(StartTagToken)
        when nil
          # NOTE: eof-in-tag parse error
          return EOF
        else
          current_token.append_to_last_attribute_value(current_input_character) if current_token.is_a?(StartTagToken)
        end
      end
    end

    # 13.2.5.38 Attribute value (unquoted) state
    # https://html.spec.whatwg.org/multipage/parsing.html#attribute-value-(unquoted)-state
    def attribute_value_unquoted_state(current_token)
      loop do
        case current_input_character = get_byte
        when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
          return before_attribute_name_state(current_token)
        when AMPERSAND
          set_return_state(__method__)
          return character_reference_state(current_token)
        when GREATER_THAN_SIGN
          return current_token
        when NULL
          # NOTE: unexpected-null-character parse error
          current_token.append_to_last_attribute_value(REPLACEMENT_CHARACTER)
        when QUOTATION_MARK, APOSTROPHE, LESS_THAN_SIGN, EQUALS_SIGN, GRAVE_ACCENT
          # NOTE: unexpected-character-in-unquoted-attribute-value parse error
          current_token.append_to_last_attribute_value(current_input_character)
        when nil
          # NOTE: eof-in-tag parse error
          return EOF
        else
          current_token.append_to_last_attribute_value(current_input_character)
        end
      end
    end

    # 13.2.5.39 After attribute value (quoted) state
    # https://html.spec.whatwg.org/multipage/parsing.html#after-attribute-value-(quoted)-state
    def after_attribute_value_quoted_state(current_token)
      case get_byte
      when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
        before_attribute_name_state(current_token)
      when SOLIDUS
        self_closing_start_tag_state(current_token)
      when GREATER_THAN_SIGN
        current_token
      when nil
        # NOTE: eof-in-tag parse error
        EOF
      else
        # NOTE: missing-whitespace-between-attributes parse error
        back_byte
        before_attribute_name_state(current_token)
      end
    end

    # 13.2.5.40 Self-closing start tag state
    # https://html.spec.whatwg.org/multipage/parsing.html#self-closing-start-tag-state
    def self_closing_start_tag_state(current_token)
      case get_byte
      when GREATER_THAN_SIGN
        current_token.self_closing_flag = true if current_token.is_a?(StartTagToken)
        current_token
      when nil
        # NOTE: eof-in-tag parse error
        EOF
      else
        # NOTE: unexpected-solidus-in-tag parse error
        back_byte
        before_attribute_name_state(current_token)
      end
    end

    # 13.2.5.41 Bogus comment state
    # https://html.spec.whatwg.org/multipage/parsing.html#bogus-comment-state
    def bogus_comment_state(current_comment_token)
      loop do
        case current_input_character = get_byte
        when GREATER_THAN_SIGN
          return current_comment_token
        when nil
          return current_comment_token
        when NULL
          # NOTE: unexpected-null-character parse error
          current_comment_token.data << REPLACEMENT_CHARACTER
        else
          current_comment_token.data << current_input_character
        end
      end
    end

    # 13.2.5.42 Markup declaration open state
    # https://html.spec.whatwg.org/multipage/parsing.html#markup-declaration-open-state
    def markup_declaration_open_state
      if @scanner.check(HYPHEN_MINUS * 2)
        @scanner.pos += 2
        comment_start_state(CommentToken.new)
      elsif @scanner.check(/DOCTYPE/i)
        @scanner.pos += 7
        doctype_state
      elsif @scanner.check(LEFT_SQUARE_BRACKET + 'CDATA' + LEFT_SQUARE_BRACKET)
        # @scanner.pos += 7
        # TODO
      else
        # NOTE: incorrectly-opened-comment parse error
        bogus_comment_state(CommentToken.new)
      end
    end

    # 13.2.5.43 Comment start state
    # https://html.spec.whatwg.org/multipage/parsing.html#comment-start-state
    def comment_start_state(current_comment_token)
      case get_byte
      when HYPHEN_MINUS
        comment_start_dash_state(current_comment_token)
      when GREATER_THAN_SIGN
        # NOTE: abrupt-closing-of-empty-comment parse error
        current_comment_token
      else
        back_byte
        comment_state(current_comment_token)
      end
    end

    # 13.2.5.44 Comment start dash state
    # https://html.spec.whatwg.org/multipage/parsing.html#comment-start-dash-state
    def comment_start_dash_state(current_comment_token)
      case get_byte
      when HYPHEN_MINUS
        comment_end_state(current_comment_token)
      when GREATER_THAN_SIGN
        # NOTE: abrupt-closing-of-empty-comment parse error
        current_comment_token
      when nil
        # NOTE: eof-in-comment parse error
        current_comment_token
      else
        current_comment_token.data << HYPHEN_MINUS
        back_byte
        comment_state(current_comment_token)
      end
    end

    # 13.2.5.45 Comment state
    # https://html.spec.whatwg.org/multipage/parsing.html#comment-state
    def comment_state(current_comment_token)
      case current_input_character = get_byte
      when LESS_THAN_SIGN
        current_comment_token.data << current_input_character
        comment_less_than_sign_state(current_comment_token)
      when HYPHEN_MINUS
        comment_end_dash_state(current_comment_token)
      when NULL
        # NOTE: unexpected-null-character parse error
        current_comment_token.data << REPLACEMENT_CHARACTER
        comment_state(current_comment_token)
      when nil
        # NOTE: eof-in-comment parse error
        current_comment_token
      else
        current_comment_token.data << current_input_character
        comment_state(current_comment_token)
      end
    end

    # 13.2.5.46 Comment less-than sign state
    # https://html.spec.whatwg.org/multipage/parsing.html#comment-less-than-sign-state
    def comment_less_than_sign_state(current_comment_token)
    end

    # 13.2.5.50 Comment end dash state
    # https://html.spec.whatwg.org/multipage/parsing.html#comment-end-dash-state
    def comment_end_dash_state(current_comment_token)
      case get_byte
      when HYPHEN_MINUS
        comment_end_state(current_comment_token)
      when nil
        # NOTE: eof-in-comment parse error
        current_comment_token
      else
        current_comment_token.data << HYPHEN_MINUS
        back_byte
        comment_state(current_comment_token)
      end
    end

    # 13.2.5.51 Comment end state
    # https://html.spec.whatwg.org/multipage/parsing.html#comment-end-state
    def comment_end_state(current_comment_token)
      case get_byte
      when GREATER_THAN_SIGN
        current_comment_token
      when EXCLAMATION_MARK
        comment_end_bang_state(current_comment_token)
      when HYPHEN_MINUS
        current_comment_token.data << HYPHEN_MINUS
        comment_end_state(current_comment_token)
      when nil
        # NOTE: eof-in-comment parse error
        current_comment_token
      else
        back_byte
        current_comment_token.data << HYPHEN_MINUS * 2
        comment_state(current_comment_token)
      end
    end

    # 13.2.5.52 Comment end bang state
    # https://html.spec.whatwg.org/multipage/parsing.html#comment-end-bang-state
    def comment_end_bang_state(current_comment_token)
      case get_byte
      when HYPHEN_MINUS
        current_comment_token.data << HYPHEN_MINUS
        current_comment_token.data << EXCLAMATION_MARK
        comment_end_dash_state(current_comment_token)
      when GREATER_THAN_SIGN
        # NOTE: incorrectly-closed-comment parse error
        current_comment_token
      when nil
        # NOTE: eof-in-comment parse error
        current_comment_token
      else
        current_comment_token.data << HYPHEN_MINUS
        current_comment_token.data << EXCLAMATION_MARK
        comment_state(current_comment_token)
      end
    end

    # 13.2.5.53 DOCTYPE state
    # https://html.spec.whatwg.org/multipage/parsing.html#doctype-state
    def doctype_state
      case get_byte
      when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
        before_doctype_name_state
      when GREATER_THAN_SIGN
        back_byte
        before_doctype_name_state
      when nil
        # NOTE: eof-in-doctype parse error
        DoctypeToken.new('', '', '', true)
      else
        # NOTE: missing-whitespace-before-doctype-name parse error
        back_byte
        before_doctype_name_state
      end
    end

    # 13.2.5.54 Before DOCTYPE name state
    # https://html.spec.whatwg.org/multipage/parsing.html#before-doctype-name-state
    def before_doctype_name_state
      case current_input_character = get_byte
      when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
        before_doctype_name_state
      when /[A-Z]/
        doctype_name_state(DoctypeToken.new(current_input_character.downcase))
      when NULL
        # NOTE: unexpected-null-character parse error
        doctype_name_state(DoctypeToken.new(REPLACEMENT_CHARACTER))
      when GREATER_THAN_SIGN
        # NOTE: missing-doctype-name parse error
        DoctypeToken.new('', nil, nil, true)
      when nil
        # NOTE: eof-in-doctype parse error
        DoctypeToken.new('', nil, nil, true)
      else
        doctype_name_state(DoctypeToken.new(current_input_character))
      end
    end

    # 13.2.5.55 DOCTYPE name state
    # https://html.spec.whatwg.org/multipage/parsing.html#doctype-name-state
    def doctype_name_state(current_doctype_token)
      case current_input_character = get_byte
      when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
        after_doctype_name_state(current_doctype_token)
      when GREATER_THAN_SIGN
        current_doctype_token
      when /[A-Z]/
        current_doctype_token.name << current_input_character.downcase
        doctype_name_state(current_doctype_token)
      when NULL
        # NOTE: unexpected-null-character parse error
        current_doctype_token.name << REPLACEMENT_CHARACTER
        doctype_name_state(current_doctype_token)
      when nil
        # NOTE: eof-in-doctype parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      else
        current_doctype_token.name << current_input_character
        doctype_name_state(current_doctype_token)
      end
    end

    # 13.2.5.56 After DOCTYPE name state
    # https://html.spec.whatwg.org/multipage/parsing.html#after-doctype-name-state
    def after_doctype_name_state(current_doctype_token)
      case get_byte
      when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
        after_doctype_name_state(current_doctype_token)
      when GREATER_THAN_SIGN
        current_doctype_token
      when nil
        # NOTE: eof-in-doctype parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      else
        back_byte
        if @scanner.check(/PUBLIC/i)
          @scanner.pos += 6
          after_doctype_public_keyword_state(current_doctype_token)
        elsif @scanner.check(/SYSTEM/i)
          @scanner.pos += 6
          after_doctype_system_keyword_state(current_doctype_token)
        else
          # NOTE: invalid-character-sequence-after-doctype-name parse error
          current_doctype_token.force_quirks_flag = true
          back_byte
          bogus_doctype_state(current_doctype_token)
        end
      end
    end

    # 13.2.5.57 After DOCTYPE public keyword state
    # https://html.spec.whatwg.org/multipage/parsing.html#after-doctype-public-keyword-state
    def after_doctype_public_keyword_state(current_doctype_token)
      case get_byte
      when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
        before_doctype_public_identifier_state(current_doctype_token)
      when QUOTATION_MARK
        # NOTE: missing-whitespace-after-doctype-public-keyword parse error
        current_doctype_token.public_identifier = ''
        doctype_public_identifier_double_quoted_state(current_doctype_token)
      when APOSTROPHE
        # NOTE: missing-whitespace-after-doctype-public-keyword parse error
        current_doctype_token.public_identifier = ''
        doctype_public_identifier_single_quoted_state(current_doctype_token)
      when GREATER_THAN_SIGN
        # NOTE: missing-doctype-public-identifier parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      when nil
        # NOTE: eof-in-doctype parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      else
        # NOTE: missing-quote-before-doctype-public-identifier parse error
        current_doctype_token.force_quirks_flag = true
        back_byte
        bogus_doctype_state(current_doctype_token)
      end
    end

    # 13.2.5.58 Before DOCTYPE public identifier state
    # https://html.spec.whatwg.org/multipage/parsing.html#before-doctype-public-identifier-state
    def before_doctype_public_identifier_state(current_doctype_token)
      case get_byte
      when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
        before_doctype_public_identifier_state(current_doctype_token)
      when QUOTATION_MARK
        current_doctype_token.public_identifier = ''
        doctype_public_identifier_double_quoted_state(current_doctype_token)
      when APOSTROPHE
        current_doctype_token.public_identifier = ''
        doctype_public_identifier_single_quoted_state(current_doctype_token)
      when nil
        # NOTE: eof-in-doctype parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      else
        # NOTE: missing-quote-before-doctype-public-identifier parse error
        current_doctype_token.force_quirks_flag = true
        back_byte
        bogus_doctype_state(current_doctype_token)
      end
    end

    # 13.2.5.59 DOCTYPE public identifier (double-quoted) state
    # https://html.spec.whatwg.org/multipage/parsing.html#doctype-public-identifier-(double-quoted)-state
    def doctype_public_identifier_double_quoted_state(current_doctype_token)
      case current_input_character = get_byte
      when QUOTATION_MARK
        after_doctype_public_identifier_state(current_doctype_token)
      when NULL
        # NOTE: unexpected-null-character parse error
        current_doctype_token.public_identifier << REPLACEMENT_CHARACTER
        doctype_public_identifier_double_quoted_state(current_doctype_token)
      when GREATER_THAN_SIGN
        # NOTE: abrupt-doctype-public-identifier parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      when nil
        # NOTE: eof-in-doctype parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      else
        current_doctype_token.public_identifier << current_input_character
        doctype_public_identifier_double_quoted_state(current_doctype_token)
      end
    end

    # 13.2.5.60 DOCTYPE public identifier (single-quoted) state
    # https://html.spec.whatwg.org/multipage/parsing.html#doctype-public-identifier-(single-quoted)-state
    def doctype_public_identifier_single_quoted_state(current_doctype_token)
      case current_input_character = get_byte
      when APOSTROPHE
        after_doctype_public_identifier_state(current_doctype_token)
      when NULL
        # NOTE: unexpected-null-character parse error
        current_doctype_token.public_identifier << REPLACEMENT_CHARACTER
        doctype_public_identifier_single_quoted_state(current_doctype_token)
      when GREATER_THAN_SIGN
        # NOTE: abrupt-doctype-public-identifier parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      when nil
        # NOTE: eof-in-doctype parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      else
        current_doctype_token.public_identifier << current_input_character
        doctype_public_identifier_single_quoted_state(current_doctype_token)
      end
    end

    # 13.2.5.61 After DOCTYPE public identifier state
    # https://html.spec.whatwg.org/multipage/parsing.html#after-doctype-public-identifier-state
    def after_doctype_public_identifier_state(current_doctype_token)
      case get_byte
      when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
        between_doctype_public_and_system_identifiers_state(current_doctype_token)
      when GREATER_THAN_SIGN
        current_doctype_token
      when QUOTATION_MARK
        # NOTE: missing-whitespace-between-doctype-public-and-system-identifiers parse error
        current_doctype_token.system_identifier = ''
        doctype_system_identifier_double_quoted_state(current_doctype_token)
      when APOSTROPHE
        # NOTE: missing-whitespace-between-doctype-public-and-system-identifiers parse error
        current_doctype_token.system_identifier = ''
        doctype_system_identifier_single_quoted_state(current_doctype_token)
      when nil
        # NOTE: eof-in-doctype parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      else
        # NOTE: missing-quote-before-doctype-system-identifier parse error
        current_doctype_token.force_quirks_flag = true
        bogus_doctype_state(current_doctype_token)
      end
    end

    # 13.2.5.62 Between DOCTYPE public and system identifiers state
    # https://html.spec.whatwg.org/multipage/parsing.html#between-doctype-public-and-system-identifiers-state
    def between_doctype_public_and_system_identifiers_state(current_doctype_token)
      case get_byte
      when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
        between_doctype_public_and_system_identifiers_state(current_doctype_token)
      when GREATER_THAN_SIGN
        current_doctype_token
      when QUOTATION_MARK
        current_doctype_token.system_identifier = ''
        doctype_system_identifier_double_quoted_state(current_doctype_token)
      when APOSTROPHE
        current_doctype_token.system_identifier = ''
        doctype_system_identifier_single_quoted_state(current_doctype_token)
      when EOF
        # NOTE: eof-in-doctype parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      else
        # NOTE: missing-quote-before-doctype-system-identifier parse error
        current_doctype_token.force_quirks_flag = true
        bogus_doctype_state(current_doctype_token)
      end
    end

    # 13.2.5.65 DOCTYPE system identifier (double-quoted) state
    # https://html.spec.whatwg.org/multipage/parsing.html#doctype-system-identifier-(double-quoted)-state
    def doctype_system_identifier_double_quoted_state(current_doctype_token)
      case current_input_character = get_byte
      when QUOTATION_MARK
        after_doctype_system_identifier_state(current_doctype_token)
      when NULL
        current_doctype_token.system_identifier << REPLACEMENT_CHARACTER
        doctype_system_identifier_double_quoted_state(current_doctype_token)
      when GREATER_THAN_SIGN
        # NOTE: abrupt-doctype-system-identifier parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      when nil
        # NOTE: eof-in-doctype parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      else
        current_doctype_token.system_identifier << current_input_character
        doctype_system_identifier_double_quoted_state(current_doctype_token)
      end
    end

    # 13.2.5.66 DOCTYPE system identifier (single-quoted) state
    # https://html.spec.whatwg.org/multipage/parsing.html#doctype-system-identifier-(single-quoted)-state
    def doctype_system_identifier_single_quoted_state(current_doctype_token)
      case current_input_character = get_byte
      when APOSTROPHE
        after_doctype_system_identifier_state(current_doctype_token)
      when NULL
        current_doctype_token.system_identifier << REPLACEMENT_CHARACTER
        doctype_system_identifier_single_quoted_state(current_doctype_token)
      when GREATER_THAN_SIGN
        # NOTE: abrupt-doctype-system-identifier parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      when nil
        # NOTE: eof-in-doctype parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      else
        current_doctype_token.system_identifier << current_input_character
        doctype_system_identifier_single_quoted_state(current_doctype_token)
      end
    end

    # 13.2.5.67 After DOCTYPE system identifier state
    # https://html.spec.whatwg.org/multipage/parsing.html#after-doctype-system-identifier-state
    def after_doctype_system_identifier_state(current_doctype_token)
      case get_byte
      when CHARACTER_TABULATION, LINE_FEED, FORM_FEED, SPACE
        after_doctype_system_identifier_state(current_doctype_token)
      when GREATER_THAN_SIGN
        current_doctype_token
      when nil
        # NOTE: eof-in-doctype parse error
        current_doctype_token.force_quirks_flag = true
        current_doctype_token
      else
        # NOTE: unexpected-character-after-doctype-system-identifier parse error
        back_byte
        bogus_doctype_state(current_doctype_token)
      end
    end

    # 13.2.5.68 Bogus DOCTYPE state
    # NOTE: https://html.spec.whatwg.org/multipage/parsing.html#bogus-doctype-state
    def bogus_doctype_state(current_doctype_token)
      loop do
        case get_byte
        when GREATER_THAN_SIGN
          return current_doctype_token
        when NULL
          # NOTE: unexpected-null-character parse error
          # ignore the character
        when nil
          return current_doctype_token
        else
          # ignore the character
        end
      end
    end

    # 13.2.5.69 CDATA section state
    # https://html.spec.whatwg.org/multipage/parsing.html#cdata-section-state
    def cdata_section_state
    end

    # 13.2.5.70 CDATA section bracket state
    # https://html.spec.whatwg.org/multipage/parsing.html#cdata-section-bracket-state
    def cdata_section_bracket_state
    end

    # 13.2.5.71 CDATA section end state
    # https://html.spec.whatwg.org/multipage/parsing.html#cdata-section-end-state
    def cdata_section_end_state
    end

    # 13.2.5.72 Character reference state
    # https://html.spec.whatwg.org/multipage/parsing.html#character-reference-state
    def character_reference_state(current_token = nil)
      temporary_buffer = ''
      temporary_buffer << AMPERSAND

      case current_input_character = get_byte
      when /[A-Za-z0-9]/
        back_byte
        named_character_reference_state(temporary_buffer, current_token)
      when NUMBER_SIGN
        temporary_buffer << current_input_character
        numeric_character_reference_state(temporary_buffer, current_token)
      else
        temporary_buffer << current_input_character
        flush_code_points_consumed_as_a_character_reference(temporary_buffer)
        back_byte
        call_return_state(*current_token)
      end
    end

    # 13.2.5.73 Named character reference state
    # https://html.spec.whatwg.org/multipage/parsing.html#named-character-reference-state
    def named_character_reference_state(temporary_buffer, current_token = nil)
      # Consume the maximum number of characters possible.
      if matched_string = @scanner.check(/[A-Za-z0-9]+;/)
        temporary_buffer << matched_string
        @scanner.pos += matched_string.size

        if codepoints = NamedCharacter::CODEPOINTS[temporary_buffer]
          entity = codepoints.pack('U')

          return CharacterToken.new(entity) if current_token.nil?

          current_token.append_to_last_attribute_value(entity)
          return call_return_state(current_token)
        end

        flush_code_points_consumed_as_a_character_reference(temporary_buffer, current_token)
        return ambiguous_ampersand_state(current_token)
      end

      while current_input_character = get_byte
        temporary_buffer << current_input_character

        case current_input_character
        when /[A-Za-z0-9]/
          next if (codepoints = NamedCharacter::CODEPOINTS[temporary_buffer]).nil?

          # NOTE: missing-semicolon-after-character-reference parse error
          return CharacterToken.new(codepoints.pack('U')) if current_token.nil?

          current_token.append_to_last_attribute_value(codepoints.pack('U'))
          return call_return_state(current_token)
        else
          flush_code_points_consumed_as_a_character_reference(temporary_buffer, current_token)
          return ambiguous_ampersand_state(current_token)
        end
      end
    end

    # 13.2.5.74 Ambiguous ampersand state
    # https://html.spec.whatwg.org/multipage/parsing.html#ambiguous-ampersand-state
    def ambiguous_ampersand_state(current_token = nil)
      case current_input_character = get_byte
      when /[A-Za-z0-9]/
        flush_code_points_consumed_as_a_character_reference(current_input_character, current_token)
      when SEMICOLON
        # NOTE: unknown-named-character-reference parse error
        back_byte
        call_return_state(*current_token)
      else
        back_byte
        call_return_state(*current_token)
      end
    end

    # 13.2.5.75 Numeric character reference state
    # https://html.spec.whatwg.org/multipage/parsing.html#numeric-character-reference-state
    def numeric_character_reference_state(temporary_buffer, current_token = nil)
      character_reference_code = 0

      case current_input_character = get_byte
      when 'x', 'X'
        temporary_buffer << current_input_character
        hexadecimal_character_reference_start_state(temporary_buffer, character_reference_code, current_token)
      else
        back_byte
        decimal_character_reference_start_state(temporary_buffer, character_reference_code, current_token)
      end
    end

    # 13.2.5.76 Hexadecimal character reference start state
    # https://html.spec.whatwg.org/multipage/parsing.html#hexadecimal-character-reference-start-state
    def hexadecimal_character_reference_start_state(temporary_buffer, character_reference_code, current_token = nil)
      case get_byte
      when /[0-9ABCDEFabcdef]/
        back_byte
        hexadecimal_character_reference_state(temporary_buffer, character_reference_code, current_token)
      else
        # NOTE: absence-of-digits-in-numeric-character-reference parse error
        flush_code_points_consumed_as_a_character_reference(temporary_buffer, current_token)
        back_byte
        call_return_state(*current_token)
      end
    end

    # 13.2.5.77 Decimal character reference start state
    # https://html.spec.whatwg.org/multipage/parsing.html#decimal-character-reference-start-state
    def decimal_character_reference_start_state(temporary_buffer, character_reference_code, current_token = nil)
      case get_byte
      when /[0-9]/
        back_byte
        decimal_character_reference_state(temporary_buffer, character_reference_code, current_token)
      else
        # NOTE: absence-of-digits-in-numeric-character-reference parse error
        flush_code_points_consumed_as_a_character_reference(temporary_buffer, current_token)
        back_byte
        call_return_state(*current_token)
      end
    end

    # 13.2.5.78 Hexadecimal character reference state
    # https://html.spec.whatwg.org/multipage/parsing.html#hexadecimal-character-reference-state
    def hexadecimal_character_reference_state(temporary_buffer, character_reference_code, current_token = nil)
      loop do
        case current_input_character = get_byte
        when /[0-9]/
          character_reference_code *= 16
          character_reference_code += current_input_character.to_i
        when /[ABCDEF]/
          character_reference_code *= 16
          character_reference_code += (current_input_character.codepoints.first - 0x37)
        when /[abcdef]/
          character_reference_code *= 16
          character_reference_code += (current_input_character.codepoints.first - 0x57)
        when SEMICOLON
          return numeric_character_reference_end_state(temporary_buffer, character_reference_code, current_token)
        else
          # NOTE: missing-semicolon-after-character-reference parse error
          back_byte
          return numeric_character_reference_end_state(temporary_buffer, character_reference_code, current_token)
        end
      end
    end

    # 13.2.5.79 Decimal character reference state
    # https://html.spec.whatwg.org/multipage/parsing.html#decimal-character-reference-state
    def decimal_character_reference_state(temporary_buffer, character_reference_code, current_token = nil)
      loop do
        case current_input_character = get_byte
        when /[0-9]/
          character_reference_code *= 10
          character_reference_code += current_input_character.to_i
        when SEMICOLON
          return numeric_character_reference_end_state(temporary_buffer, character_reference_code, current_token)
        else
          # NOTE: missing-semicolon-after-character-reference parse error
          back_byte
          return numeric_character_reference_end_state(temporary_buffer, character_reference_code, current_token)
        end
      end
    end

    # 13.2.5.80 Numeric character reference end state
    # https://html.spec.whatwg.org/multipage/parsing.html#numeric-character-reference-end-state
    def numeric_character_reference_end_state(temporary_buffer, character_reference_code, current_token = nil)
      if character_reference_code == 0x00
        # NOTE: null-character-reference parse error
        character_reference_code = REPLACEMENT_CHARACTER
      elsif character_reference_code > 0x10FFFF
        # NOTE: character-reference-outside-unicode-range parse error.
        character_reference_code = REPLACEMENT_CHARACTER
      elsif Character.surrogate?(character_reference_code)
        # NOTE: surrogate-character-reference parse error
        character_reference_code = REPLACEMENT_CHARACTER
      elsif Character.noncharacter?(character_reference_code)
        # NOTE: noncharacter-character-reference parse error
        # The parser resolves such character references as-is.
      elsif character_reference_code == 0x0D || (Character.control?(character_reference_code) && !Character.ascii_whitespace?(character_reference_code))
        # NOTE: control-character-reference parse error
        if codepoint = CONTROL_CHARECTER_REFERENCE_TABLE[character_reference_code]
          character_reference_code = [codepoint].pack('U')
        end
      end

      temporary_buffer = character_reference_code
      flush_code_points_consumed_as_a_character_reference(temporary_buffer, current_token)
      call_return_state(*current_token)
    end

    def back_byte
      @scanner.pos -= 1
    end

    def get_byte
      @scanner.get_byte
    end

    def flush_code_points_consumed_as_a_character_reference(temporary_buffer, current_token = nil)
      entity = if NamedCharacter::CODEPOINTS[temporary_buffer]
                 NamedCharacter::CODEPOINTS[temporary_buffer].pack('U')
               else
                 temporary_buffer
               end

      if current_token
        current_token.append_to_last_attribute_value(entity)
        call_return_state(current_token)
      else
        @buffer.concat(temporary_buffer.to_s.chars.map { |char| CharacterToken.new(char) })
      end
    end

    def call_return_state(*args)
      send(@return_state, *args)
    end

    def set_return_state(state_name)
      @return_state = state_name
    end

    def consumed_as_part_of_an_attribute?
      %i[attribute_value_double_quoted_state attribute_value_single_quoted_state attribute_value_unquoted_state].include?(@return_state)
    end

    def debug(*args)
      raise "debug method called in #{caller[0]}" unless ENV['DEBUG']

      # rubocop:disable InternalAffairs/Debug
      puts '>>>> debug'
      args.each { |arg| pp arg }
      pp caller[0]
      puts '<<<< debug'
      puts
      # rubocop:enable InternalAffairs/Debug
    end
  end
end
