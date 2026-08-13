class RebuildReservationsForAuthenticatedUsers < ActiveRecord::Migration[8.1]
  def change
    drop_table :reservation_events
    drop_table :seat_slots
    drop_table :members
    drop_table :posts, if_exists: true

    add_column :seats, :test_only, :boolean, default: false, null: false

    create_table :users do |t|
      t.string :name, null: false
      t.string :username, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.boolean :admin, default: false, null: false
      t.timestamps
    end
    add_index :users, :username, unique: true
    add_index :users, :email_address, unique: true

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    create_table :seat_slots do |t|
      t.references :seat, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.date :reservation_date, null: false
      t.string :status, null: false, default: "available"
      t.datetime :hold_expires_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :seat_slots, [ :seat_id, :reservation_date ], unique: true
    add_index :seat_slots, [ :user_id, :reservation_date ], unique: true,
      where: "user_id IS NOT NULL"
    add_check_constraint :seat_slots,
      "status IN ('available', 'held', 'reserved')",
      name: "seat_slots_status"
    add_check_constraint :seat_slots, <<~SQL.squish, name: "seat_slots_state_consistency"
      (status = 'available' AND user_id IS NULL AND hold_expires_at IS NULL) OR
      (status = 'held' AND user_id IS NOT NULL AND hold_expires_at IS NOT NULL) OR
      (status = 'reserved' AND user_id IS NOT NULL AND hold_expires_at IS NULL)
    SQL

    create_table :payments do |t|
      t.references :seat_slot, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :amount, null: false
      t.string :status, null: false, default: "paid"
      t.string :transaction_id, null: false
      t.datetime :paid_at, null: false
      t.datetime :refunded_at
      t.string :refund_reason
      t.timestamps
    end
    add_index :payments, :transaction_id, unique: true
    add_index :payments, :seat_slot_id, unique: true,
      where: "status = 'paid'", name: "index_payments_on_active_paid_seat_slot"
    add_check_constraint :payments, "amount > 0", name: "payments_positive_amount"
    add_check_constraint :payments,
      "status IN ('paid', 'refunded')",
      name: "payments_status"
    add_check_constraint :payments, <<~SQL.squish, name: "payments_refund_consistency"
      (status = 'paid' AND refunded_at IS NULL) OR
      (status = 'refunded' AND refunded_at IS NOT NULL)
    SQL

    create_table :reservation_events do |t|
      t.references :seat_slot, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :payment, foreign_key: true
      t.string :event_type, null: false
      t.json :details, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :reservation_events, [ :seat_slot_id, :occurred_at ]
  end
end
