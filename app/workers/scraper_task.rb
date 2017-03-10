class ScraperTask
  @queue = :scraper_queue
  def self.perform(link)
    include ScraperHelper
    @scraper = WebScraper.new
    @scraper.launch
    @articles = @scraper.find_articles(link)
    Website.create!(link: link, articles: @articles, last_crawled: Time.zone.now)
  end
end
