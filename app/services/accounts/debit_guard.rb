module Accounts
  class DebitGuard
    class InsufficientFunds < ArgumentError; end

    def self.call(account:, amount:, &block)
      new(account: account, amount: amount).call(&block)
    end

    def initialize(account:, amount:)
      @account = account
      @amount = amount.to_d
    end

    def call
      account.with_lock do
        available_balance = Accounts::BalanceCalculator.call(account)

        if available_balance < amount
          raise InsufficientFunds,
                "Saldo insuficiente na conta #{account.name}. Disponível: #{format_currency(available_balance)}. Necessário: #{format_currency(amount)}."
        end

        yield
      end
    end

    private

    attr_reader :account, :amount

    def format_currency(value)
      "R$ #{format('%.2f', value.to_d).tr('.', ',')}"
    end
  end
end
