module SeatHolds
  class Acquire
    HOLD_DURATION = 5.minutes

    class SeatUnavailable < StandardError; end
    class ExistingReservation < StandardError; end

    def initialize(seat_slot:, user:)
      @seat_slot = seat_slot
      @user = user
    end

    def call
      acquired = SqliteWriteGate.synchronize { acquire_in_sqlite }
      raise SeatUnavailable, "다른 사용자가 먼저 선점한 좌석입니다" unless acquired

      @seat_slot.reload
    rescue ActiveRecord::RecordNotUnique
      raise ExistingReservation, "이 날짜에 이미 선점하거나 예약한 좌석이 있습니다"
    ensure
      Rails.cache.delete(SeatSlot.cache_key_for(@seat_slot.reservation_date))
    end

    private
      def acquire_in_sqlite
        acquired = false
        now = Time.current

        SeatSlot.transaction do
          previous_slot = SeatSlot
            .where(user_id: @user.id, reservation_date: @seat_slot.reservation_date)
            .where.not(id: @seat_slot.id)
            .first

          if previous_slot&.reserved?
            raise ExistingReservation, "결제 완료된 예약이 있어 다른 좌석을 선택할 수 없습니다"
          end

          release_previous_hold(previous_slot, now) if previous_slot&.held?

          target = SeatSlot.select(:id, :status, :user_id, :hold_expires_at).find(@seat_slot.id)
          expired_user_id = target.user_id if target.held? && target.hold_expires_at <= now

          updated = SeatSlot
            .where(id: @seat_slot.id)
            .where(
              "status = :available OR " \
              "(status = :held AND hold_expires_at <= :now) OR " \
              "(status = :held AND user_id = :user_id AND hold_expires_at > :now)",
              available: "available",
              held: "held",
              now: now,
              user_id: @user.id
            )
            .update_all(
              user_id: @user.id,
              status: "held",
              hold_expires_at: now + HOLD_DURATION,
              lock_version: Arel.sql("lock_version + 1"),
              updated_at: now
            )

          acquired = updated == 1
          next unless acquired

          record_expiration(expired_user_id, now) if expired_user_id && expired_user_id != @user.id
          ReservationEvent.create!(
            seat_slot_id: @seat_slot.id,
            user: @user,
            event_type: "held",
            details: { expires_at: (now + HOLD_DURATION).iso8601 },
            occurred_at: now
          )
        end

        acquired
      end

      def release_previous_hold(previous_slot, now)
        previous_slot.update_columns(
          user_id: nil,
          status: "available",
          hold_expires_at: nil,
          lock_version: previous_slot.lock_version + 1,
          updated_at: now
        )
        ReservationEvent.create!(
          seat_slot: previous_slot,
          user: @user,
          event_type: "hold_released",
          details: { reason: "switched_seat" },
          occurred_at: now
        )
        Rails.cache.delete(SeatSlot.cache_key_for(previous_slot.reservation_date))
      end

      def record_expiration(expired_user_id, now)
        ReservationEvent.create!(
          seat_slot_id: @seat_slot.id,
          user_id: expired_user_id,
          event_type: "hold_expired",
          details: { reason: "claimed_after_timeout" },
          occurred_at: now
        )
      end
  end
end
