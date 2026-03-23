module Merchants
  class Normalize
    def self.call(text)
      I18n.transliterate(text.to_s)
          .upcase
          .strip
          .gsub(/[0-9]/, ' ')
          .gsub(/[^A-Z\s]/, ' ')
          .gsub(/\s+/, ' ')
          .strip
    end
  end
end
