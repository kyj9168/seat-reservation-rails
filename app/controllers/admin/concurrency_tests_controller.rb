class Admin::ConcurrencyTestsController < Admin::BaseController
  def show
    @sample_user_count = User.where("username LIKE ?", "loadtest%").count
    @test_seat = Seat.find_by(test_only: true)
  end

  def create
    @result = LoadTests::RunSeatReservation.new.call
    @sample_user_count = 100
    @test_seat = @result[:seat]
    render :show
  rescue LoadTests::RunSeatReservation::MissingTestData => error
    redirect_to admin_concurrency_test_path, alert: error.message
  end
end
