module Merchants
  class Canonicalize
    # regras específicas (vai crescer com o tempo)
    RULES = [
      [/\bUBER\s*EATS\b/, "UBER EATS"],
      [/\bUBER\b/, "UBER"],
      [/\bIFOOD\b/, "IFOOD"],
    ].freeze

    def self.call(text)
      normalized = Merchants::Normalize.call(text)

      RULES.each do |pattern, canonical|
        return canonical if normalized.match?(pattern)
      end

      normalized # fallback: usa o normalizado mesmo
    end
  end
end