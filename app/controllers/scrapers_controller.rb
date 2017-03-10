require 'watir'
require 'nokogiri'
require 'selenium-webdriver'
require 'pry'
require 'social_shares'
require 'share_counts'
require 'open-uri'
require 'open_uri_redirections'
require 'zlib'
require 'anemone'
require 'phantomjs'
require 'json'
require 'typhoeus'

class ScrapersController < ApplicationController
  include ActionController::Live
  include ServerSide

  def root_url(site)
    uri = URI.parse(site)
    uri = URI.parse("http://#{site}") if uri.scheme.nil?
    host = uri.host.downcase
    url = host.start_with?('www.') ? host[4..-1] : host
  end

  def new; end

  def get_home_articles
    link = params['scrape_job']['url']
    response.headers['Content-Type'] = 'text/event-stream'
    $sse = ServerSide::SSE.new(response.stream)
    begin
      @scraper = WebScraper.new
      @scraper.set_limit(10)
      @website = Website.find_by(link: root_url(link))
      if !@website
        @website = Website.create!(link: root_url(link), last_crawled: Time.zone.now)
      else
        flash[:notice] = 'This website has already been crawled...'
      end
      @articles = @scraper.find_articles(link)
      @articles.each do |a|
        begin
          Article.create!(link: a, crawled: false, website_id: @website.id)
        rescue
          next
        end
      end
    rescue IOError
    ensure
      $sse.close
    end
  end

  def home_scan
    links = params[:links].delete("'").split(';')
    response.headers['Content-Type'] = 'text/event-stream'
    $sse = ServerSide::SSE.new(response.stream)
    begin
      @scraper = WebScraper.new
      @scraper.articles = links
      site = 'http://www.' + URI(links[0]).host.match(/[^\.]+\.\w+$/)[0]
      @articles = @scraper.grab_articles(site)
    rescue IOError
    ensure
      $sse.close
    end
  end

  def get_articles
    link = params['scrape_job']['url']
    response.headers['Content-Type'] = 'text/event-stream'
    $sse = ServerSide::SSE.new(response.stream)
    begin
      @scraper = WebScraper.new
      @website = Website.find_by(link: root_url(link))
      @website = Website.create!(link: root_url(link), last_crawled: Time.zone.now) if !@website
      @website.update_attribute("last_crawled", Time.now)
      current_user.websites << @website unless current_user.websites.include? @website
      link = 'http://www.' + link + "/" unless link.include? "://"
      @articles = @scraper.find_articles(link)
      @articles.each do |a|
        begin
          Article.create!(link: a, crawled: false, website_id: @website.id)
        rescue
          next
        end
      end
      @scraper.grab_articles
      @website.status = true; @website.save! if @website.articles.all? { |article| article.crawled? == true }
    rescue IOError
    ensure
      $sse.close
    end
  end

  # -------------------------------- ACTUAL SCRAPING TASKS --------------------------
  class WebScraper
    attr_accessor :all_articles, :articles, :links, :site
    def initialize
      @all_articles = {}
      @articles = []
      @html = ''
      @links = []
      @site = ''
      # @proxies = Proxy.all.order("grade DESC").map(&:ip)
      # @proxy = 0
      @rate_limits = 0
      @limit = false
      @urls = ['sitemap.xml', 'sitemap']
      @disqus_found = false
      @disqus_shorthand = ''
      @root = false
      $browser = ''
      launch
    end

    def write(string, type = 'message', sleep_time = 0)
      $sse.write(JSON.pretty_generate(type.parameterize.underscore.to_sym => string))
      sleep sleep_time
    end

    def set_limit(limit)
      write("Retrieving the first #{limit} articles!", 'message', 1.5)
      @limit = limit
    end

    def set_root(site)
      uri = URI.parse(site)
      uri = URI.parse("http://#{site}") if uri.scheme.nil?
      host = uri.host.downcase
      @root = host.start_with?('www.') ? host[4..-1] : host
      @website = Website.find_by(link: @root)
    end

    def launch
      $browser = nil
      until $browser
        # puts "Launching with #{@proxies[@proxy]}"
        begin
          $browser = Watir::Browser.new(:phantomjs)
          # args: ["--proxy=#{@proxies[@proxy]}", '--ignore-ssl-errors=true', '--ssl-protocol=any'])
        rescue Net::ReadTimeout
          puts 'Connection failed, rotating'
          rotate_proxy
          retry
        end
      end
      # puts "Succesfull launch with #{@proxies[@proxy]}"
    end

    def rotate_proxy
      # Proxy.find_by(ip: @proxies[@proxy]).update_attribute("grade", 1)
      # @proxy += 1
      $browser.quit
      $browser = nil
      until $browser
        # puts "Rotating ip to #{@proxies[@proxy]}"
        begin
          $browser = Watir::Browser.new(:phantomjs)
          # args: ["--proxy=#{@proxies[@proxy]}", '--ignore-ssl-errors=true', '--ssl-protocol=any'])
        rescue
          puts 'connection failed, rotating'
          rotate_proxy
          retry
        end
      end
       # puts "Succesfull rotation with #{@proxies[@proxy]}"
     end
    # -------------------- FILTERING & PARSING METHODS ------------------------------

    def parse_html
      sleep 3
      @html = Nokogiri::HTML($browser.html)
    end

    def bad_ip?
      @html.text.match(/域名纠错系统/i) || @html.text == ''
    end

    def parse_xml(link)
      xml = Nokogiri::XML(open(link, allow_redirections: :all))
      @links = xml.search('*//loc').map(&:inner_html)
    end

    def parse_robots_txt
      @html = @html.match(/sitemap: (https?:\/\/(?:www\.|(?!www))[^\s\.]+\.[^\s]{2,}|www\.[^\s]+\.[^\s]{2,})/i)[0]
      @html[8..-1].strip
    end

    def filter_articles
      puts 'filtering crawled links..'
      @articles.delete_if { |data| data.match(/replytocom|category\/|\/about|wp-content\/|component\/|wp-includes\/|wp-json\/|.png|.jpg|.svg|.jpeg|#comment|page\/|profile\/|contact\/|author\/|store\/|products\/|tags\/|forum\/|forums\/|user\/|archive\/|tag\//i) }
      @articles.uniq
    end

    def error?(link)
      response = Typhoeus::Request.head(link).response_code
      return true if response == 404
      # If it's not a 200 ok code and the page doesn't contain the words "sitemap" or "xml", it's an error (or crawling is better)
      !@html.text.match(/sitemap/i) && !@html.text.match(/xml/i) && !([200, 301,302].include? response)
      #  @html.text.match(/404|not found|unable to load Disqus/i)
    end

    def comments?(text)
      text =~ /[\d]+ comment/i
    end

    def disqus_comments?(_article)
      return true if @disqus_found && @disqus_shorthand.size > 2
      if @html.at_css('#disqus_thread')
        @disqus_found = true
        scripts = @html.xpath('//script[not(@src)]').map(&:text).join('').tr(';', ',').tr("\n", ',').split(',')
        # other sites
        begin
          if !scripts.delete_if { |data| !data.match(/shortname/i) }.empty?
            scripts = scripts.delete_if { |data| !data.match(/shortname/i) }
            scripts = scripts.delete_if { |data| data.match(/\./i) }.collect { |e| e.tr(':', '=') }[0]
            shorthand = scripts.match(/\=(.*)/)[0].gsub(/[^0-9a-z ]/i, '').strip
            @disqus_shorthand = shorthand
            return true
          elsif !scripts.delete_if { |data| !data.match(/disqus.com/) }.empty?
            # my site
            scripts = scripts.delete_if { |data| !data.match(/disqus.com/) }
            scripts = scripts.join.split('.').delete_if { |data| !data.match(/\/\/(.*)/i) }.join('')
            shorthand = scripts.match(/\/\/(.*)/i)[0].delete('/')
            @disqus_shorthand = shorthand
            return true
          end
        rescue
          return false
        end
      else
        return false
      end
    end

    def robots_txt_has_sitemap?
      @html = @html.text
      @html.match(/sitemap: (https?:\/\/(?:www\.|(?!www))[^\s\.]+\.[^\s]{2,}|www\.[^\s]+\.[^\s]{2,})/i)
    end

    # -------------------- FIND OR CREATE SITEMAP ------------------------------

    def find_articles(site)
      @site = site
      find_xml_sitemap
      write('Filtering invalid articles..')
      sleep 1
      puts 'filtering done!'
      sleep 1
      write("#{@articles.size} valid articles found! Adding to table..")
      write(@articles.size.to_s, 'amount')
      sleep 1
      @articles.each { |a| write(a, 'url') }
      @limit ? write("First #{@limit} articles added!") : write('All articles added!')
      @articles
    end

    def find_xml_sitemap
      sitemap_found = false; size = 0
      until sitemap_found == true || size > 1
        write("Searching /#{@urls[size]}")
        puts "checking out /#{@urls[size]}"
        begin
          $browser.goto "#{@site}#{@urls[size]}"
        rescue
          puts 'Timeouterror reached, switching ip adress'
          rotate_proxy
          retry
        end
        parse_html
        # if bad_ip?
        #   puts 'Weird chinese stuff found or empty page, rotating'
        #   rotate_proxy
        #   redo
        # end
        puts 'Decent proxy'
        # Proxy.find_by(ip: @proxies[@proxy]).update_attribute("grade", 5)
        if !error?("#{@site}#{@urls[size]}")
          write('Sitemap found!')
          puts 'Sitemap found!'
          @links = parse_xml("#{@site}#{@urls[size]}")
          sitemap_found = true
          has_nested_sitemap?
        else
          write('No sitemap found :(', 'message', 1)
          puts 'Found error page - No sitemap :('
          size += 1
        end
      end
      unless sitemap_found
        puts 'No sitemap found on /sitemap or /sitemap.xml, trying sitemap.xml.gz'
        write('Searching sitemap.xml.gz', 'message', 1)
        begin
          sitemap = open("#{@site}sitemap.xml.gz", allow_redirections: :all)
          gz = Zlib::GzipReader.new(sitemap)
          xml = gz.read
          @links = Nokogiri::XML.parse(xml).search('*//loc').map(&:inner_html)
          puts 'Sitemap.gz found!'
          write('Sitemap found!', 'message', 1)
          has_nested_sitemap?
        rescue
          write('No sitemap :(', 'message', 1)
          write('Searching /robots.txt', 'message', 1)
          puts 'No sitemap.xml.gz found, trying robots.txt'
          $browser.goto "#{@site}robots.txt"
          parse_html
          if robots_txt_has_sitemap?
            link = parse_robots_txt
            @links = parse_xml(link)
            has_nested_sitemap?
          else
            puts 'No sitemap found nor indications in robots.txt. Going to create own sitemap.'
            puts 'Releasing THE KRACKEN'
            write('No valid sitemap found on site.', 'message', 1)
            write('Creating new sitemap (this might take a few minutes)', 'message', 1)
            write('RELEASE THE KRACKEN!')
            spider_search
          end
        end
      end
    end

    def has_nested_sitemap?
      @articles = []
      if @links.any? { |e| e.match(/xml/) }
        puts 'Found nested sitemap, digging deeper'
        @links.each_with_index do |link, i|
          puts "Digging up links for #{link}"
          xml = Nokogiri::XML(open(link, allow_redirections: :all))
          write("#{i + 1}/#{@links.size} parts retrieved") unless @limit
          @articles += xml.search('*//loc').map(&:inner_html)
          if @limit && @articles.size >= @limit
            @articles = filter_articles
            return @articles = @articles[0..@limit - 1]
          end
        end
      else
        @articles = @links
        if @limit && @articles.size >= @limit
          @articles = filter_articles
          return @articles = @articles[0..@limit - 1]
        end
      end
      write("#{@articles.size} possible articles retrieved!")
      @articles = filter_articles
    end

    def spider_search
      @links = []
      Anemone.crawl(@site, depth_limit: 3, obey_robots_txt: true, skip_query_strings: true) do |anemone|
        anemone.skip_links_like /replytocom|category\/|\/about|wp-content\/|component\/|wp-includes\/|wp-json\/|.png|.jpg|.svg|.jpeg|#comment|page\/|profile\/|contact\/|author\/|store\/|products\/|tags\/|forum\/|forums\/|user\/|archive\/|tag\//i
        anemone.on_every_page do |page|
          puts "checking #{page.url}"
          @links << page.url.to_s
          write("Found #{@links.size} total articles!")
          if @limit && @links.size >= @limit
            @articles = @links
            @articles = filter_articles
            return @articles = @articles[0..@limit - 1]
          end
        end
      end
      @articles = @links
      @articles = filter_articles
    end

    # -------------------- GET SHARECOUNT & COMMENTCOUNT ------------------------------

    def grab_articles(site = @site)
      set_root(site) unless @root
      @articles.each_with_index do |article, i|
        @article = @website.articles.find_by(link: article)
        if @article.crawled == true
          write(JSON.pretty_generate(link: @article.link, total: @article.total_shares, facebook: @article.facebook_shares, twitter: @article.twitter_shares, linkedin: @article.linkedin_shares, pinterest: @article.pinterest_pins, google: @article.google_shares, comments: @article.comments).to_s, 'shares')
          next
        end
        link = article.gsub(site, '')[0..-2]
        write("Getting data for #{link.blank? ? 'root' : article} (#{i + 1}/#{@articles.size})")
        puts "Getting shares for #{article}"
        begin
          facebook = SocialShares.facebook! article
        rescue
          # @rate_limits += 1
          # if @rate_limits > 4
          #   puts 'Long rate limit reached, switching ip adress'
          #   @rate_limits = 0
          #   rotate_proxy
          #   retry
          # else
          #   puts 'Rate limit reached, going to sleep for 30 seconds'
          #   sleep 30
          #   redo
          # end
          write("Facebook rate limit reached, shutting down.")
          exit
        end
        linkedin = SocialShares.linkedin article
        pinterest = SocialShares.pinterest article
        google = SocialShares.google article
        twitter = twittercount article

        puts facebook, linkedin, pinterest, google
        begin
          @html = Nokogiri::HTML.parse(open(article, allow_redirections: :all))
        rescue
          write(JSON.pretty_generate(link: 0, total: 0, facebook: 0, twitter: 0, linkedin: 0, pinterest: 0, google: 0, comments: 0).to_s, 'shares')
          next
        end
        text = @html.text.delete("\n")
        # binding.pry
        if !@disqus_found && comments?(text)
          comments = text.match(/[\d]+ comment/i)[0]
          comments.downcase!
          comments.slice!('comment')
        elsif disqus_comments?(article)
          begin
            # binding.pry
            json = JSON.parse(Net::HTTP.get(URI("http://disqus.com/api/3.0/posts/list.json?api_key=GPzjga0wi0guHeQC12FMxgXcVHvcTgOqKVLCmJYZfvk7zymhIGkN20MEeY5p4ylC&limit=100&forum=#{@disqus_shorthand}&thread=link:#{article}")))
            comments = json['response'].size || 0
            while json['hasNext']
              # binding.pry
              cursor = json['next']
              json = JSON.parse(Net::HTTP.get(URI("http://disqus.com/api/3.0/posts/list.json?api_key=GPzjga0wi0guHeQC12FMxgXcVHvcTgOqKVLCmJYZfvk7zymhIGkN20MEeY5p4ylC&limit=100&forum=#{@disqus_shorthand}&thread=link:#{article}&cursor=#{cursor}")))
              comments += json['response'].size || 0
            end
          rescue
            comments = 0
          end
        else
          comments = 0
        end
        puts comments
        if !@article
          @website.articles.create!(crawled: true, link: article, total_shares: facebook + twitter + pinterest + google + linkedin, facebook_shares: facebook, twitter_shares: twitter, linkedin_shares: linkedin, pinterest_pins: pinterest, google_shares: google, comments: comments)
        elsif @article
          @article.update_attributes(crawled: true, link: article, total_shares: facebook + twitter + pinterest + google + linkedin, facebook_shares: facebook, twitter_shares: twitter, linkedin_shares: linkedin, pinterest_pins: pinterest, google_shares: google, comments: comments)
        end
        # @all_articles[:"article#{@all_articles.size + 1}"] = { link: article, total: facebook + twitter + pinterest + google + linkedin,facebook: facebook, twitter: twitter, linkedin: linkedin, pinterest: pinterest, google: google, comments: comments }
        write(JSON.pretty_generate(link: article, total: facebook + twitter + pinterest + google + linkedin, facebook: facebook, twitter: twitter, linkedin: linkedin, pinterest: pinterest, google: google, comments: comments).to_s, 'shares')
        # puts "#{@articles.size - @all_articles.size} of #{@articles.size} links left"
      end
      @all_articles
    end

    def twittercount(url)
      response = Net::HTTP.get(URI('http://public.newsharecounts.com/count.json?url=' + url))
      JSON.parse(response)['size'] || 0
    rescue
      0
    end
  end
end
