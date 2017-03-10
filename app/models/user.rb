class User < ApplicationRecord
  has_and_belongs_to_many :websites, dependent: :destroy

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,  :confirmable

end
