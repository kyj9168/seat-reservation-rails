class ExpireSeatHoldsJob < ApplicationJob
  queue_as :default

  def perform
    SeatHolds::Expire.call
  end
end
