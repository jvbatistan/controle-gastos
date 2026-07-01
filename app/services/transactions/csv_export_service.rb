require 'csv'

module Transactions
  class CsvExportService
    HEADERS = [
      'ID',
      'Data',
      'Competência/Fatura',
      'Descrição',
      'Observação',
      'Tipo',
      'Origem',
      'Conta',
      'Cartão',
      'Categoria',
      'Responsável',
      'Valor',
      'Valor assinado',
      'Pago?',
      'Parcela atual',
      'Total de parcelas',
      'Grupo de parcelamento',
      'Arquivado?',
      'Ignorado no pagamento?',
      'Criado em',
      'Atualizado em'
    ].freeze

    SOURCE_LABELS = {
      'card' => 'cartão',
      'cash' => 'dinheiro',
      'bank' => 'banco'
    }.freeze

    KIND_LABELS = {
      'income' => 'receita',
      'expense' => 'despesa'
    }.freeze

    def self.call(transactions)
      new(transactions).call
    end

    def initialize(transactions)
      @transactions = transactions
    end

    def call
      CSV.generate(col_sep: ';', force_quotes: true) do |csv|
        csv << HEADERS
        @transactions.each { |transaction| csv << row_for(transaction) }
      end
    end

    private

    def row_for(transaction)
      [
        transaction.id,
        date_value(transaction.date),
        date_value(transaction.billing_statement),
        transaction.description,
        transaction.note,
        type_label(transaction),
        SOURCE_LABELS.fetch(transaction.source, transaction.source),
        transaction.account&.name,
        transaction.card&.name,
        transaction.category&.name,
        transaction.responsible,
        money_value(transaction.value),
        money_value(transaction.signed_value),
        boolean_label(transaction.paid?),
        transaction.installment_number,
        transaction.installments_count,
        transaction.installment_group_id,
        boolean_label(transaction.archived?),
        boolean_label(transaction.ignored_for_payment?),
        datetime_value(transaction.created_at),
        datetime_value(transaction.updated_at)
      ]
    end

    def type_label(transaction)
      return 'estorno' if transaction.refund?

      KIND_LABELS.fetch(transaction.kind, transaction.kind)
    end

    def boolean_label(value)
      value ? 'sim' : 'não'
    end

    def money_value(value)
      format('%.2f', value.to_d)
    end

    def date_value(value)
      value&.to_date&.iso8601
    end

    def datetime_value(value)
      value&.in_time_zone&.strftime('%Y-%m-%d %H:%M:%S')
    end
  end
end
