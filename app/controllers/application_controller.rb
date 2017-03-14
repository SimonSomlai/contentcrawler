# frozen_string_literal: true
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :initialize_form

  def initialize_form
    @contact = Contact.new
  end

  def after_sign_in_path_for(_resource_or_scope)
    root_path
  end

  def logged_in_user?
    (redirect_to new_user_session_path; flash[:notice] = "You need to be logged in for that";) unless !!current_user
  end
end
