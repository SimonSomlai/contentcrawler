class Proxy < ApplicationRecord
  validates :ip, uniqueness: true
end
