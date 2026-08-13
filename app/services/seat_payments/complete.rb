module SeatPayments
  class Complete
    class HoldUnavailable < StandardError; end

    def initialize(seat_slot:, user:)
      @seat_slot = seat_slot
      @user = user
    end

    def call
      payment = SqliteWriteGate.synchronize { pay_in_sqlite }
      raise HoldUnavailable, "선점 시간이 만료되었거나 본인의 좌석이 아닙니다" unless payment

      payment
    ensure
      Rails.cache.delete(SeatSlot.cache_key_for(@seat_slot.reservation_date))
    end

    private
      def pay_in_sqlite
        payment = nil
        now = Time.current

        SeatSlot.transaction do
          updated = SeatSlot
            .where(id: @seat_slot.id, user_id: @user.id, status: "held")
            .where("hold_expires_at > ?", now)
            .update_all(
              status: "reserved",
              hold_expires_at: nil,
              lock_version: Arel.sql("lock_version + 1"),
              updated_at: now
            )

          if updated == 1
            payment = Payment.create!(
              seat_slot: @seat_slot,
              user: @user,
              amount: Seat::RESERVATION_PRICE,
              status: "paid",
              transaction_id: "SIM-#{SecureRandom.uuid}",
              paid_at: now
            )
            ReservationEvent.create!(
              seat_slot: @seat_slot,
              user: @user,
              payment:,
              event_type: "paid",
              details: { amount: payment.amount, provider: "simulation" },
              occurred_at: now
            )
          else
            release_if_expired(now)
          end
        end

        payment
      end

      def release_if_expired(now)
        expired = SeatSlot
          .where(id: @seat_slot.id, user_id: @user.id, status: "held")
          .where(hold_expires_at: ..now)
          .update_all(
            user_id: nil,
            status: "available",
            hold_expires_at: nil,
            lock_version: Arel.sql("lock_version + 1"),
            updated_at: now
          )
        return unless expired == 1

        ReservationEvent.create!(
          seat_slot: @seat_slot,
          user: @user,
          event_type: "hold_expired",
          details: { reason: "payment_after_timeout" },
          occurred_at: now
        )
      end
  end
end
