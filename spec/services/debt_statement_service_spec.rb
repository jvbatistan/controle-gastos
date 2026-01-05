require 'rails_helper'

RSpec.describe DebtStatementService, type: :service do
  #
  # Ideia dos testes:
  #   - usamos um Card com due_date e closing_date conhecidos
  #   - criamos Debts em datas diferentes
  #   - chamamos o service
  #   - conferimos se billing_statement ficou como esperado
  #

  let(:card) do
    # Exemplo: fatura vence dia 15, fecha 7 dias antes (dia 8)
    create(:card, due_date: 15, closing_date: 7)
  end

  context 'quando a compra é feita antes do fechamento da fatura' do
    it 'lança na fatura do mesmo mês' do
      # mês de referência: novembro/2025
      transaction_date = Date.new(2025, 11, 5) # antes do fechamento (8)

      debt = build(:debt, card: card, transaction_date: transaction_date)

      DebtStatementService.new(debt).call

      # closing_date = 15/11 - 7 dias = 08/11
      # como compra dia 05/11 < 08/11 → vai pra fatura de novembro
      expect(debt.billing_statement).to eq(Date.new(2025, 11, 15))
    end
  end

  context 'quando a compra é feita no dia do fechamento ou depois' do
    it 'lança na fatura do mês seguinte' do
      # fechamento dia 08/11, compra dia 08/11
      transaction_date = Date.new(2025, 11, 8)

      debt = build(:debt, card: card, transaction_date: transaction_date)

      DebtStatementService.new(debt).call

      # regra que você implementou:
      #   se transaction_date >= closing_date → próxima fatura
      # próxima fatura = 15/12
      expect(debt.billing_statement).to eq(Date.new(2025, 12, 15))
    end
  end

  context 'quando é dezembro e cai na fatura de janeiro' do
    it 'vira corretamente o ano' do
      # mesmo cartão: vence 15, fecha 8
      # compra depois do fechamento de dezembro
      transaction_date = Date.new(2025, 12, 10) # > 08/12

      debt = build(:debt, card: card, transaction_date: transaction_date)

      DebtStatementService.new(debt).call

      # Deve ir pra fatura de 15/01/2026
      expect(debt.billing_statement).to eq(Date.new(2026, 1, 15))
    end
  end
end
