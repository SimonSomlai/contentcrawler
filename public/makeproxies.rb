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

def parse_html
  sleep 3
  @html = Nokogiri::HTML($browser.html)
end


  $browser = Watir::Browser.new(:phantomjs)
  # args: ['--ignore-ssl-errors=true', '--ssl-protocol=any'])
  $browser.goto 'http://proxylist.hidemyass.com/'
  sleep 3
  $browser.label(xpath: "//*[@id='proxy-search-form']/div[1]/div[6]/fieldset[2]/div[1]/label").click
  $browser.label(xpath: '//*[@id="proxy-search-form"]/div[1]/div[6]/fieldset[2]/div[2]/label').click
  $browser.label(xpath: '//*[@id="proxy-search-form"]/div[1]/div[6]/fieldset[1]/div[1]/label').click
  $browser.label(xpath: '//*[@id="proxy-search-form"]/div[1]/div[6]/fieldset[1]/div[2]/label').click
  $browser.label(xpath: '//*[@id="proxy-search-form"]/div[1]/div[5]/fieldset[1]/div[1]/label').click
  $browser.label(xpath: '//*[@id="proxy-search-form"]/div[1]/div[5]/fieldset[1]/div[2]/label').click
  $browser.label(xpath: '//*[@id="proxy-search-form"]/div[1]/div[5]/fieldset[1]/div[3]/label').click
  $browser.select_list(name: 'pp').select_value('3')
  # Update listing
  $browser.button(id: 'proxy-list-upd-btn').click
  hidden_classes = {}
  parse_html
  list = @html.at_css('#listable')
  # Gets hidden classes
  list.search('td[2]>span>style').each_with_index do |data, index|
    array = data.text.tr("\n", ',').split(',')
    array.delete_if { |data| !data.match(/display:none/i) }
    array = array.collect! { |e| e[1..4] }
    # list of hidden classes
    hidden_classes[:"ip#{index + 1}"] = { classes: array }
  end
  # Gets ip adress from html content
  ip_list = []
  list.search('td[2]').each_with_index do |data, index|
    ip = data.inner_html.tr("\n", ',').gsub('span', ',').gsub('div', ',').split(',').delete_if { |data| data.match(/display:none/i) }
    reg = Regexp.new(hidden_classes[:"ip#{index + 1}"][:classes].join('|'))
    ip = ip.delete_if { |data| data.match(reg) }
    ip = ip.delete_if { |data| !data.match(/>\.*[\d]+\.*</) }
    ip = ip.map { |x| x[/>\.*[\d]+\.*</] }
    ip = ip.map { |x| x[/\d+/] }.join('.')
    ip_list << ip
  end
  ports = []
  list.search('td[3]').each_with_index do |data, _index|
    ports << data.text.strip
  end
  @proxies = ip_list.each_with_index.map { |e, i| e + ":#{ports[i]}" }

  @proxies.each do |proxy|
    if Proxy.find_by(ip: proxy)
      next
    else
      Proxy.create!(ip: proxy, grade: 2)
    end
  end
