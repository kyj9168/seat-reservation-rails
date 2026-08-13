module ApplicationHelper
  def seat_status_label(status)
    { "available" => "이용 가능", "held" => "결제 대기", "reserved" => "예약 완료" }.fetch(status, status)
  end

  def event_type_label(event_type)
    {
      "held" => "좌석 선점",
      "hold_released" => "선점 해제",
      "hold_expired" => "선점 만료",
      "paid" => "결제 완료",
      "refunded" => "환불 완료"
    }.fetch(event_type, event_type)
  end
end
