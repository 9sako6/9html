#
# Usage:
#   `ruby script/generate_named_character_references.rb` in the root directory.
# https://html.spec.whatwg.org/entities.json

require 'open-uri'
require 'json'

OUTPUT_PATH = './lib/htimlee/tokenizer/named_character.rb'.freeze

entities_json = JSON.parse(URI.open('https://html.spec.whatwg.org/entities.json', &:read))

source_code = <<~SOURCECODE
  # rubocop:disable all
  # This code is generated automatically with #{__FILE__}.
  module Htimlee
    class Tokenizer
      module NamedCharacter
        CODEPOINTS = {
  #{
    entities_json.map do |character_name, character_entity|
      "        '#{character_name}'.freeze => #{character_entity['codepoints']}.freeze,"
    end.join("\n")
  }
        }.freeze
      end
    end
  end
  # rubocop:enable all
SOURCECODE

# rubocop:disable InternalAffairs/Debug
File.open(OUTPUT_PATH, 'w') { |f| f.puts source_code }
# rubocop:enable InternalAffairs/Debug
