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
      ($sse.write(JSON.pretty_generate(:error => "true")); exit;) if invalid_url?(link)
      @scraper = WebScraper.new
      @website = Website.find_by(link: root_url(link)) # Check if website already exists, if not create new.
      @website ||= Website.create!(link: root_url(link), last_crawled: Time.zone.now)
      @website.update_attribute("last_crawled", Time.now)
      current_user.websites << @website unless current_user.websites.include? @website
      @articles = @scraper.find_articles(link) # Crawl site for articles
      @articles = @articles - (@website.articles.map(&:link) & @articles) # Check for articles that don't exist yet.
      $sse.write(JSON.pretty_generate(:message => "Saving new articles.. (please wait)"))
      articles = @articles.map {|article| Article.new(link: article, crawled: false, website_id: @website.id) }
      Article.import articles # Bulk insert them
      @scraper.grab_articles # Get shares & comments for articles
      (@website.status = true; @website.save!) if @website.articles.all? { |article| article.crawled? == true }
    rescue IOError
    ensure
      $sse.close
    end
  end

  # -------------------------------- ACTUAL SCRAPING TASKS --------------------------
  class WebScraper
    attr_accessor :all_articles, :articles, :links, :site
    def initialize
      @articles = []
      @html = ''
      @links = []
      @site = ''
      @limit = false
      @urls = ['sitemap.xml', 'sitemap']
      @disqus_found = false
      @disqus_shorthand = ''
      @root = false
      $browser = ''
      launch
    end

    # TEST SITES
    # Few articles, sitemap --> http://www.wouteeckhout.com/
    # Few articles, sitemap.xml.gz --> http://truetech.be/
    # Sitemap reference in robots.txt --> https://www.bodybuilding.com/
    # No sitemap (crawler) --> http://www.viperchill.com/, https://www.goodlookingloser.com/
    # Disqus comments --> https://www.scotthyoung.com/
    # Multiple nested sitemap --> https://www.reddit.com/

    # -------------------- FINDING ARTICLES  ------------------------------
    public

    def find_articles(site, limit = false)  # Finds articles for given website
      write("Retrieving the first #{limit} articles!", 'message', 1.5) if limit
      @limit, @site = limit, site
      find_xml_sitemap
      write_articles_to_table
      @articles
    end

    def find_xml_sitemap # Searches for /sitemap.xml & /sitemap
      sitemap_found = false; size = 0
      until sitemap_found || size > 1
        write("Searching /#{@urls[size]}")
        link = "#{@site}#{@urls[size]}"
        if has_sitemap?(link)
          write('Sitemap found!'); puts 'Sitemap found!'
          @links = parse_xml(link)
          sitemap_found = true
          has_nested_sitemap?
        else
          write('No sitemap found :(', 'message', 1); puts 'Found error page - No sitemap :('
          size += 1
        end
      end
      find_xml_gz_sitemap unless sitemap_found
    end

    def has_sitemap?(link) # Checks if the page has an XML sitemap
      return false if error_page?(link)
      # If the text matches sitemap, xml & the title is blank it's probably and .xml file.
      !!(@html.to_html[/sitemap/i] && @html.to_html[/xml/i] && $browser.title.blank?)
    end

    def find_xml_gz_sitemap # Checks for /sitemap.xml.gz
      puts 'No sitemap found on /sitemap or /sitemap.xml, trying sitemap.xml.gz'; write('Searching sitemap.xml.gz', 'message', 1)
      begin
        link = Timeout.timeout(5) { open("#{@site}sitemap.xml.gz", allow_redirections: :all, read_timeout: 5) }
        gz = Zlib::GzipReader.new(link)
        xml = gz.read
        @links = Nokogiri::XML.parse(xml).search('*//loc').map(&:inner_html)
        puts 'Sitemap.gz found!'; write('Sitemap found!', 'message', 1)
        has_nested_sitemap?
      rescue
        write('No sitemap :(', 'message', 1); find_robots_txt_sitemap
      end
    end

    def find_robots_txt_sitemap # Searches /robots.txt for reference to sitemap
      write('Searching /robots.txt', 'message', 1); puts 'No sitemap.xml.gz found, trying robots.txt'
      if robots_txt_has_sitemap?("#{@site}robots.txt")
        sitemap = parse_robots_txt
        @links = parse_xml(sitemap)
        has_nested_sitemap?
      else
        puts 'No sitemap found nor indications in robots.txt. Going to create own sitemap.'; puts 'Releasing THE KRACKEN'
        write('No valid sitemap found on site.', 'message', 1); write('Creating new sitemap (this might take a few minutes)', 'message', 1)
        write('RELEASE THE KRACKEN!'); create_new_sitemap
      end
    end

    def robots_txt_has_sitemap?(link) # Checks if robots.txt has reference to sitemap
      return false if error_page?(link)
      # If the text matches sitemap, followed by a link then it includes a reference to sitemap
      !!(@html.text[/sitemap: (https?:\/\/(?:www\.|(?!www))[^\s\.]+\.[^\s]{2,}|www\.[^\s]+\.[^\s]{2,})/i])
    end

    def create_new_sitemap # No sitemap found, creating new using anemone crawler
      Anemone.crawl(@site, depth_limit: 3, obey_robots_txt: true, skip_query_strings: true) do |anemone|
        anemone.skip_links_like /replytocom|category\/|\/about|wp-content\/|component\/|wp-includes\/|wp-json\/|.png|.jpg|.svg|.jpeg|#comment|page\/|profile\/|contact\/|author\/|store\/|products\/|tags\/|forum\/|forums\/|user\/|archive\/|tag\//i
        anemone.on_every_page do |page|
          @links << page.url.to_s
          puts "checking #{page.url}"; write("Found #{@links.size} total articles!")
          (@articles = @links; return limited_articles) if (@limit && @links.size >= 15)
        end
      end
      @articles = filter_articles(@links)
    end

    def has_nested_sitemap? # Loops over nested sitemap & adds valid links
      @articles = @links.select{|link| !link[/xml/]} # Add links without .xml extension to @articles
      if @links.any? { |link| !!link[/xml/] }
        puts 'Found nested sitemap, digging deeper'
        @articles = recursive_sitemap_search(@links)
      end
      write("#{@articles.size} possible articles retrieved!")
      return limited_articles if (@limit && @articles.size >= @limit)
      @articles = filter_articles
    end

    def recursive_sitemap_search(collection) # Recursively searches sitemap for valid links & adds them to @articles
      return collection if collection.none? { |link| !!link[/\.xml/] } # Return collection when reached bottom (no link of type xml)
      collection.each do |link|
        nested_links = parse_xml(link)
        puts "Digging up links for #{link}"; write("Searching in #{link}..")
        return limited_articles if (@limit && @articles.size >= @limit)
        @articles += recursive_sitemap_search(nested_links)
      end
      @articles
    end

    def write_articles_to_table # Write articles to output stream
      write("#{@articles.size} valid articles found! Adding to table.."); write(@articles.size.to_s, 'amount', 1)
      @articles[0..500].each { |article| write(article, 'url') }
      @limit ? write("First #{@limit} articles added!") : write('All articles added!')
    end

    # -------------------- GETTING SHARES & COMMENTS  ------------------------------

    def grab_articles(site = @site, articles = @articles) # Grabs social shares and links for collection of articles
      set_root(site) unless @root
      already_crawled = @website.articles.where(crawled: true)
      # Write already crawled articles to stream
      already_crawled.each {|article| write(JSON.pretty_generate(link: article.link, total: article.total_shares, facebook: article.facebook_shares, twitter: article.twitter_shares, linkedin: article.linkedin_shares, pinterest: article.pinterest_pins, google: article.google_shares, comments: article.comments).to_s, 'shares')}
      articles = articles - already_crawled.map(&:link)
      # Loop over each article that hasn't been crawled before
      articles.each_with_index do |article, i|
        puts "Getting shares for #{article}"; write("Getting data for #{article} (#{i + 1}/#{articles.size})")
        facebook, twitter, pinterest, google, linkedin, error = get_shares(article) # Get shares
        next if error # skip comments if page had an error
        comments = get_comments(article) # Get comments
        crawled_article = @website.articles.where(link: article).first_or_initialize # grab articles if exists, else intialize
        crawled_article.update(crawled: true, link: article, total_shares: facebook + twitter + pinterest + google + linkedin, facebook_shares: facebook, twitter_shares: twitter, linkedin_shares: linkedin, pinterest_pins: pinterest, google_shares: google, comments: comments)
        write(JSON.pretty_generate(link: article, total: facebook + twitter + pinterest + google + linkedin, facebook: facebook, twitter: twitter, linkedin: linkedin, pinterest: pinterest, google: google, comments: comments).to_s, 'shares')
      end
    end

    def get_shares(article) # Returns shares for given article
      begin
        facebook = SocialShares.facebook! article
      rescue
        write("Facebook rate limit reached, shutting down."); exit
      end
      linkedin, pinterest, google, twitter = (SocialShares.linkedin article), (SocialShares.pinterest article), (SocialShares.google article), (twittercount article)
      puts facebook, linkedin, pinterest, google
      begin
        parse_html(article)
      rescue
        write(JSON.pretty_generate(link: 0, total: 0, facebook: 0, twitter: 0, linkedin: 0, pinterest: 0, google: 0, comments: 0).to_s, 'shares')
        return [0,0,0,0,0, true]
      end
      [facebook, twitter, pinterest, google, linkedin, false]
    end

    def twittercount(url) # Returns twittercount for article
      begin
        response = Net::HTTP.get(URI('http://public.newsharecounts.com/count.json?url=' + url))
        JSON.parse(response)['count'] || 0
      rescue
        0
      end
    end

    def get_comments(article) # Returns comment count for given article
      text, comments = @html.to_html.delete("\n"), 0
      if !@disqus_found && comments?(text) # If disqus hasn't been found on the page & normal comments are
        comments = text.match(/[\d]+ comment/i)[0] # Get the first match
        comments.downcase!; comments.slice!('comment') # Remove trailing word
      elsif disqus_comments?(article) # Check if there's disqus comments for article with valid shorthand
        comments = get_disqus_comments(article)
      end
      comments
    end

    def comments?(text) # Checks with regex if page matches # comment
      !!text[/[\d]+ comment/i]
    end

    def get_disqus_comments(article) # Returns disqus comment count based on api query
      begin
        json = JSON.parse(Net::HTTP.get(URI("http://disqus.com/api/3.0/posts/list.json?api_key=GPzjga0wi0guHeQC12FMxgXcVHvcTgOqKVLCmJYZfvk7zymhIGkN20MEeY5p4ylC&limit=100&forum=#{@disqus_shorthand}&thread=link:#{article}")))
        comments = json['response'].size || 0
        while json['hasNext'] # Disqus stupid pagination on JSON response
          cursor = json['next']
          json = JSON.parse(Net::HTTP.get(URI("http://disqus.com/api/3.0/posts/list.json?api_key=GPzjga0wi0guHeQC12FMxgXcVHvcTgOqKVLCmJYZfvk7zymhIGkN20MEeY5p4ylC&limit=100&forum=#{@disqus_shorthand}&thread=link:#{article}&cursor=#{cursor}")))
          comments += json['response'].size || 0
        end
      rescue # Some error (rate limiting or other)
        comments = 0
      end
      comments
    end

    def disqus_comments?(article) # Checks if page contains disqus comments
      return true if @disqus_found
      if @html.at_css('#disqus_thread')
        @disqus_found = true if shorthand_found?
      else
        return false
      end
    end

    def shorthand_found? # Parses disqus shorthand from page (messy, but quite effective)
      scripts = @html.xpath('//script[not(@src)]').map(&:text).join('').tr(';', ',').tr("\n", ',').split(',')
      begin # This is messy parsing of the DOM to reduce scripttags to a disqus shorthand
        if !scripts.delete_if { |data| !data.match(/shortname/i) }.empty?
          scripts = scripts.delete_if { |data| !data.match(/shortname/i) }
          scripts = scripts.delete_if { |data| data.match(/\./i) }.collect { |e| e.tr(':', '=') }[0]
          shorthand = scripts.match(/\=(.*)/)[0].gsub(/[^0-9a-z ]/i, '').strip
          @disqus_shorthand = shorthand
          return true
        elsif !scripts.delete_if { |data| !data.match(/disqus.com/) }.empty?
          scripts = scripts.delete_if { |data| !data.match(/disqus.com/) }
          scripts = scripts.join.split('.').delete_if { |data| !data.match(/\/\/(.*)/i) }.join('')
          shorthand = scripts.match(/\/\/(.*)/i)[0].delete('/')
          @disqus_shorthand = shorthand
          return true
        end
      rescue
        false
      end
    end

    # -------------------- PRIVATE METHODS  ------------------------------
    private

    # GENERAL METHODS
    def write(string, type = 'message', sleep_time = 0) # Writes message to stream
      $sse.write(JSON.pretty_generate(type.parameterize.underscore.to_sym => string))
      sleep sleep_time # Allows user to see rapid-passing messages from stream
    end

    def launch # sets $browser to phantomjs webscraper
     $browser = Watir::Browser.new(:phantomjs)
    end

    def set_root(site) # Sets @root by parsing site to domain.com
      uri = URI.parse(site)
      uri = URI.parse("http://#{site}") if uri.scheme.nil?
      host = uri.host.downcase
      @root = host.start_with?('www.') ? host[4..-1] : host
      @website = Website.find_by(link: @root)
    end

    def error_page?(link) # Check if link returns a 404 page
      response = Typhoeus::Request.head(link, followlocation: true, connecttimeout: 5, timeout: 5).response_code
      ([0,500,404].include?(response)) ? (return true) : (parse_html(link))
      false
    end

    # FILTERING, PARSING & LIMITING
    def filter_articles(collection = @articles) # Removes invalid articles from @articles
      puts 'filtering crawled links..';  write('Filtering invalid articles..', "message", 1)
      collection.delete_if { |data| data.match(/replytocom|category\/|\/about|wp-content\/|component\/|wp-includes\/|wp-json\/|.png|.jpg|.svg|.jpeg|#comment|page\/|profile\/|contact\/|author\/|store\/|products\/|tags\/|forum\/|forums\/|user\/|archive\/|tag\//i) }.uniq
    end

    def parse_html(link) # Sets @html attribute with page content from link
      @html = Nokogiri::HTML(open(link, allow_redirections: :all))
    end

    def parse_xml(link) # Grabs all articles from an XML file & returns the links
      xml = Nokogiri::XML(open(link, allow_redirections: :all))
      @links = xml.search('*//loc').map(&:inner_html)
    end

    def parse_robots_txt # Returns sitemap link from robots.txt file
      @html.text[/sitemap: (https?:\/\/(?:www\.|(?!www))[^\s\.]+\.[^\s]{2,}|www\.[^\s]+\.[^\s]{2,})/i][8..-1].strip
    end

    def limited_articles # Returns limited # of articles based on limit
      @articles = filter_articles[0..@limit - 1]
    end
  end
end

# Hi mom! Look I'm coding :)
