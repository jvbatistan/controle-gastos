module Merchants
  class Normalize
    def self.call(text)
      text.to_s
          .upcase
          .strip
          .gsub(/[0-9]/, ' ')
          .gsub(/[^A-Z\s]/, ' ')
          .gsub(/\s+/, ' ')
          .strip
    end
  end
end