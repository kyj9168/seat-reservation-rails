class Admin::PaymentsController < Admin::BaseController
  def refund
    payment = Payment.includes(seat_slot: :seat).find(params.expect(:id))
    PaymentRefunds::Create.new(
      payment:,
      admin: current_user,
      reason: params[:reason]
    ).call
    redirect_to admin_root_path(date: payment.seat_slot.reservation_date),
      notice: "#{payment.user.name}님의 결제를 환불하고 좌석을 반환했습니다.",
      status: :see_other
  rescue PaymentRefunds::Create::NotRefundable => error
    redirect_to admin_root_path, alert: error.message, status: :see_other
  end
end
