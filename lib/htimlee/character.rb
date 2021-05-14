module Htimlee
  module Character
    AMPERSAND = "\u0026".freeze # &
    APOSTROPHE = "\u0027".freeze # '
    CARRIAGE_RETURN = "\u000D".freeze
    CHARACTER_TABULATION = "\u0009".freeze # tab
    EQUALS_SIGN = "\u003D".freeze # =
    EXCLAMATION_MARK = "\u0021".freeze # !
    FORM_FEED = "\u000C".freeze # FF
    GRAVE_ACCENT = "\u0060".freeze # `
    GREATER_THAN_SIGN = "\u003E".freeze # >
    HYPHEN_MINUS = "\u002D".freeze # -
    LEFT_SQUARE_BRACKET = "\u005B".freeze # [
    LESS_THAN_SIGN = "\u003C".freeze # <
    LINE_FEED = "\u000A".freeze # LF
    NULL = "\u0000".freeze
    NUMBER_SIGN = "\u0023".freeze # #
    QUESTION_MARK = "\u003F".freeze # ?
    QUOTATION_MARK = "\u0022".freeze # "
    REPLACEMENT_CHARACTER = "\uFFDD".freeze
    SEMICOLON = "\u003B".freeze # ;
    SOLIDUS = "\u002F".freeze # /
    SPACE = "\u0020".freeze

    CONTROL_CHARECTER_REFERENCE_TABLE = {
      0x80 => 0x20AC, # EURO SIGN (€)
      0x82 => 0x201A, # SINGLE LOW-9 QUOTATION MARK (‚)
      0x83 => 0x0192, # LATIN SMALL LETTER F WITH HOOK (ƒ)
      0x84 => 0x201E, # DOUBLE LOW-9 QUOTATION MARK („)
      0x85 => 0x2026, # HORIZONTAL ELLIPSIS (…)
      0x86 => 0x2020, # DAGGER (†)
      0x87 => 0x2021, # DOUBLE DAGGER (‡)
      0x88 => 0x02C6, # MODIFIER LETTER CIRCUMFLEX ACCENT (ˆ)
      0x89 => 0x2030, # PER MILLE SIGN (‰)
      0x8A => 0x0160, # LATIN CAPITAL LETTER S WITH CARON (Š)
      0x8B => 0x2039, # SINGLE LEFT-POINTING ANGLE QUOTATION MARK (‹)
      0x8C => 0x0152, # LATIN CAPITAL LIGATURE OE (Œ)
      0x8E => 0x017D, # LATIN CAPITAL LETTER Z WITH CARON (Ž)
      0x91 => 0x2018, # LEFT SINGLE QUOTATION MARK (‘)
      0x92 => 0x2019, # RIGHT SINGLE QUOTATION MARK (’)
      0x93 => 0x201C, # LEFT DOUBLE QUOTATION MARK (“)
      0x94 => 0x201D, # RIGHT DOUBLE QUOTATION MARK (”)
      0x95 => 0x2022, # BULLET (•)
      0x96 => 0x2013, # EN DASH (–)
      0x97 => 0x2014, # EM DASH (—)
      0x98 => 0x02DC, # SMALL TILDE (˜)
      0x99 => 0x2122, # TRADE MARK SIGN (™)
      0x9A => 0x0161, # LATIN SMALL LETTER S WITH CARON (š)
      0x9B => 0x203A, # SINGLE RIGHT-POINTING ANGLE QUOTATION MARK (›)
      0x9C => 0x0153, # LATIN SMALL LIGATURE OE (œ)
      0x9E => 0x017E, # LATIN SMALL LETTER Z WITH CARON (ž)
      0x9F => 0x0178 # LATIN CAPITAL LETTER Y WITH DIAERESIS (Ÿ)
    }.freeze

    module_function

    def ascii_whitespace?(codepoint)
      [0x009, 0x000A, 0x000C, 0x000D, 0x0020].include?(codepoint)
    end

    def c0_control?(codepoint)
      0x0000 <= codepoint && codepoint <= 0x001F
    end

    def control?(codepoint)
      c0_control?(codepoint) || (0x007F <= codepoint && codepoint <= 0x009F)
    end

    def surrogate?(codepoint)
      0xD800 <= codepoint && codepoint <= 0xDFFF
    end

    def noncharacter?(codepoint)
      (0xFDD0 <= codepoint && codepoint <= 0xFDEF) ||
        [
          0xFFFE,
          0xFFFF,
          0x1FFFE,
          0x1FFFF,
          0x2FFFE,
          0x2FFFF,
          0x3FFFE,
          0x3FFFF,
          0x4FFFE,
          0x4FFFF,
          0x5FFFE,
          0x5FFFF,
          0x6FFFE,
          0x6FFFF,
          0x7FFFE,
          0x7FFFF,
          0x8FFFE,
          0x8FFFF,
          0x9FFFE,
          0x9FFFF,
          0xAFFFE,
          0xAFFFF,
          0xBFFFE,
          0xBFFFF,
          0xCFFFE,
          0xCFFFF,
          0xDFFFE,
          0xDFFFF,
          0xEFFFE,
          0xEFFFF,
          0xFFFFE,
          0xFFFFF,
          0x10FFFE,
          0x10FFFF
        ].include?(codepoint)
    end
  end
end
