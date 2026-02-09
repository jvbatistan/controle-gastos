require "securerandom"

module Transactions
  class InstallmentGeneratorService
    def initialize(transaction, current_installment:, final_installment:)
      @transaction  = transaction
      @current      = current_installment.to_i
      @final        = final_installment.to_i
    end

    def call
      validate_installments!

      group_id = SecureRandom.uuid

      Transaction.transaction do
        generate_installments(group_id)
      end

      group_id
    end

    private

    def validate_installments!
      raise ArgumentError, "final_installment inválido" if @final < 2
      raise ArgumentError, "current_installment inválido" if @current < 1 || @current > @final
    end

    def generate_installments(group_id)
      installment_value = @transaction.value.to_d
      base_date         = @transaction.date.to_date

      (@current..@final).each do |n|
        date = base_date + (n - @current).months

        Transaction.create!(
          user_id: @transaction.user_id,

          description: @transaction.description,
          value: installment_value,
          date: date,
          kind: @transaction.kind,
          source: @transaction.source,
          paid: false,
          responsible: @transaction.responsible,
          card_id: @transaction.card_id,
          category_id: @transaction.category_id,

          installment_group_id: group_id,
          installment_number: n,
          installments_count: @final
        )
      end
    end
  end
end
