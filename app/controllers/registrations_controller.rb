# app/controllers/registrations_controller.rb
class RegistrationsController < Devise::RegistrationsController
  def new
    super
  end

  def create
    super
    user = User.find_by(email: params["user"]["email"])
    if params[:url]
      url = params[:url]
      uri = URI.parse(url)
      uri = URI.parse("http://#{url}") if uri.scheme.nil?
      host = uri.host.downcase
      url = host.start_with?('www.') ? host[4..-1] : host
      website = Website.find_by(link: url)
      user.websites << website
    end
  end

  def update
    super
  end

  def destroy
    super
  end
end
