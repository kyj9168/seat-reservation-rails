require "test_helper"

class SeatHoldsTest < ActiveSupport::TestCase
  test "holds an available seat for five minutes" do
    slot = seat_slots(:one)

    result = SeatHolds::Acquire.new(seat_slot: slot, user: users(:one)).call

    assert result.held?
    assert_equal users(:one), result.user
    assert_in_delta 5.minutes.from_now, result.hold_expires_at, 2.seconds
  end

  test "rejects a seat held by another user" do
    slot = seat_slots(:one)
    SeatHolds::Acquire.new(seat_slot: slot, user: users(:one)).call

    assert_raises(SeatHolds::Acquire::SeatUnavailable) do
      SeatHolds::Acquire.new(seat_slot: slot, user: users(:two)).call
    end
  end

  test "selecting another seat releases the previous hold" do
    first = seat_slots(:one)
    second = seat_slots(:two)
    SeatHolds::Acquire.new(seat_slot: first, user: users(:one)).call

    SeatHolds::Acquire.new(seat_slot: second, user: users(:one)).call

    assert first.reload.available?
    assert second.reload.held?
    assert_equal users(:one), second.user
  end

  test "trying another unavailable seat still abandons the previous hold" do
    first = seat_slots(:one)
    second = seat_slots(:two)
    SeatHolds::Acquire.new(seat_slot: first, user: users(:one)).call
    SeatHolds::Acquire.new(seat_slot: second, user: users(:two)).call

    assert_raises(SeatHolds::Acquire::SeatUnavailable) do
      SeatHolds::Acquire.new(seat_slot: second, user: users(:one)).call
    end

    assert first.reload.available?
    assert_equal users(:two), second.reload.user
  end

  test "expires an unpaid hold after five minutes" do
    slot = seat_slots(:one)
    SeatHolds::Acquire.new(seat_slot: slot, user: users(:one)).call
    slot.update_column(:hold_expires_at, 1.second.ago)

    assert_equal 1, SeatHolds::Expire.call
    assert slot.reload.available?
  end
end
