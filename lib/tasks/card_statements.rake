namespace :card_statements do
  desc "Audit a card statement without changing data: rake card_statements:audit[card_id,month,year]"
  task :audit, %i[card_id month year] => :environment do |_task, args|
    card_id = Integer(args[:card_id], exception: false)
    month = Integer(args[:month], exception: false)
    year = Integer(args[:year], exception: false)

    abort "Usage: rake card_statements:audit[card_id,month,year]" unless card_id && month&.between?(1, 12) && year&.positive?

    card = Card.find(card_id)
    period_start = Date.new(year, month, 1)
    period_end = period_start.end_of_month
    statement = card.card_statements.find_by(billing_statement: card.due_on(year, month))
    transactions = card.transactions
                       .active
                       .includes(:category, :classification_suggestions)
                       .where(billing_statement: period_start..period_end)
                       .order(:date, :id)

    calculated_total = transactions.sum(&:signed_value)
    calculated_paid = statement ? statement.card_statement_payments.sum(:amount).to_d : 0.to_d
    calculated_remaining = [calculated_total - calculated_paid, 0.to_d].max
    duplicate_counts = transactions.group_by do |transaction|
      [transaction.date, transaction.description, transaction.value.to_d, transaction.refund?]
    end.transform_values(&:size)

    puts "Card: #{card.id} - #{card.name}"
    puts "Period: #{period_start.strftime('%m/%Y')}"
    puts "Closing day: #{card.closing_day_value(period_start)}"
    puts "Statement: #{statement&.id || 'not found'}"
    puts ""
    puts "Transactions:"
    puts "  id | date | statement period | card | type | status | classification | category | paid | refund | included | sign | value | description"

    transactions.each do |transaction|
      type = transaction.refund? ? "REFUND" : "PURCHASE"
      warning = transaction.card_statement_payment_description? ? " [PAYMENT-LIKE DESCRIPTION]" : ""
      duplicate_count = duplicate_counts.fetch([transaction.date, transaction.description, transaction.value.to_d, transaction.refund?])
      warning += " [POSSIBLE DUPLICATE x#{duplicate_count}]" if duplicate_count > 1
      sign = transaction.signed_value.negative? ? "-" : "+"
      puts format(
        "  %<id>d | %<date>s | %<statement>s | %<card>s | %<type>s | %<status>s | %<classification>s | %<category>s | %<paid>s | %<refund>s | YES | %<sign>s | %<value>.2f | %<description>s%<warning>s",
        id: transaction.id,
        date: transaction.date,
        statement: transaction.billing_statement,
        card: card.name,
        type: type,
        status: transaction.paid? ? "PAID" : "OPEN",
        classification: transaction.classification_status,
        category: transaction.category&.name || "Uncategorized",
        paid: transaction.paid?,
        refund: transaction.refund?,
        sign: sign,
        value: transaction.value,
        description: transaction.description,
        warning: warning
      )
    end

    puts ""
    puts "Statement payments:"
    if statement
      statement.card_statement_payments.order(:paid_at, :id).each do |payment|
        puts format(
          "  #%<id>d | %<date>s | PAYMENT | included in total: NO | included in paid: YES | %<value>10.2f | %<description>s | original transaction: %<transaction>s",
          id: payment.id,
          date: payment.paid_at.to_date,
          value: payment.amount,
          description: payment.description,
          transaction: payment.original_transaction_id || "none"
        )
      end
    end

    puts ""
    puts format("Calculated total:     %10.2f", calculated_total)
    puts format("Calculated paid:      %10.2f", calculated_paid)
    puts format("Calculated remaining: %10.2f", calculated_remaining)
    puts format("Stored total:         %10.2f", statement&.total_amount.to_d)
    puts format("Stored paid:          %10.2f", statement&.paid_amount.to_d)
    puts format("Stored remaining:     %10.2f", statement&.remaining_amount.to_d)
  end
end
