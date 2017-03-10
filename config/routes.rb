Rails.application.routes.draw do
  # Devise routing
  devise_for :user, path: '', path_names: { sign_in: 'login', sign_out: 'logout', sign_up: 'register' }
  devise_scope :user do
    post 'register' => 'registrations#create'
  end

  authenticated :user do
    root 'websites#index', as: :authenticated_root
  end

  # Root path
  root 'pages#home'
  get "/faq" => "pages#faq", as: "faq"
  resources :websites
  resources :contacts, only: [:new, :create]

  # Scrapers routing
  get 'get-home-articles' => 'scrapers#get_home_articles', as: 'get_home_articles'
  get 'home-scan' => 'scrapers#home_scan', as: 'home_scan'

  get "get-articles" => 'scrapers#get_articles', as: "get_articles"
end
