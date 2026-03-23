module Merchants
  class DescriptionAnalysis
    STOPWORDS = %w[
      A AO AOS AS COMPRA COM DA DAS DE DEBITO DO DOS E EM NA NAS NO NOS O OS
      PAGAMENTO PARA PARC PARCELA PARCELADO PGTO POR UMA UM
    ].freeze

    Result = Struct.new(
      :canonical_merchant,
      :normalized_description,
      :phrase_candidates,
      :token_candidates,
      keyword_init: true
    ) do
      def match_candidates
        [canonical_merchant, normalized_description, *phrase_candidates, *token_candidates]
          .map { |candidate| candidate.to_s.upcase.strip }
          .reject(&:blank?)
          .uniq
      end
    end

    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text
    end

    def call
      normalized_description = Merchants::Normalize.call(@text)
      token_candidates = extract_relevant_tokens(normalized_description)

      Result.new(
        canonical_merchant: Merchants::Canonicalize.call(@text),
        normalized_description: normalized_description,
        phrase_candidates: build_phrase_candidates(token_candidates),
        token_candidates: token_candidates
      )
    end

    private

    def extract_relevant_tokens(normalized_description)
      normalized_description.to_s.split.filter_map do |token|
        next if token.length < 2
        next if STOPWORDS.include?(token)

        token
      end
    end

    def build_phrase_candidates(tokens)
      candidates = []

      [3, 2].each do |size|
        next if tokens.length < size

        tokens.each_cons(size) do |group|
          candidates << group.join(' ')
        end
      end

      candidates
    end
  end
end
