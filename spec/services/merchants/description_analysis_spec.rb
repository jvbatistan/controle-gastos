require 'rails_helper'

RSpec.describe Merchants::DescriptionAnalysis do
  describe '.call' do
    it 'separates canonical merchant from token candidates' do
      result = described_class.call('Uber Trip 1234 Fortaleza')

      expect(result.canonical_merchant).to eq('UBER')
      expect(result.normalized_description).to eq('UBER TRIP FORTALEZA')
      expect(result.token_candidates).to include('UBER', 'TRIP', 'FORTALEZA')
    end

    it 'removes accents and ignores common stopwords' do
      result = described_class.call('Pagamento de Farmácia São José')

      expect(result.normalized_description).to eq('PAGAMENTO DE FARMACIA SAO JOSE')
      expect(result.token_candidates).to eq(%w[FARMACIA SAO JOSE])
    end

    it 'builds ordered phrase candidates before single tokens' do
      result = described_class.call('Compra supermercado extra bairro')

      expect(result.phrase_candidates).to eq([
        'SUPERMERCADO EXTRA BAIRRO',
        'SUPERMERCADO EXTRA',
        'EXTRA BAIRRO'
      ])
      expect(result.match_candidates).to eq([
        'COMPRA SUPERMERCADO EXTRA BAIRRO',
        'SUPERMERCADO EXTRA BAIRRO',
        'SUPERMERCADO EXTRA',
        'EXTRA BAIRRO',
        'SUPERMERCADO',
        'EXTRA',
        'BAIRRO'
      ])
    end

    it 'canonicalizes noisy uber trip descriptions' do
      result = described_class.call('UBER UBER *TRIP HELP.U')

      expect(result.canonical_merchant).to eq('UBER')
      expect(result.normalized_description).to eq('UBER UBER TRIP HELP U')
      expect(result.token_candidates).to eq(%w[UBER UBER TRIP HELP])
    end

    it 'keeps useful person name tokens from pix-like descriptions' do
      result = described_class.call('ZP *FBIO LOPES')

      expect(result.canonical_merchant).to eq('ZP FBIO LOPES')
      expect(result.normalized_description).to eq('ZP FBIO LOPES')
      expect(result.token_candidates).to eq(%w[ZP FBIO LOPES])
      expect(result.phrase_candidates).to eq(['ZP FBIO LOPES', 'ZP FBIO', 'FBIO LOPES'])
    end

    it 'normalizes recargapay descriptions with compact suffixes' do
      result = described_class.call('RECARGAPAY *JOAOVITORSAOPAULOBR')

      expect(result.canonical_merchant).to eq('RECARGAPAY JOAOVITORSAOPAULOBR')
      expect(result.normalized_description).to eq('RECARGAPAY JOAOVITORSAOPAULOBR')
      expect(result.token_candidates).to eq(%w[RECARGAPAY JOAOVITORSAOPAULOBR])
      expect(result.phrase_candidates).to eq(['RECARGAPAY JOAOVITORSAOPAULOBR'])
    end

    it 'keeps external merchant identifiers for training platforms' do
      result = described_class.call('JIM.COM* BS TREINAMENT')

      expect(result.canonical_merchant).to eq('JIM COM BS TREINAMENT')
      expect(result.normalized_description).to eq('JIM COM BS TREINAMENT')
      expect(result.token_candidates).to eq(%w[JIM BS TREINAMENT])
      expect(result.phrase_candidates).to eq(['JIM BS TREINAMENT', 'JIM BS', 'BS TREINAMENT'])
    end
  end
end
