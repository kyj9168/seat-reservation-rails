class UsernameLookupsController < ApplicationController
  allow_unauthenticated_access

  def new
  end

  def create
    @user = User.find_by(
      name: params[:name].to_s.strip,
      email_address: params[:email_address].to_s.strip.downcase
    )
    render :new, status: @user ? :ok : :unprocessable_content
  end
end
