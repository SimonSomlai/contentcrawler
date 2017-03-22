require 'watir'
require 'nokogiri'
require 'selenium-webdriver'
require 'pry'
require 'social_shares'
require 'share_counts'
require "net/http"
require 'open-uri'
require 'open_uri_redirections'
require 'zlib'
require 'anemone'
require 'phantomjs'
require 'json'
require 'typhoeus'
require 'resolv-replace'
require 'timeout'
require 'active_record'
require 'activerecord-import'

class ScrapersController < ApplicationController
  include ActionController::Live
  include ServerSide
  include ScraperHelper

  def close_stream # Closes active stream
    redirect_to request.referrer
    exit;
  end

  def root_url(site) # Gets root domain from site to save in DB
    uri = URI.parse(site)
    uri = URI.parse("http://#{site}") if uri.scheme.nil?
    host = uri.host.downcase
    url = host.start_with?('www.') ? host[4..-1] : host
  end

  def invalid_url?(url) # Checks if given url is right format
    uri = URI.parse(url)
    !(uri.is_a?(URI::HTTP) && !uri.host.nil? && uri.to_s[-1] == "/")
  end

  def get_home_articles # Finds the articles for url on the homepage & write to stream
    link = params['scrape_job']['url']
    response.headers['Content-Type'] = 'text/event-stream'
    $sse = ServerSide::SSE.new(response.stream)
    begin
      ($sse.write(JSON.pretty_generate(:error => "true")); exit;) if invalid_url?(link)
      @scraper = WebScraper.new
      # Check if website already exists, if not -> create new.
      @website = Website.where(link: root_url(link)).first_or_create(link: root_url(link), last_crawled: Time.zone.now)
      @articles = @scraper.find_articles(link,10) # Crawl site for articles
      @articles = @articles - (@website.articles.map(&:link) & @articles) # Check for articles that don't exist yet.
      @articles.each {|article| Article.create!(link: article, crawled: false, website_id: @website.id) } # Create them
    rescue IOError
    ensure
      $sse.close
    end
  end

  def home_scan # Finds the social shares & comments for first 5 displayed articles on homepage
    links = params[:links].delete("'").split(';')
    response.headers['Content-Type'] = 'text/event-stream'
    $sse = ServerSide::SSE.new(response.stream)
    begin
      @scraper = WebScraper.new
      site = 'http://www.' + URI(links[0]).host.sub(/^https?\:\/\//, '').sub(/^www./,'')
      @articles = @scraper.grab_articles(site, links)
    rescue IOError
    ensure
      $sse.close
    end
  end

  def get_articles # Main feature -> gets all articles and all data
    link = params['scrape_job']['url']
    response.headers['Content-Type'] = 'text/event-stream'
    $sse = ServerSide::SSE.new(response.stream)
    begin
      link = 'http://www.' + link + "/" unless link.include? "://"
      ($sse.write(JSON.pretty_generate(:error => "true")); exit;) if invalid_url?(link) # Error when url
      @scraper = WebScraper.new
      # Check if website already exists, if not -> create new.
      @website = Website.where(link: root_url(link)).first_or_create(link: root_url(link), last_crawled: Time.zone.now)
      @website.update_attribute("last_crawled", Time.now)
      current_user.websites << @website unless current_user.websites.include? @website # Add site to current_user
      @articles = @scraper.find_articles(link) # Crawl site for articles
      @articles = @articles - (@website.articles.map(&:link) & @articles) # Check for articles that don't exist yet.
      $sse.write(JSON.pretty_generate(:message => "Saving new articles.. (please wait)"))
      articles = @articles.map {|article| Article.new(link: article, crawled: false, website_id: @website.id) }
      Article.import articles # Bulk insert them (more efficient than create!)
      @scraper.grab_articles # Get shares & comments for articles
      (@website.status = true; @website.save!) if @website.articles.all? { |article| article.crawled? == true }
    rescue IOError
    ensure
      $sse.close
    end
  end
end
