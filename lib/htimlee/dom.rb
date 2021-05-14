module Htimlee
  # Class for constructing DOM tree from a sequence of tokens from the tokenizer.
  #
  # 13.2.6 Tree construction
  # https://html.spec.whatwg.org/multipage/parsing.html#tree-construction
  class DOM
    include Character

    def initialize(text)
      @stack_of_open_elements = []
      @insertion_mode = :initial
      @tokenizer = Tokenizer.new(text)
      construct_tree
      @dom = []
    end

    private

    def construct_tree
      while (token = @tokenizer.next_token) != Tokenizer::EOF
        if token.is_a?(Tokenizer::StartTagToken) && [CHARACTER_TABULATION, LINE_FEED, FORM_FEED, CARRIAGE_RETURN, SPACE].include?(token.data)
          # ignore the token
          next
        elsif token.is_a?(Tokenizer::CommentToken)
          insert_comment(token)
        elsif token.is_a?(Tokenizer::DoctypeToken)
          puts token
          next
        end
      end
    end

    def insert_comment(data)
      @dom << Comment.new(data)
    end

    def reset_insertion_mode; end
  end
end
