module LoadTests
  class RunSeatReservation
    USER_COUNT = 100

    class MissingTestData < StandardError; end

    def call
      users = User.where(username: usernames).order(:username).to_a
      seat = Seat.find_by(test_only: true, label: "TEST-100")
      raise MissingTestData, "db:seed를 실행해 테스트 사용자 100명과 전용 좌석을 생성해 주세요." unless users.size == USER_COUNT && seat

      date = 30.days.from_now.to_date
      slot = SeatSlot.find_or_create_by!(seat:, reservation_date: date)
      reset_slot(slot)

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      results = race(users, slot)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      payment = Payment.paid.find_by(seat_slot: slot)

      {
        seat:,
        slot: slot.reload,
        date:,
        attempted: results.size,
        success_count: results.count { |result| result[:status] == :reserved },
        conflict_count: results.count { |result| result[:status] == :conflict },
        winner: payment&.user,
        payment:,
        elapsed: elapsed.round(3),
        errors: results.filter_map { |result| result[:error] }.uniq
      }
    end

    private
      def usernames
        1.upto(USER_COUNT).map { |number| format("loadtest%03d", number) }
      end

      def reset_slot(slot)
        SqliteWriteGate.synchronize do
          SeatSlot.transaction do
            ReservationEvent.where(seat_slot: slot).delete_all
            Payment.where(seat_slot: slot).delete_all
            slot.update_columns(
              user_id: nil,
              status: "available",
              hold_expires_at: nil,
              lock_version: slot.lock_version + 1,
              updated_at: Time.current
            )
          end
        end
      end

      def race(users, slot)
        ready = Queue.new
        start = Queue.new
        threads = users.map do |user|
          Thread.new do
            ready << true
            start.pop
            ActiveRecord::Base.connection_pool.with_connection do
              run_one_user(user, slot)
            end
          end
        end

        USER_COUNT.times { ready.pop }
        USER_COUNT.times { start << true }
        threads.map(&:value)
      end

      def run_one_user(user, slot)
        SeatHolds::Acquire.new(seat_slot: slot, user:).call
        SeatPayments::Complete.new(seat_slot: slot, user:).call
        { user_id: user.id, status: :reserved }
      rescue SeatHolds::Acquire::SeatUnavailable,
             SeatHolds::Acquire::ExistingReservation,
             SeatPayments::Complete::HoldUnavailable => error
        { user_id: user.id, status: :conflict, error: error.message }
      end
  end
end
