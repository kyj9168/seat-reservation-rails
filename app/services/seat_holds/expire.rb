module SeatHolds
  class Expire
    def self.call(now: Time.current, date: nil)
      new(now:, date:).call
    end

    def initialize(now:, date:)
      @now = now
      @date = date
    end

    def call
      expired_dates = []

      SqliteWriteGate.synchronize do
        SeatSlot.transaction do
          scope.find_each do |slot|
            user_id = slot.user_id
            updated = SeatSlot
              .where(id: slot.id, user_id:, status: "held")
              .where(hold_expires_at: ..@now)
              .update_all(
                user_id: nil,
                status: "available",
                hold_expires_at: nil,
                lock_version: Arel.sql("lock_version + 1"),
                updated_at: @now
              )
            next unless updated == 1

            expired_dates << slot.reservation_date
            ReservationEvent.create!(
              seat_slot: slot,
              user_id:,
              event_type: "hold_expired",
              details: { reason: "five_minute_timeout" },
              occurred_at: @now
            )
          end
        end
      end

      expired_dates.uniq.each { |expired_date| Rails.cache.delete(SeatSlot.cache_key_for(expired_date)) }
      expired_dates.size
    end

    private
      def scope
        result = SeatSlot.expired_holds(@now)
        @date ? result.for_date(@date) : result
      end
  end
end
