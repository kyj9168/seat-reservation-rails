module SeatHolds
  class Release
    class NotHeldByUser < StandardError; end

    def initialize(seat_slot:, user:, reason: "user_cancelled")
      @seat_slot = seat_slot
      @user = user
      @reason = reason
    end

    def call
      SqliteWriteGate.synchronize do
        SeatSlot.transaction do
          updated = SeatSlot
            .where(id: @seat_slot.id, user_id: @user.id, status: "held")
            .update_all(
              user_id: nil,
              status: "available",
              hold_expires_at: nil,
              lock_version: Arel.sql("lock_version + 1"),
              updated_at: Time.current
            )

          raise NotHeldByUser, "해당 사용자가 선점한 좌석이 아닙니다" unless updated == 1

          ReservationEvent.create!(
            seat_slot: @seat_slot,
            user: @user,
            event_type: "hold_released",
            details: { reason: @reason },
            occurred_at: Time.current
          )
        end
      end
    ensure
      Rails.cache.delete(SeatSlot.cache_key_for(@seat_slot.reservation_date))
    end
  end
end
