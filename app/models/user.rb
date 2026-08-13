class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :seat_slots, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :reservation_events, dependent: :restrict_with_error

  normalizes :username, with: ->(value) { value.strip.downcase }
  normalizes :email_address, with: ->(value) { value.strip.downcase }

  validates :name, presence: true, length: { maximum: 50 }
  validates :username, presence: true, uniqueness: true,
    length: { in: 4..30 }, format: { with: /\A[a-z0-9_]+\z/ }
  validates :email_address, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def display_name
    "#{name} (#{username})"
  end

  def masked_username
    return username if username.length <= 3

    "#{username.first(3)}#{"*" * (username.length - 3)}"
  end
end
