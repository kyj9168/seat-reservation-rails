class CreateLibrarySeatReservations < ActiveRecord::Migration[8.1]
  def change
    create_table :members do |t|
      t.string :name, null: false
      t.string :membership_number, null: false
      t.timestamps
    end
    add_index :members, :membership_number, unique: true

    create_table :seats do |t|
      t.string :label, null: false
      t.string :zone, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :seats, :label, unique: true

    create_table :seat_slots do |t|
      t.references :seat, null: false, foreign_key: true
      t.references :member, null: true, foreign_key: true
      t.date :reservation_date, null: false
      t.string :status, null: false, default: "available"
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :seat_slots, [ :seat_id, :reservation_date ], unique: true
    add_index :seat_slots, [ :member_id, :reservation_date ], unique: true,
      where: "member_id IS NOT NULL",
      name: "index_seat_slots_on_member_and_date"
    add_check_constraint :seat_slots,
      "status IN ('available', 'reserved')",
      name: "seat_slots_status"
    add_check_constraint :seat_slots,
      "(status = 'available' AND member_id IS NULL) OR " \
      "(status = 'reserved' AND member_id IS NOT NULL)",
      name: "seat_slots_status_matches_member"

    create_table :reservation_events do |t|
      t.references :seat_slot, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.string :event_type, null: false
      t.json :details, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :reservation_events, [ :seat_slot_id, :occurred_at ]
  end
end
