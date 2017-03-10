# frozen_string_literal: true
class Website < ApplicationRecord
  require 'open-uri'

  has_and_belongs_to_many :users
  has_many :articles, dependent: :destroy

  before_save do
    uri = URI.parse(link)
    uri = URI.parse("http://#{link}") if uri.scheme.nil?
    host = uri.host.downcase
    self.link = host.start_with?('www.') ? host[4..-1] : host
  end

  validates :link, uniqueness: true

  # --------------------- MODEL METHODS ----------------------
  def to_csv(options = {})
    CSV.generate(options) do |csv|
      csv << Article.column_names
      self.articles.each do |article|
        csv << article.attributes.values_at(*Article.column_names)
      end
    end
  end
end
