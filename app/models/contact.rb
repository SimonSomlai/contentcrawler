# frozen_string_literal: true
class Contact < MailForm::Base
  attribute :message
  attribute :nickname, captcha: true

  def headers
    {
      subject: 'ContentCrawl Contact Form',
      to: 'info@truetech.be',
      from: "noreply@truetech.be"
    }
  end
end
