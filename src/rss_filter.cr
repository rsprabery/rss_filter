require "http/client"
require "json"

module RssFilter
  VERSION = "0.1.0"

  def self.save_to_file(articles : Set(Article), filename : String)
    json_articles = articles.to_json
    if File.exists? filename
      File.delete(filename)
    end

    articles_file = File.open(filename, "w")
    articles_file << json_articles
    articles_file.close
  end

  def self.load_articles_set_from(filename : String)
    articles_set = Set(Article).new
    if File.exists? filename
      articles_set = Set(Article).from_json(File.read(filename))
      puts "Loaded articles from #{filename}."
      puts "Number of articles: #{articles_set.size}"
    end
    return articles_set
  end

  class Article
    JSON.mapping(
      url: String,
      title: String,
      published_on: Time
    )

    def initialize(url : String, title : String, published_on : Time)
      @url = url
      @title = title
      @published_on = published_on
    end

    def title
      @title
    end

    getter :title, :url

    def_equals_and_hash @title, @published_on
  end

  visited_filename = "./rss_filter.json"
  waiting_filename = "./rss_filter_waiting.json"

  visited_articles = load_articles_set_from(visited_filename)
  waiting_articles = load_articles_set_from(waiting_filename)

  loop do
    new_articles = Array(Article).new

    articles_url = "https://feed2json.org/convert?url=http%3A%2F%2Ffeeds.arstechnica.com%2Farstechnica%2Findex"

    response = HTTP::Client.get articles_url
    feed = JSON.parse(response.body)
    feed["items"].as_a.each do |item|
      title = item["title"].as_s
      url = item["url"].as_s
      location = Time::Location.new("UTC", [Time::Location::Zone::UTC])
      date_published = Time.parse(item["date_published"].as_s,
        "%Y-%m-%dT%k:%M:%S", location)

      article = Article.new(url, title, date_published)
      new_articles << article
    end

    utc_now = Time.now.to_utc
    instapaper_failures = 0

    new_set = Set(Article).new(new_articles)
    super_set = Set(Article).new(waiting_articles)
    super_set.concat(new_set)

    super_set.each do |article|
      unless article.nil?
        if utc_now - article.published_on > 2.weeks
          unless visited_articles.includes? article
            # Add to Instapaper
            username = ENV["INSTA_USERNAME"]
            password = ENV["INSTA_PWD"]
            params = HTTP::Params.encode({"username" => username,
                                          "password" => password,
                                          "url"      => article.url,
                                          "title"    => article.title,
            })

            client = HTTP::Client.new(host: "www.instapaper.com", tls: true)
            client.basic_auth(username, password)
            response = client.get("/api/add", body: params)
            if response.status_code != 201
              puts "Instapaper status code: #{response.status_code}"
              puts response.body
              puts "\n\n"
              instapaper_failures += 1
              if instapaper_failures >= 3
                exit(1)
              end
            else
              # Add to previously seen articles
              visited_articles.add(article)
              if waiting_articles.includes?(article)
                waiting_articles.delete(article)
              end
            end
          end
        else # article is < 2 weeks old
          waiting_articles.add(article)
        end
      end
    end

    save_to_file(visited_articles, visited_filename)
    save_to_file(waiting_articles, waiting_filename)

    puts "Num waiting: #{waiting_articles.size}"
    puts "Num processed: #{visited_articles.size}"

    seconds_in_day = 1 * 24 * 60 * 60
    sleep(seconds_in_day)
  end
end
