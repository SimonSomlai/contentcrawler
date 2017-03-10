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
end
