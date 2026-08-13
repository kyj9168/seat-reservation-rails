class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_session_path, alert: "로그인 시도가 너무 많습니다. 잠시 후 다시 시도해 주세요." }

  def new
  end

  def create
    credentials = params.permit(:username, :password)
    user = User.authenticate_by(
      username: credentials[:username].to_s.strip.downcase,
      password: credentials[:password]
    )

    if user
      start_new_session_for(user)
      redirect_to after_authentication_url, notice: "#{user.name}님, 환영합니다."
    else
      redirect_to new_session_path, alert: "아이디 또는 비밀번호를 확인해 주세요."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "로그아웃했습니다.", status: :see_other
  end
end
