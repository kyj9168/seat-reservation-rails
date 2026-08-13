require "test_helper"

class SeatSlotsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "shows daily seats to a signed in user" do
    get seat_slots_url(date: Date.current)

    assert_response :success
    assert_select "h1", "오늘의 자리를 선택하세요"
  end

  test "holds then pays for a seat" do
    slot = seat_slots(:one)

    post hold_seat_slot_url(slot)
    assert_redirected_to checkout_seat_slot_url(slot)
    assert slot.reload.held?
    assert_equal users(:one), slot.user

    post pay_seat_slot_url(slot)
    assert_redirected_to seat_slots_url(date: Date.current)
    assert slot.reload.reserved?
    assert_equal 1, slot.payments.paid.count
  end

  test "releases an unpaid hold" do
    slot = seat_slots(:one)
    SeatHolds::Acquire.new(seat_slot: slot, user: users(:one)).call

    delete release_seat_slot_url(slot)

    assert_redirected_to seat_slots_url(date: Date.current)
    assert slot.reload.available?
  end
end
