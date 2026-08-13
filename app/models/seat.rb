class Seat < ApplicationRecord
  RESERVATION_PRICE = 2_000

  has_many :seat_slots, dependent: :restrict_with_error

  scope :active, -> { where(active: true) }
  scope :reservable, -> { active.where(test_only: false) }
  scope :test_seats, -> { where(test_only: true) }

  validates :label, presence: true, uniqueness: true
  validates :zone, presence: true
end
