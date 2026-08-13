class Payment < ApplicationRecord
  belongs_to :seat_slot
  belongs_to :user
  has_many :reservation_events, dependent: :restrict_with_error

  enum :status, { paid: "paid", refunded: "refunded" }, validate: true

  validates :amount, numericality: { only_integer: true, greater_than: 0 }
  validates :transaction_id, presence: true, uniqueness: true
  validates :paid_at, presence: true
  validate :refund_fields_match_status

  private
    def refund_fields_match_status
      return if paid? && refunded_at.nil?
      return if refunded? && refunded_at.present?

      errors.add(:status, "환불 상태와 환불 시간이 일치하지 않습니다")
    end
end
