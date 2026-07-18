class AddAccountToCardStatementPayments < ActiveRecord::Migration[6.1]
  def change
    add_reference :card_statement_payments, :account, foreign_key: true, null: true
  end
end
