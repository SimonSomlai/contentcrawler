source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'rails', '~> 5.0'
gem 'pg', '~> 0.20'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '~> 3.1'
gem 'coffee-rails', '~> 4.2'
gem 'jquery-rails', "~> 4.2"
gem 'turbolinks', '~> 5.0'
gem 'jbuilder', '~> 2.6'
gem "pry", "~> 0.10"
gem "puma", "~> 3.8"
gem 'watir', "~> 6.2"
gem 'nokogiri', "~> 1.7"
gem 'selenium-webdriver', "~> 3.3"
gem 'social_shares', "~> 0.3"
gem 'share_counts', "~> 0.1"
gem 'open_uri_redirections', "~> 0.2"
gem 'anemone', "~> 0.7"
gem 'phantomjs', "~> 2.1"
gem 'sinatra', '~> 2.0.0.beta2'
gem 'rb-fsevent', "~> 0.9"
gem "devise", "~> 4.2"
gem "mail_form", "~> 1.6"
gem "typhoeus", "~> 1.1"
gem 'activerecord-import', '~> 0.15.0'

group :development, :test do
  gem 'web-console', '~> 3.4'
  gem 'listen', '~> 3.1'
  gem 'spring', "~> 2.0"
  gem 'spring-watcher-listen', '~> 2.0'
  gem 'htmlbeautifier', "~> 1.2"
  gem "better_errors", "~> 2.1"
  gem "meta_request", "~> 0.4"
  gem "binding_of_caller", "~> 0.7"
  gem 'byebug', "~> 9.0", platform: :mri
end

gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
