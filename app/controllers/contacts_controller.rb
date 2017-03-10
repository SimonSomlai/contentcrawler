# frozen_string_literal: true
class ContactsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    @contact = Contact.new(params[:contact])
    @contact.request = request
    if @contact.deliver
      respond_to do |format|
        format.html { redirect_to request.referrer }
        format.js {render layout: false}
      end
    else
      flash.now[:error] = 'Cannot send message'
      redirect_to root
    end
  end
end
