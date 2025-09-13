namespace :import do
  desc "Import debts from CSV, ajustando ids de cards e categories"
  task debts: :environment do
    require "csv"

    file_path = Rails.root.join("debts.csv")

    # Mapeia os nomes dos cartões para IDs novos
    cards_map = Card.pluck(:name, :id).to_h
    categories_map = Category.pluck(:name, :id).to_h

    cards_ids_antigos = {
      16 => 'ITAÚ CLICK',
      17 => 'NUBANK',
      18 => 'PAN',
      19 => 'CASAS BAHIA',
      20 => 'ITI',
      21 => 'DIGIO',
      22 => 'WILL',
      23 => 'RENNER',
      24 => 'OUTROS',
      25 => 'RECARGA PAY'
    }

    categories_ids_antigos = {
      20 => 'Saúde',
      21 => 'Transporte',
      22 => 'Alimentação',
      23 => 'Moradia',
      24 => 'Dívidas',
      25 => 'Pessoal',
      26 => 'Pets'
    }

    puts "🔄 Importando dívidas do arquivo: #{file_path}"

    CSV.foreach(file_path, headers: true) do |row|
      card_id = cards_map[cards_ids_antigos[row["card_id"].to_i]]
      category_id = categories_map[categories_ids_antigos[row["category_id"].to_i]]

      # if card_id.nil? || category_id.nil?
      #   puts "⚠️ Pulando linha, não encontrou card/category -> #{row.inspect}"
      #   next
      # end

      Debt.create!(
        description: row["description"],
        value: row["value"],
        transaction_date: row["transaction_date"],
        billing_statement: row["billing_statement"],
        paid: row["paid"] == "true",
        has_installment: row["has_installment"] == "true",
        current_installment: row["current_installment"].to_i,
        final_installment: row["final_installment"].to_i,
        responsible: row["responsible"],
        parent_id: row["parent_id"].presence,
        card_id: card_id,
        created_at: row["created_at"],
        updated_at: row["updated_at"],
        note: row["note"],
        category_id: category_id,
        expense_type: row["expense_type"].to_i
      )
    end

    puts "✅ Importação concluída!"
  end
end
