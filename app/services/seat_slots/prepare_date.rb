module SeatSlots
  class PrepareDate
    def self.call(date)
      active_seat_ids = Seat.reservable.ids
      return if SeatSlot.for_date(date).where(seat_id: active_seat_ids).count == active_seat_ids.size

      now = Time.current
      rows = active_seat_ids.map do |seat_id|
        {
          seat_id: seat_id,
          reservation_date: date,
          status: "available",
          lock_version: 0,
          created_at: now,
          updated_at: now
        }
      end

      SeatSlot.insert_all(rows, unique_by: [ :seat_id, :reservation_date ]) if rows.any?
    end
  end
end
