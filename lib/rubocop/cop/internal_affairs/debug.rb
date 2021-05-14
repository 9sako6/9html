module RuboCop
  module Cop
    module InternalAffairs
      #
      # # bad (ok during development)
      # # using debug method
      # def some_method
      #  debug
      # end
      #
      # # good
      # def some_method
      # end
      #
      class Debug < Base
        RESTRICT_ON_SEND = %i[debug p pp puts].freeze
        MSG = 'Remove debug method'.freeze

        def on_send(node)
          add_offense(node)
        end
      end
    end
  end
end
