require "bcrypt"

def seed_user(username:, name:, email_address:, password:, admin: false)
  user = User.find_or_initialize_by(username:)
  user.assign_attributes(name:, email_address:, admin:)
  user.password_digest = BCrypt::Password.create(password, cost: BCrypt::Engine::MIN_COST)
  user.save!
  user
end

seed_user(
  username: "admin",
  name: "도서관 관리자",
  email_address: "admin@library.local",
  password: "admin123!",
  admin: true
)
seed_user(
  username: "demo_user",
  name: "데모 사용자",
  email_address: "demo@library.local",
  password: "password123!"
)

load_test_digest = BCrypt::Password.create("loadtest123!", cost: BCrypt::Engine::MIN_COST)
1.upto(100) do |number|
  username = format("loadtest%03d", number)
  user = User.find_or_initialize_by(username:)
  user.assign_attributes(
    name: format("동시접속 사용자 %03d", number),
    email_address: "#{username}@library.local",
    password_digest: load_test_digest,
    admin: false
  )
  user.save!
end

{
  "A" => 8,
  "B" => 8,
  "C" => 4
}.each do |zone, count|
  1.upto(count) do |number|
    seat = Seat.find_or_initialize_by(label: format("%s-%02d", zone, number))
    seat.assign_attributes(zone:, active: true, test_only: false)
    seat.save!
  end
end

test_seat = Seat.find_or_initialize_by(label: "TEST-100")
test_seat.assign_attributes(zone: "TEST", active: true, test_only: true)
test_seat.save!

Date.current.upto(30.days.from_now.to_date) do |date|
  SeatSlots::PrepareDate.call(date)
end
SeatSlot.find_or_create_by!(seat: test_seat, reservation_date: 30.days.from_now.to_date)

puts({
  users: User.count,
  sample_users: User.where("username LIKE ?", "loadtest%").count,
  seats: Seat.reservable.count,
  test_seat: test_seat.label,
  seat_slots: SeatSlot.count
})
