class Admin::BaseController < ApplicationController
  before_action :require_admin

  private
    def require_admin
      redirect_to root_path, alert: "관리자 권한이 필요합니다." unless current_user&.admin?
    end
end
