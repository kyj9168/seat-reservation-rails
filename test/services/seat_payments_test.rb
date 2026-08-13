require "test_helper"

class SeatPaymentsTest < ActiveSupport::TestCase
  test "payment turns a hold into a reservation" do
    slot = seat_slots(:one)
    SeatHolds::Acquire.new(seat_slot: slot, user: users(:one)).call

    payment = SeatPayments::Complete.new(seat_slot: slot, user: users(:one)).call

    assert payment.paid?
    assert slot.reload.reserved?
    assert_nil slot.hold_expires_at
  end

  test "admin refund returns the seat" do
    slot = seat_slots(:one)
    SeatHolds::Acquire.new(seat_slot: slot, user: users(:one)).call
    payment = SeatPayments::Complete.new(seat_slot: slot, user: users(:one)).call

    PaymentRefunds::Create.new(payment:, admin: users(:admin), reason: "운영자 환불").call

    assert payment.reload.refunded?
    assert_equal "운영자 환불", payment.refund_reason
    assert slot.reload.available?
    assert_equal 1, slot.reservation_events.refunded.count
  end
end
