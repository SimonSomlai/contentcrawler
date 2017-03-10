class PagesController < ApplicationController
  include PagesHelper
  def home
    @user = User.new
  end

  def faq

  end
end
