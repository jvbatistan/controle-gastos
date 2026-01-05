class DebtInstallmentService
  def initialize(debt)
    @debt = debt
  end

  def call
    return unless @debt.has_installment
    return if @debt.current_installment.blank? || @debt.final_installment.blank?
    return if @debt.parent_id.present?
    return unless @debt.current_installment.to_i < @debt.final_installment.to_i

    Debt.transaction do
      parent_id = @debt.id

      ((@debt.current_installment + 1)..@debt.final_installment).each do |installment_number|
        months_to_add = installment_number - @debt.current_installment

        next_debt = @debt.dup
        next_debt.transaction_date     = @debt.transaction_date + months_to_add.months
        next_debt.current_installment  = installment_number
        next_debt.parent_id            = parent_id

        next_debt.save!
      end
    end
  end
end
