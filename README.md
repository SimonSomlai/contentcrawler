# Coach App

>ContenCrawler is an application that allows its users to retrieve the most popular articles from any website (measured by total social shares and comments). Might be down on occasion since it's running on free dynos.   

<b>User demo login:</b> demon@email.com & password  (Yeah, that's 'demon' instead of 'demo'. Typo :/)<br/>

# Tech Stack

- <b>Front:</b> HTML, CSS, JS (+EventSource)
- <b>Back:</b> Ruby & RoR
- <b>Gems:</b> Typhoeus, watir, nokogiri, social_shares, phantomjs, activerecord-import, devise, open_uri, magic
- <b>Db:</b> Postgresql

# Pics Or It Didn't Happen

## Home Page
<img src="home.png"/>

## Website Index
<img src="index.png"/>

## Website Show
<img src="show.png"/>

## Show Me Da Magic
Most of the cool stuff is inside<b> app/helpers/scraper_helper.rb</b>

<img src="find_articles.png"/>
<img src="shares.png"/>
<img src="private.png"/>

# Explainer Video (click it)

[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/Z1w5bXbUS5w/0.jpg)](https://www.youtube.com/watch?list=PLGEw-EytTlW5GWyw4Ou6zrPrltMn7CpCJ&v=Z1w5bXbUS5w)

## TO DO

- Refactor messy javascript
- Implement ip rotation
- Find solution for facebook <span style="text-decoration:line-through;">rape</span> rate limiting
- Maybe try to actually market it a bit?  

Made with <3 by [TrueTech]("http://www.truetech.be/en")
