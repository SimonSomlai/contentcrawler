class Article < ApplicationRecord
  validates :link, uniqueness: true
  belongs_to :website
end
