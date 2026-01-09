module Debts
  class CreateService
    Result = Struct.new(:debt, :errors, keyword_init: true) do
      def success?
        errors.blank?
      end
    end

    def initialize(params)
      @params = params
    end

    def call
      debt = Debt.new(@params)

      Debt.transaction do
        debt.save!

        tx = build_transaction_from(debt)
        tx.save!

        debt.update!(financial_transaction: tx)

        DebtInstallmentService.new(debt).call
      end

      Result.new(debt: debt, errors: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(debt: debt, errors: e.record.errors)
    end

    private

    def build_transaction_from(debt)
      Transaction.new(
        description: debt.description,
        date: debt.transaction_date,
        kind: :expense,
        source: debt.card_id.present? ? :card : :cash,
        value: debt.value,
        card_id: debt.card_id,
        category_id: debt.category_id,
        responsible: debt.responsible,
        paid: false
      )
    end
  end
end