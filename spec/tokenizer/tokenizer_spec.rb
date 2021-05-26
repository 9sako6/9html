require 'spec_helper'

RSpec.describe Htimlee::Tokenizer do
  let(:tokenizer) { described_class.new(text) }

  context 'a tag with a href attribute' do
    let(:text) { '<a href=\'https://example.com\'>example.com</a>' }

    it do
      expect(tokenizer.next_token).to eql described_class::StartTagToken.new(
        'a', [
          described_class::Attribute.new(name: 'href', value: 'https://example.com')
        ]
      )
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('e')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('x')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('a')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('m')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('p')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('l')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('e')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('.')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('c')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('o')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('m')
      expect(tokenizer.next_token).to eql described_class::EndTagToken.new('a')
      expect(tokenizer.next_token).to eq described_class::EOF
    end
  end

  context 'comment with hyphen-minus' do
    let(:text) { '<!---- comment -- --->' }

    it do
      expect(tokenizer.next_token).to eql described_class::CommentToken.new('-- comment -- -')
      expect(tokenizer.next_token).to eq described_class::EOF
    end
  end

  context 'attribute' do
    let(:text) { '<foo double_quoted="aaa" single_quoted=\'bbb\' un_quoted=ccc></foo>' }

    it do
      expect(tokenizer.next_token).to eql described_class::StartTagToken.new(
        'foo',
        [
          described_class::Attribute.new(name: 'double_quoted', value: 'aaa'),
          described_class::Attribute.new(name: 'single_quoted', value: 'bbb'),
          described_class::Attribute.new(name: 'un_quoted', value: 'ccc')
        ]
      )
      expect(tokenizer.next_token).to eql described_class::EndTagToken.new('foo')
    end
  end

  context 'doctype' do
    context 'with public identifier and system identifier' do
      let(:text) { '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">' }

      it do
        expect(tokenizer.next_token).to eql described_class::DoctypeToken.new(
          'html',
          '-//W3C//DTD HTML 4.01 Transitional//EN',
          'http://www.w3.org/TR/html4/loose.dtd'
        )
      end
    end
  end

  context 'named characters' do
    it do
      expect(described_class.new('&amp;').next_token).to eql described_class::CharacterToken.new('&')
      expect(described_class.new('&amp').next_token).to eql described_class::CharacterToken.new('&')
      expect(described_class.new('&notin;').next_token).to eql described_class::CharacterToken.new('∉')

      token = described_class.new('&notin')
      expect(token.next_token).to eql described_class::CharacterToken.new('¬')
      expect(token.next_token).to eql described_class::CharacterToken.new('i')
      expect(token.next_token).to eql described_class::CharacterToken.new('n')

      token = described_class.new('&notit;')
      expect(token.next_token).to eql described_class::CharacterToken.new('&')
      expect(token.next_token).to eql described_class::CharacterToken.new('n')
      expect(token.next_token).to eql described_class::CharacterToken.new('o')
      expect(token.next_token).to eql described_class::CharacterToken.new('t')
      expect(token.next_token).to eql described_class::CharacterToken.new('i')
      expect(token.next_token).to eql described_class::CharacterToken.new('t')
      expect(token.next_token).to eql described_class::CharacterToken.new(';')

      token = described_class.new('<img foo="&amp;" bar=\'&amp;\' baz=&amp; />')
      expect(token.next_token).to eql described_class::StartTagToken.new(
        'img', [
          described_class::Attribute.new(name: 'foo', value: '&'),
          described_class::Attribute.new(name: 'bar', value: '&'),
          described_class::Attribute.new(name: 'baz', value: '&')
        ],
        true
      )

      token = described_class.new('<img foo="&amp" bar=\'&amp\' baz=&amp />')
      expect(token.next_token).to eql described_class::StartTagToken.new(
        'img',
        [
          described_class::Attribute.new(name: 'foo', value: '&'),
          described_class::Attribute.new(name: 'bar', value: '&'),
          described_class::Attribute.new(name: 'baz', value: '&')
        ],
        true
      )
      expect(described_class.new('&#x80;').next_token).to eql described_class::CharacterToken.new('€')
      expect(described_class.new('&#x80').next_token).to eql described_class::CharacterToken.new('€')
      # expect(described_class.new('&#64;').next_token).to eql described_class::CharacterToken.new('@')
    end
  end
end
