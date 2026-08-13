module PaymentRefunds
  class Create
    class NotRefundable < StandardError; end

    def initialize(payment:, admin:, reason:)
      @payment = payment
      @admin = admin
      @reason = reason.presence || "관리자 환불"
    end

    def call
      SqliteWriteGate.synchronize { refund_in_sqlite }
    ensure
      Rails.cache.delete(SeatSlot.cache_key_for(@payment.seat_slot.reservation_date))
    end

    private
      def refund_in_sqlite
        now = Time.current

        Payment.transaction do
          refunded = Payment
            .where(id: @payment.id, status: "paid", refunded_at: nil)
            .update_all(
              status: "refunded",
              refunded_at: now,
              refund_reason: @reason,
              updated_at: now
            )
          raise NotRefundable, "이미 환불됐거나 환불할 수 없는 결제입니다" unless refunded == 1

          released = SeatSlot
            .where(id: @payment.seat_slot_id, user_id: @payment.user_id, status: "reserved")
            .update_all(
              user_id: nil,
              status: "available",
              hold_expires_at: nil,
              lock_version: Arel.sql("lock_version + 1"),
              updated_at: now
            )
          raise NotRefundable, "결제와 좌석 예약 상태가 일치하지 않습니다" unless released == 1

          ReservationEvent.create!(
            seat_slot_id: @payment.seat_slot_id,
            user_id: @payment.user_id,
            payment: @payment,
            event_type: "refunded",
            details: { reason: @reason, admin_id: @admin.id, amount: @payment.amount },
            occurred_at: now
          )
        end

        @payment.reload
      end
  end
end
