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

        DebtInstallmentService.new(debt).call
      end

      Result.new(debt: debt, errors: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(debt: debt, errors: e.record.errors)
    end
  end
end