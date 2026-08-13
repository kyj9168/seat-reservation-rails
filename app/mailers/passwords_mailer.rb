class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "[도서관] 비밀번호 재설정", to: user.email_address
  end
end
