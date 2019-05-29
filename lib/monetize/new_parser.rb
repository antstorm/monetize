require 'monetize/parser'

module Monetize
  class NewParser
    def initialize(input, fallback_currency = Money.default_currency, options = {})
      @input = input.to_s
      @options = options
      @fallback_currency = fallback_currency
    end

    def parse
      puts "\n-----"
      puts input

      result = {}

      result[:symbol] = match_symbol
      result[:sign] = match_sign
      result[:amount] = match_amount
      result[:currency_iso] = match_currency_iso

      result = result.select { |key, value| !!value }.sort_by { |key, value| value.offset(0).first }

      raise "invalid input - #{result.map(&:first)}" unless ALLOWED_FORMATS.include?(result.map(&:first))

      result = result.to_h

      p result

      amount = parse_amount(result[:amount].to_s, result[:sign].to_s)

      currency =
        if result[:symbol] && assume_from_symbol?
          parse_symbol(result[:symbol].to_s)
        elsif result[:currency_iso]
          parse_currency_iso(result[:currency_iso].to_s)
        else
          fallback_currency
        end

      # puts "parsed = #{result.map(&:last).join}"
      # p result

      # result.map(&:last).join

      Money.from_amount(amount, currency)
    end

    private

    # figure out what to do with whitespaces & signs
    ALLOWED_FORMATS = [
      [:amount],
      [:sign, :amount],
      [:symbol, :amount],
      [:sign, :symbol, :amount],
      [:symbol, :sign, :amount],

      [:symbol, :amount, :sign], # ?

      [:amount, :symbol],
      [:sign, :amount, :symbol],
      [:currency_iso, :amount],
      [:currency_iso, :sign, :amount],
      [:amount, :currency_iso],
      [:sign, :amount, :currency_iso]
    ].freeze

    attr_reader :input, :fallback_currency, :options

    SYMBOLS = Monetize::Parser::CURRENCY_SYMBOLS.keys.map { |symbol| Regexp.escape(symbol) }.freeze
    SYMBOL_REGEXP = Regexp.new(SYMBOLS.join('|')).freeze

    SIGN_REGEXP = /[\-\+]/.freeze

    THOUSAND_SEPARATORS = /[\.\ ,]/.freeze
    DECIMAL_MARKS = /[\.,]/.freeze
    MULTIPLIERS = Monetize::Parser::MULTIPLIER_SUFFIXES.keys.join('|').freeze

    # how to tell between decimal mark & thousands separator
    AMOUNT_REGEXP = /\d+(#{THOUSAND_SEPARATORS}\d{3})*(#{DECIMAL_MARKS}\d+)?(#{MULTIPLIERS})?(?!(\d|#{DECIMAL_MARKS}))/.freeze

    CURRENCY_ISO_REGEXP = /(?<![A-Z])[A-Z]{3}(?![A-Z])/i.freeze

    def match_symbol
      input.match(SYMBOL_REGEXP)
    end

    def match_sign
      input.match(SIGN_REGEXP)
    end

    def match_amount
      input.scan(AMOUNT_REGEXP) { p $~ }
      input.match(AMOUNT_REGEXP)
    end

    def match_currency_iso
      input.match(CURRENCY_ISO_REGEXP)
      # match_data if match_data && Money::Currency.find(match_data.to_s)
    end

    def parse_amount(amount, sign)
      multiplier = amount.match(/#{MULTIPLIERS}/)
      amount = amount.gsub(/#{MULTIPLIERS}/, '')
      amount = amount.gsub(' ', '')

      used_delimiters = amount.scan(/[^\d]/).uniq

      num =
        case used_delimiters.length
        when 0
          amount.to_f
        when 1
          decimal_mark = used_delimiters.first
          amount = amount.gsub(decimal_mark, '.')

          amount.to_f
        when 2
          thousands_separator, decimal_mark = used_delimiters
          amount = amount.gsub(thousands_separator, '')
          amount = amount.gsub(decimal_mark, '.')

          amount.to_f
        else
          raise 'invalid amount of delimiters used'
        end

      if multiplier
        num = num * (10 ** Monetize::Parser::MULTIPLIER_SUFFIXES[multiplier.to_s])
      end

      num = num * -1 if sign == '-'

      num
    end

    def parse_symbol(symbol)
      Money::Currency.wrap(Monetize::Parser::CURRENCY_SYMBOLS[symbol])
    end

    def parse_currency_iso(currency_iso)
      Money::Currency.wrap(currency_iso)
    end

    def assume_from_symbol?
      options.key?(:assume_from_symbol) ? options[:assume_from_symbol] : Monetize.assume_from_symbol
    end
  end
end
