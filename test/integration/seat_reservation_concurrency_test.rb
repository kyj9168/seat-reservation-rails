require "test_helper"

class SeatReservationConcurrencyTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  test "exactly one of 100 signed-in users can hold and pay for one seat" do
    users = create_users(100)
    seat = Seat.create!(label: "CONC-100", zone: "CONC")
    slot = SeatSlot.create!(seat:, reservation_date: 20.days.from_now.to_date)
    sessions = users.map { |user| authenticated_session_for(user) }
    Rails.application.routes.recognize_path("/seat_slots/#{slot.id}/hold", method: :post)

    ready = Queue.new
    start = Queue.new
    threads = sessions.map do |browser_session|
      Thread.new do
        ready << true
        start.pop
        browser_session.post("/seat_slots/#{slot.id}/hold")
        {
          session: browser_session,
          status: browser_session.response.status,
          result: browser_session.response.headers["X-Hold-Result"]
        }
      end
    end

    100.times { ready.pop }
    100.times { start << true }
    results = threads.map(&:value)

    assert_equal 1, results.count { |result| result[:result] == "held" }
    assert_equal 99, results.count { |result| result[:result] == "conflict" }
    assert_equal({ 303 => 100 }, results.group_by { |result| result[:status] }.transform_values(&:count))

    winner = results.find { |result| result[:result] == "held" }
    winner[:session].post("/seat_slots/#{slot.id}/pay")

    assert_equal 303, winner[:session].response.status
    assert slot.reload.reserved?
    assert_equal 1, Payment.paid.where(seat_slot: slot).count
    assert_equal 1, ReservationEvent.paid.where(seat_slot: slot).count
  ensure
    ReservationEvent.where(seat_slot_id: slot&.id).delete_all
    Payment.where(seat_slot_id: slot&.id).delete_all
    SeatSlot.where(id: slot&.id).delete_all
    Seat.where(id: seat&.id).delete_all
    Session.where(user_id: users&.map(&:id)).delete_all
    User.where(id: users&.map(&:id)).delete_all
  end

  private
    def create_users(count)
      digest = BCrypt::Password.create("password123!", cost: BCrypt::Engine::MIN_COST)
      now = Time.current
      rows = count.times.map do |number|
        {
          name: "동시 사용자 #{number}",
          username: "concurrent_#{number}",
          email_address: "concurrent_#{number}@example.com",
          password_digest: digest,
          admin: false,
          created_at: now,
          updated_at: now
        }
      end
      User.insert_all!(rows)
      User.where(username: rows.pluck(:username)).order(:username).to_a
    end

    def authenticated_session_for(user)
      browser_session = ActionDispatch::Integration::Session.new(Rails.application)
      browser_session.post(
        "/session",
        params: { username: user.username, password: "password123!" }
      )
      raise "test login failed" unless browser_session.response.redirect?

      browser_session
    end
end
