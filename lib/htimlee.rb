require 'htimlee/version'
require 'htimlee/tokenizer'
require 'htimlee/dom'

module Htimlee
  def self.new(text)
    DOM.new(text)
  end
end
