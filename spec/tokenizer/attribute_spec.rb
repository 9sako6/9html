require 'spec_helper'

RSpec.describe Htimlee::Tokenizer::Attribute do
  let(:attribute) { described_class.new(name: 'foo', value: 'bar') }

  describe '#eql?' do
    it 'has same name and value to an other attribute' do
      expect(attribute.eql?(attribute.dup)).to be true
    end

    it 'has different name to an other attribute' do
      other_attribute = attribute.dup
      other_attribute.name = 'hello'
      expect(attribute.eql?(other_attribute)).to be false
    end

    it 'has different value to an other attribute' do
      other_attribute = attribute.dup
      other_attribute.value = 'world'
      expect(attribute.eql?(other_attribute)).to be false
    end
  end
end
