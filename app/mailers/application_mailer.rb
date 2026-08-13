class ApplicationMailer < ActionMailer::Base
  default from: "no-reply@library.local"
  layout "mailer"
end
