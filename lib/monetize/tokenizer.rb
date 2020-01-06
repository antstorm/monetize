require 'monetize/parser'

module Monetize
  class Tokenizer
    SYMBOLS = Monetize::Parser::CURRENCY_SYMBOLS.keys.map { |symbol| Regexp.escape(symbol) }.freeze
    THOUSAND_SEPARATORS = /[\.\ ,]/.freeze
    DECIMAL_MARKS = /[\.,]/.freeze
    MULTIPLIERS = Monetize::Parser::MULTIPLIER_SUFFIXES.keys.join('|').freeze

    SYMBOL_REGEXP = Regexp.new(SYMBOLS.join('|')).freeze
    CURRENCY_ISO_REGEXP = /(?<![A-Z])[A-Z]{3}(?![A-Z])/i.freeze
    SIGN_REGEXP = /[\-\+]/.freeze
    AMOUNT_REGEXP = %r{
      (?<amount>                         # amount group
        \d+                              # starts with at least one digit
        (?:#{THOUSAND_SEPARATORS}\d{3})* # separated into groups of 3 digits by a thousands separator
        (?!\d)                           # not followed by a digit
        (?:#{DECIMAL_MARKS}\d+)?         # has decimal mark followed by decimal part
      )
      (?<multiplier>#{MULTIPLIERS})?     # optional multiplier
    }ix.freeze

    class Token < Struct.new(:type, :match); end

    def initialize(input, options = {})
      @input = input
      @options = options
    end

    def process
      result = []

      result += match_currency_iso
      result += match_symbol
      result += match_sign
      result += match_amount

      result = result.sort_by { |token| token.match.offset(0).first }

      preview(result)

      result
    end

    private

    attr_reader :input, :options

    def match_symbol
      tokens = []
      input.scan(SYMBOL_REGEXP) { tokens << generate_token(:symbol, $~) }

      tokens
    end

    def match_sign
      tokens = []
      input.scan(SIGN_REGEXP) { tokens << generate_token(:sign, $~) }

      tokens
    end

    def match_amount
      tokens = []
      input.scan(AMOUNT_REGEXP) { tokens << generate_token(:amount, $~) }

      tokens
    end

    def match_currency_iso
      tokens = []
      input.scan(CURRENCY_ISO_REGEXP) { tokens << generate_token(:currency_iso, $~) }

      tokens
    end

    # def match(type, regexp)
    #   tokens = []
    #   input.scan(regexp) { tokens << generate_token(type, Regexp.last_match) }

    #   tokens
    # end

    def generate_token(type, match)
      Token.new(type, match)
    end

    def preview(result)
      preview_input = input.dup
      result.reverse.each do |token|
        offset = token.match.offset(0)
        preview_input.slice!(offset.first, token.match.to_s.length)
        preview_input.insert(offset.first, "<#{token.type}>")
      end

      p preview_input
    end
  end
end
