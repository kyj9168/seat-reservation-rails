class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[edit update]
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_password_path, alert: "요청이 너무 많습니다. 잠시 후 다시 시도해 주세요." }

  def new
  end

  def create
    user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
    if user
      PasswordsMailer.reset(user).deliver_later
      flash[:demo_password_reset_url] = edit_password_url(user.password_reset_token) if demo_mode?
    end

    redirect_to new_session_path,
      notice: "가입된 이메일이면 비밀번호 재설정 안내를 전송했습니다."
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "비밀번호를 변경했습니다. 다시 로그인해 주세요."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to new_password_path, alert: "재설정 링크가 잘못됐거나 만료되었습니다."
    end

    def demo_mode?
      Rails.env.development? || ENV["DEMO_MODE"] == "true"
    end
end
