require 'spec_helper'

RSpec.describe Htimlee::Tokenizer do
  let(:tokenizer) { described_class.new(text) }

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-abrupt-closing-of-empty-comment
  describe 'abrupt-closing-of-empty-comment' do
    context 'two hyphen-minus' do
      let(:text) { '<!-->' }

      specify do
        expect(tokenizer.next_token).to eql described_class::CommentToken.new
      end
    end

    context 'three hyphen-minus' do
      let(:text) { '<!--->' }

      specify do
        expect(tokenizer.next_token).to eql described_class::CommentToken.new
      end
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-abrupt-doctype-public-identifier
  describe 'abrupt-doctype-public-identifier' do
    context 'double quoted' do
      let(:text) { '<!DOCTYPE html PUBLIC "foo>' }

      specify do
        expect(tokenizer.next_token).to eql described_class::DoctypeToken.new('html', 'foo', nil, true)
      end
    end

    context 'single quoted' do
      let(:text) { '<!DOCTYPE html PUBLIC "foo>' }

      specify do
        expect(tokenizer.next_token).to eql described_class::DoctypeToken.new('html', 'foo', nil, true)
      end
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-abrupt-doctype-system-identifier
  describe 'abrupt-doctype-system-identifier' do
    let(:text) { '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "foo>' }

    specify do
      expect(tokenizer.next_token).to eql described_class::DoctypeToken.new('html', '-//W3C//DTD HTML 4.01//EN', 'foo', true)
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-absence-of-digits-in-numeric-character-reference
  describe 'absence-of-digits-in-numeric-character-reference' do
    let(:text) { '&#qux;' }

    specify do
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('&')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('#')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('q')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('u')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('x')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new(';')
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-cdata-in-html-content
  describe 'cdata-in-html-content' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-character-reference-outside-unicode-range
  describe 'character-reference-outside-unicode-range' do
    let(:text) { '&#x110000;' }

    specify do
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new(Htimlee::Character::REPLACEMENT_CHARACTER)
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-control-character-in-input-stream
  describe 'control-character-in-input-stream' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-control-character-reference
  describe 'control-character-reference' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-end-tag-with-attributes
  describe 'end-tag-with-attributes' do
    let(:text) { '</div foo="bar">' }

    it do
      expect(tokenizer.next_token).to eql described_class::EndTagToken.new('div')
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-duplicate-attribute
  describe 'duplicate-attribute' do
    let(:text) { '<div foo="bar" foo="baz"></div>' }

    it do
      expect(tokenizer.next_token).to eql described_class::StartTagToken.new(
        'div',
        [
          described_class::Attribute.new(name: 'foo', value: 'bar')
        ]
      )
      expect(tokenizer.next_token).to eql described_class::EndTagToken.new('div')
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-end-tag-with-trailing-solidus
  describe 'end-tag-with-trailing-solidus' do
    let(:text) { '</div/>' }

    it do
      expect(tokenizer.next_token).to eql described_class::EndTagToken.new('div')
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-eof-before-tag-name
  describe 'eof-before-tag-name' do
    context 'for an end tag' do
      let(:text) { '</' }

      specify do
        expect(tokenizer.next_token).to eql described_class::CharacterToken.new('<')
        expect(tokenizer.next_token).to eql described_class::CharacterToken.new('/')
      end
    end

    context 'for a start tag' do
      let(:text) { '<' }

      specify do
        expect(tokenizer.next_token).to eql described_class::CharacterToken.new('<')
      end
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-eof-in-cdata
  describe 'eof-in-cdata' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-eof-in-comment
  describe 'eof-in-comment' do
    let(:text) { '<!-- div' }

    specify do
      expect(tokenizer.next_token).to eql described_class::CommentToken.new(' div')
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-eof-in-doctype
  describe 'eof-in-doctype' do
    let(:text) { '<!DOCTYPE html' }

    specify do
      expect(tokenizer.next_token).to eql described_class::DoctypeToken.new('html', nil, nil, true)
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-eof-in-script-html-comment-like-text
  describe 'eof-in-script-html-comment-like-text' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-eof-in-tag
  describe 'eof-in-tag' do
    let(:text) { '<div id=' }

    specify do
      expect(tokenizer.next_token).to eql described_class::EOF
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-incorrectly-closed-comment
  describe 'incorrectly-closed-comment' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-incorrectly-opened-comment
  describe 'incorrectly-opened-comment' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-invalid-character-sequence-after-doctype-name
  describe 'invalid-character-sequence-after-doctype-name' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-invalid-first-character-of-tag-name
  describe 'invalid-first-character-of-tag-name' do
    let(:text) { '<42></42>' }

    specify do
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('<')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('4')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('2')
      expect(tokenizer.next_token).to eql described_class::CharacterToken.new('>')
      expect(tokenizer.next_token).to eql described_class::CommentToken.new('42')
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-attribute-value
  describe 'missing-attribute-value' do
    let(:text) { '<div id=>' }

    specify do
      expect(tokenizer.next_token).to eql described_class::StartTagToken.new('div', [described_class::Attribute.new(name: 'id', value: '')])
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-doctype-name
  describe 'missing-doctype-name' do
    let(:text) { '<!DOCTYPE>' }

    specify do
      expect(tokenizer.next_token).to eql described_class::DoctypeToken.new('', nil, nil, true)
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-doctype-public-identifier
  describe 'missing-doctype-public-identifier' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-doctype-system-identifier
  describe 'missing-doctype-system-identifier' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-end-tag-name
  describe 'missing-end-tag-name' do
    let(:text) { '</>' }

    specify do
      expect(tokenizer.next_token).to eql described_class::EOF
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-quote-before-doctype-public-identifier
  describe 'missing-quote-before-doctype-public-identifier' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-quote-before-doctype-system-identifier
  describe 'missing-quote-before-doctype-system-identifier' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-semicolon-after-character-reference
  describe 'missing-semicolon-after-character-reference' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-whitespace-after-doctype-public-keyword
  describe 'missing-whitespace-after-doctype-public-keyword' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-whitespace-after-doctype-system-keyword
  describe 'missing-whitespace-after-doctype-system-keyword' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-whitespace-before-doctype-name
  describe 'missing-whitespace-before-doctype-name' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-whitespace-between-attributes
  describe 'missing-whitespace-between-attributes' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-missing-whitespace-between-doctype-public-and-system-identifiers
  describe 'missing-whitespace-between-doctype-public-and-system-identifiers' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-nested-comment
  describe 'nested-comment' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-noncharacter-character-reference
  describe 'noncharacter-character-reference' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-noncharacter-in-input-stream
  describe 'noncharacter-in-input-stream' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-non-void-html-element-start-tag-with-trailing-solidus
  describe 'non-void-html-element-start-tag-with-trailing-solidus' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-null-character-reference
  describe 'null-character-reference' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-surrogate-character-reference
  describe 'surrogate-character-reference' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-surrogate-in-input-stream
  describe 'surrogate-in-input-stream' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-unexpected-character-after-doctype-system-identifier
  describe 'unexpected-character-after-doctype-system-identifier' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-unexpected-character-in-attribute-name
  describe 'unexpected-character-in-attribute-name' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-unexpected-character-in-unquoted-attribute-value
  describe 'unexpected-character-in-unquoted-attribute-value' do
    let(:text) { "<div foo=b'ar'>" }

    specify do
      expect(tokenizer.next_token).to eql described_class::StartTagToken.new(
        'div',
        [
          described_class::Attribute.new(name: 'foo', value: "b'ar'")
        ]
      )
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-unexpected-equals-sign-before-attribute-name
  describe 'unexpected-equals-sign-before-attribute-name' do
    let(:text) { '<div foo="bar" ="baz">' }

    specify do
      expect(tokenizer.next_token).to eql described_class::StartTagToken.new(
        'div',
        [
          described_class::Attribute.new(name: 'foo', value: 'bar'),
          described_class::Attribute.new(name: '="baz"', value: '')
        ]
      )
    end
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-unexpected-null-character
  describe 'unexpected-null-character' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-unexpected-question-mark-instead-of-tag-name
  describe 'unexpected-question-mark-instead-of-tag-name' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-unexpected-solidus-in-tag
  describe 'unexpected-solidus-in-tag' do
  end

  # https://html.spec.whatwg.org/multipage/parsing.html#parse-error-unknown-named-character-reference
  describe 'unknown-named-character-reference' do
  end
end
