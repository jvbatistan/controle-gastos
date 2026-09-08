module Transactions
  class RegisterPaymentService
    Result = Struct.new(:transaction, :payment, keyword_init: true)

    def initialize(transaction:, account:, amount:, settled_on:, settle: false)
      @transaction, @account, @amount, @settled_on, @settle = transaction, account, amount.to_d, settled_on, ActiveModel::Type::Boolean.new.cast(settle)
    end

    def call
      Transaction.transaction do
        transaction.with_lock do
          raise ArgumentError, 'Despesa já está quitada.' if transaction.paid?
          raise ArgumentError, 'Valor do pagamento deve ser maior que zero.' if amount <= 0
          raise ArgumentError, 'Pagamento acima do saldo nominal exige quitação explícita.' if amount > transaction.remaining_amount && !settle

          payment = transaction.transaction_payments.create!(account: account, amount: amount, settled_on: settled_on)
          transaction.update!(paid: true) if settle
          Result.new(transaction: transaction.reload, payment: payment)
        end
      end
    end

    private

    attr_reader :transaction, :account, :amount, :settled_on, :settle
  end
end
