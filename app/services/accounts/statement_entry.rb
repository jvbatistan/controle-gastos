module Accounts
  class StatementEntry
    attr_reader :id,
                :source_type,
                :source_id,
                :movement_type,
                :direction,
                :amount,
                :occurred_on,
                :title,
                :description,
                :status,
                :metadata,
                :created_at

    def initialize(id:, source_type:, source_id:, movement_type:, direction:, amount:, occurred_on:, title:, created_at:, description: nil, status: "posted", metadata: {})
      @id = id
      @source_type = source_type
      @source_id = source_id
      @movement_type = movement_type
      @direction = direction
      @amount = amount.to_d
      @occurred_on = occurred_on.to_date
      @title = title
      @description = description
      @status = status
      @metadata = metadata
      @created_at = created_at
    end

    def credit?
      direction == "credit"
    end

    def debit?
      direction == "debit"
    end

    def as_json(*)
      {
        id: id,
        source_type: source_type,
        source_id: source_id,
        movement_type: movement_type,
        direction: direction,
        amount: amount,
        occurred_on: occurred_on,
        title: title,
        description: description,
        status: status,
        metadata: metadata
      }
    end
  end
end
