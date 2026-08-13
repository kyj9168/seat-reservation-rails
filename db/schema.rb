# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_10_060000) do
  create_table "payments", force: :cascade do |t|
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.datetime "paid_at", null: false
    t.string "refund_reason"
    t.datetime "refunded_at"
    t.integer "seat_slot_id", null: false
    t.string "status", default: "paid", null: false
    t.string "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["seat_slot_id"], name: "index_payments_on_active_paid_seat_slot", unique: true, where: "status = 'paid'"
    t.index ["seat_slot_id"], name: "index_payments_on_seat_slot_id"
    t.index ["transaction_id"], name: "index_payments_on_transaction_id", unique: true
    t.index ["user_id"], name: "index_payments_on_user_id"
    t.check_constraint "(status = 'paid' AND refunded_at IS NULL) OR (status = 'refunded' AND refunded_at IS NOT NULL)", name: "payments_refund_consistency"
    t.check_constraint "amount > 0", name: "payments_positive_amount"
    t.check_constraint "status IN ('paid', 'refunded')", name: "payments_status"
  end

  create_table "reservation_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "details", default: {}, null: false
    t.string "event_type", null: false
    t.datetime "occurred_at", null: false
    t.integer "payment_id"
    t.integer "seat_slot_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["payment_id"], name: "index_reservation_events_on_payment_id"
    t.index ["seat_slot_id", "occurred_at"], name: "index_reservation_events_on_seat_slot_id_and_occurred_at"
    t.index ["seat_slot_id"], name: "index_reservation_events_on_seat_slot_id"
    t.index ["user_id"], name: "index_reservation_events_on_user_id"
  end

  create_table "seat_slots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "hold_expires_at"
    t.integer "lock_version", default: 0, null: false
    t.date "reservation_date", null: false
    t.integer "seat_id", null: false
    t.string "status", default: "available", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["seat_id", "reservation_date"], name: "index_seat_slots_on_seat_id_and_reservation_date", unique: true
    t.index ["seat_id"], name: "index_seat_slots_on_seat_id"
    t.index ["user_id", "reservation_date"], name: "index_seat_slots_on_user_id_and_reservation_date", unique: true, where: "user_id IS NOT NULL"
    t.index ["user_id"], name: "index_seat_slots_on_user_id"
    t.check_constraint "(status = 'available' AND user_id IS NULL AND hold_expires_at IS NULL) OR (status = 'held' AND user_id IS NOT NULL AND hold_expires_at IS NOT NULL) OR (status = 'reserved' AND user_id IS NOT NULL AND hold_expires_at IS NULL)", name: "seat_slots_state_consistency"
    t.check_constraint "status IN ('available', 'held', 'reserved')", name: "seat_slots_status"
  end

  create_table "seats", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.boolean "test_only", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "zone", null: false
    t.index ["label"], name: "index_seats_on_label", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "payments", "seat_slots"
  add_foreign_key "payments", "users"
  add_foreign_key "reservation_events", "payments"
  add_foreign_key "reservation_events", "seat_slots"
  add_foreign_key "reservation_events", "users"
  add_foreign_key "seat_slots", "seats"
  add_foreign_key "seat_slots", "users"
  add_foreign_key "sessions", "users"
end
