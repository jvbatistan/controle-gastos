module DebtsHelper
  def badge_class(debt)
    case debt&.expense_type
    when "recurring"   then "bg-primary p-2"
    when "installment" then "bg-warning p-2"
    when "single"      then "bg-info p-2"
    else "bg-secondary p-2"
    end
  end

  def translated_expense_type(debt)
    debt&.expense_type ? I18n.t("activerecord.attributes.debt.expense_type.#{debt&.expense_type}") : "Não definido"
  end
end
