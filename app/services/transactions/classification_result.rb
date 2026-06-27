module Transactions
  class ClassificationResult < Struct.new(:suggested_category, :confidence, :source, keyword_init: true)
  end
end
