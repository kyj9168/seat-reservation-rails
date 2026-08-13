class SeatSlotsController < ApplicationController
  before_action :set_slot, only: %i[hold release checkout pay]

  def index
    @date = requested_date
    SeatSlots::PrepareDate.call(@date)
    SeatHolds::Expire.call(date: @date)

    @slots = SeatAvailabilityQuery.new(@date).call
    @held_count = @slots.count { |slot| slot[:status] == "held" }
    @reserved_count = @slots.count { |slot| slot[:status] == "reserved" }
  end

  def hold
    SeatHolds::Acquire.new(seat_slot: @seat_slot, user: current_user).call
    response.set_header("X-Hold-Result", "held")
    redirect_to checkout_seat_slot_path(@seat_slot),
      notice: "#{@seat_slot.seat.label} 좌석을 5분간 선점했습니다.",
      status: :see_other
  rescue SeatHolds::Acquire::SeatUnavailable,
         SeatHolds::Acquire::ExistingReservation => error
    response.set_header("X-Hold-Result", "conflict")
    redirect_to seat_slots_path(date: @seat_slot.reservation_date),
      alert: error.message,
      status: :see_other
  end

  def checkout
    unless @seat_slot.held_by?(current_user)
      redirect_to seat_slots_path(date: @seat_slot.reservation_date),
        alert: "선점 시간이 만료되었거나 본인의 좌석이 아닙니다."
    end
  end

  def pay
    payment = SeatPayments::Complete.new(seat_slot: @seat_slot, user: current_user).call
    redirect_to seat_slots_path(date: @seat_slot.reservation_date),
      notice: "#{payment.amount.to_fs(:delimited)}원 결제가 완료되어 예약이 확정됐습니다.",
      status: :see_other
  rescue SeatPayments::Complete::HoldUnavailable => error
    redirect_to seat_slots_path(date: @seat_slot.reservation_date),
      alert: error.message,
      status: :see_other
  end

  def release
    SeatHolds::Release.new(seat_slot: @seat_slot, user: current_user).call
    redirect_to seat_slots_path(date: @seat_slot.reservation_date),
      notice: "좌석 선점을 취소했습니다.",
      status: :see_other
  rescue SeatHolds::Release::NotHeldByUser => error
    redirect_to seat_slots_path(date: @seat_slot.reservation_date),
      alert: error.message,
      status: :see_other
  end

  private
    def set_slot
      @seat_slot = SeatSlot.includes(:seat).find(params.expect(:id))
    end

    def requested_date
      date = params[:date].present? ? Date.iso8601(params[:date]) : Date.current
      return date if date.between?(Date.current, 30.days.from_now.to_date)

      Date.current
    rescue Date::Error
      Date.current
    end
end
