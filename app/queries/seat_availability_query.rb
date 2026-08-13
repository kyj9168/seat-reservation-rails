class SeatAvailabilityQuery
  def initialize(date)
    @date = date
  end

  def call
    Rails.cache.fetch(SeatSlot.cache_key_for(@date), expires_in: 5.seconds) do
      SeatSlot.for_date(@date)
        .joins(:seat)
        .where(seats: { test_only: false })
        .order("seats.zone", "seats.label")
        .pluck(
          "seat_slots.id",
          "seats.label",
          "seats.zone",
          "seat_slots.status",
          "seat_slots.user_id",
          "seat_slots.hold_expires_at"
        )
        .map do |id, label, zone, status, user_id, hold_expires_at|
          {
            id: id,
            label: label,
            zone: zone,
            status: status,
            user_id: user_id,
            hold_expires_at: hold_expires_at
          }
        end
    end
  end
end
