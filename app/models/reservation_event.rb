class ReservationEvent < ApplicationRecord
  belongs_to :seat_slot
  belongs_to :user
  belongs_to :payment, optional: true

  enum :event_type, {
    held: "held",
    hold_released: "hold_released",
    hold_expired: "hold_expired",
    paid: "paid",
    refunded: "refunded"
  }, validate: true

  validates :occurred_at, presence: true
end
