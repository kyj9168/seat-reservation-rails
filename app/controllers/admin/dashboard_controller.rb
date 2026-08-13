class Admin::DashboardController < Admin::BaseController
  def index
    @date = requested_date
    SeatSlots::PrepareDate.call(@date)
    SeatHolds::Expire.call(date: @date)

    @slots = SeatSlot.for_date(@date)
      .joins(:seat)
      .where(seats: { test_only: false })
      .includes(:seat, :user, :payments)
      .order("seats.zone", "seats.label")
    @payments = Payment.includes(:user, seat_slot: :seat)
      .joins(:seat_slot)
      .where(seat_slots: { reservation_date: @date })
      .order(created_at: :desc)
    @events = ReservationEvent.includes(:user, seat_slot: :seat)
      .joins(:seat_slot)
      .where(seat_slots: { reservation_date: @date })
      .order(occurred_at: :desc)
      .limit(50)
  end

  private
    def requested_date
      params[:date].present? ? Date.iso8601(params[:date]) : Date.current
    rescue Date::Error
      Date.current
    end
end
