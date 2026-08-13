require "test_helper"

class SeatSlotTest < ActiveSupport::TestCase
  test "requires one slot per seat and date" do
    duplicate = SeatSlot.new(
      seat: seats(:one),
      reservation_date: seat_slots(:one).reservation_date,
      status: "available"
    )

    assert_not duplicate.valid?
  end

  test "held status requires a user and expiration" do
    slot = seat_slots(:one)
    slot.status = "held"

    assert_not slot.valid?
  end

  test "reserved status requires a user without expiration" do
    slot = seat_slots(:one)
    slot.assign_attributes(status: "reserved", user: users(:one), hold_expires_at: 1.minute.from_now)

    assert_not slot.valid?
  end
end
