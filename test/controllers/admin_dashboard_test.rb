require "test_helper"

class AdminDashboardTest < ActionDispatch::IntegrationTest
  test "blocks a normal user" do
    sign_in_as(users(:one))
    get admin_root_url

    assert_redirected_to root_url
  end

  test "admin sees status and refunds a payment" do
    slot = seat_slots(:one)
    SeatHolds::Acquire.new(seat_slot: slot, user: users(:one)).call
    payment = SeatPayments::Complete.new(seat_slot: slot, user: users(:one)).call
    sign_in_as(users(:admin))

    get admin_root_url(date: Date.current)
    assert_response :success
    assert_select "h1", "좌석·결제 현황"

    post refund_admin_payment_url(payment), params: { reason: "테스트 환불" }
    assert_redirected_to admin_root_url(date: Date.current)
    assert payment.reload.refunded?
    assert slot.reload.available?
  end

  test "admin can open test guide and concurrency lab" do
    sign_in_as(users(:admin))

    get test_page_url
    assert_response :success
    assert_select "h1", "브라우저 테스트 페이지"

    get admin_concurrency_test_url
    assert_response :success
    assert_select "h1", "100명 동시 예약 테스트"
  end
end
