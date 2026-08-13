class SeatSlot < ApplicationRecord
  belongs_to :seat
  belongs_to :user, optional: true
  has_many :payments, dependent: :restrict_with_error
  has_many :reservation_events, dependent: :restrict_with_error

  enum :status, { available: "available", held: "held", reserved: "reserved" }, validate: true

  validates :reservation_date, presence: true, uniqueness: { scope: :seat_id }
  validates :user_id, uniqueness: { scope: :reservation_date }, allow_nil: true
  validate :state_is_consistent

  scope :for_date, ->(date) { where(reservation_date: date) }
  scope :expired_holds, ->(now = Time.current) { held.where(hold_expires_at: ..now) }

  def self.cache_key_for(date)
    "library-seat-map:v2:#{date.iso8601}"
  end

  def held_by?(candidate)
    held? && user_id == candidate.id && hold_expires_at&.future?
  end

  def active_payment
    payments.paid.order(created_at: :desc).first
  end

  private
    def state_is_consistent
      return if available? && user_id.nil? && hold_expires_at.nil?
      return if held? && user_id.present? && hold_expires_at.present?
      return if reserved? && user_id.present? && hold_expires_at.nil?

      errors.add(:status, "좌석 상태와 사용자·선점 시간이 일치하지 않습니다")
    end
end
