require 'spec_helper'

RSpec.describe Htimlee::Tokenizer::StartTagToken do
  let(:first_attribute) { Htimlee::Tokenizer::Attribute.new(name: 'foo', value: 'bar') }
  let(:second_attribute) { Htimlee::Tokenizer::Attribute.new(name: 'xyz', value: 'bar') }

  let(:first_token) { described_class.new('tag', [first_attribute, second_attribute]) }
  let(:second_token) { described_class.new('tag', [second_attribute, first_attribute]) }
  let(:third_token) { described_class.new('tag', [second_attribute]) }

  describe '#eql?' do
    it 'is same token' do
      expect(first_token.eql?(second_token)).to be true
    end

    it 'is different token' do
      expect(first_token.eql?(third_token)).to be false
    end
  end

  describe '#delete_duplicate_attribute!' do
    it 'has uniq attributes' do
      first_token.attributes << first_attribute.dup
      expect(first_token.attributes).to eq([first_attribute, second_attribute, first_attribute])
      first_token.delete_duplicate_attribute!
      expect(first_token.attributes).to eq([first_attribute, second_attribute])
    end
  end
end
