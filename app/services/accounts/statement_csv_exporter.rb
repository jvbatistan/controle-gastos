require "csv"

module Accounts
  class StatementCsvExporter
    MOVEMENT_TYPE_LABELS = {
      "initial_balance" => "Saldo inicial",
      "income" => "Entrada",
      "expense" => "Saída",
      "card_statement_payment" => "Pagamento de fatura",
      "transfer_in" => "Transferência recebida",
      "transfer_out" => "Transferência enviada"
    }.freeze

    DIRECTION_LABELS = {
      "credit" => "Entrada",
      "debit" => "Saída"
    }.freeze

    ACCOUNT_KIND_LABELS = {
      "checking" => "Conta corrente",
      "savings" => "Poupança",
      "wallet" => "Carteira",
      "digital_wallet" => "Carteira digital",
      "other" => "Outra"
    }.freeze

    SOURCE_LABELS = {
      "cash" => "Dinheiro",
      "bank" => "Banco",
      "card" => "Cartão"
    }.freeze

    ITEM_HEADERS = [
      "Data",
      "Tipo",
      "Direção",
      "Descrição",
      "Categoria",
      "Origem",
      "Conta contraparte",
      "Valor"
    ].freeze

    def self.call(result)
      new(result).call
    end

    def self.filename(result, date: Time.zone.today)
      account_name = ActiveSupport::Inflector.transliterate(result.account.name)
                                                .downcase
                                                .gsub(/[^a-z0-9]+/, "-")
                                                .gsub(/\A-+|-+\z/, "")
      account_name = "conta" if account_name.blank?

      "finch-extrato-#{account_name}-#{date.iso8601}.csv"
    end

    def initialize(result)
      @result = result
    end

    def call
      csv_content = CSV.generate(col_sep: ";", force_quotes: true) do |csv|
        add_document_header(csv)
        csv << []
        csv << ITEM_HEADERS

        if result.items.empty?
          csv << ["Nenhuma movimentação no período."]
        else
          result.items.each { |entry| csv << row_for(entry) }
        end
      end

      "\uFEFF#{csv_content}"
    end

    private

    attr_reader :result

    def add_document_header(csv)
      csv << ["Finch"]
      csv << ["Extrato por Account"]
      csv << []
      csv << ["Conta", result.account.name]
      csv << ["Tipo", ACCOUNT_KIND_LABELS.fetch(result.account.kind, result.account.kind)]
      csv << ["Status", result.account.archived? ? "Arquivada" : "Ativa"]
      csv << []
      csv << ["Período", period_label]
      csv << []
      csv << ["Filtros", filters_label]
      csv << []
      csv << ["Saldo de abertura", money_value(result.balances[:opening_balance])]
      csv << ["Entradas", money_value(result.summary[:credits_total])]
      csv << ["Saídas", money_value(result.summary[:debits_total])]
      csv << ["Variação líquida", money_value(result.summary[:net_total])]
      csv << ["Saldo de fechamento", money_value(result.balances[:closing_balance])]
    end

    def period_label
      start_date = result.period[:start_date]&.iso8601
      end_date = result.period[:end_date]&.iso8601

      return "#{start_date} a #{end_date}" if start_date && end_date
      return "A partir de #{start_date}" if start_date
      return "Até #{end_date}" if end_date

      "Todo o período"
    end

    def filters_label
      filters = []
      movement_type = result.filters[:movement_type]
      direction = result.filters[:direction]
      filters << "Tipo: #{MOVEMENT_TYPE_LABELS.fetch(movement_type, movement_type)}" if movement_type.present?
      filters << "Direção: #{DIRECTION_LABELS.fetch(direction, direction)}" if direction.present?

      filters.presence&.join(" | ") || "Nenhum"
    end

    def row_for(entry)
      [
        entry.occurred_on.iso8601,
        MOVEMENT_TYPE_LABELS.fetch(entry.movement_type, entry.movement_type),
        DIRECTION_LABELS.fetch(entry.direction, entry.direction),
        entry.title,
        entry.metadata.dig(:category, :name),
        origin_for(entry),
        entry.metadata.dig(:counterparty_account, :name),
        money_value(entry.credit? ? entry.amount : -entry.amount)
      ]
    end

    def origin_for(entry)
      source = entry.metadata[:source]
      return SOURCE_LABELS.fetch(source, source) if source.present?
      return entry.metadata.dig(:card, :name) if entry.movement_type == "card_statement_payment"
      return "Transferência" if entry.movement_type.start_with?("transfer_")
      return "Saldo inicial" if entry.movement_type == "initial_balance"

      nil
    end

    def money_value(value)
      format("%.2f", value.to_d)
    end
  end
end
