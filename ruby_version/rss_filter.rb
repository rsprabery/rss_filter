require "net/http"
require "json"
require "set"
require "date"

module RssFilter
  VERSION = "0.1.0"

  def self.save_to_file(articles, filename)
    json_articles = set_to_json(articles)
    if File.exists? filename
      File.delete(filename)
    end

    articles_file = File.open(filename, "w")
    articles_file << json_articles
    articles_file.close
  end

  def self.load_articles_set_from(filename)
    articles_set = Set.new
    if File.exists? filename
      articles_set = articles_set_from_hash(JSON.parse(File.read(filename)))
      puts "Loaded articles from #{filename}."
      puts "Number of articles: #{articles_set.size}"
    end
    return articles_set
  end

  def self.set_to_json(enumerable_obj)
    output = []
    enumerable_obj.each do |item|
      output << item
    end
    output.to_json
  end

  def self.articles_set_from_hash(hash) 
    output = Set.new
    hash.each do |article_hash|
      output.add(Article.new(article_hash))
    end
    output
  end

  class Article
    def initialize(*args) 
      case args.size
      when 1
        init_from_hash(*args)
      when 3
        init_from_args(*args)
      end
    end

    def init_from_args(url, title, published_on) 
      @url = url
      @title = title
      @published_on = published_on
    end

    def init_from_hash(hash)
      @url = hash["url"]
      @title = hash["title"]
      pub_on =  DateTime.strptime(hash["published_on"], "%Y-%m-%dT%k:%M:%S%:z")
      pub_on = pub_on.to_time.utc
      @published_on =  pub_on
    end

    def title
      @title
    end

    attr_reader :published_on, :url

    def to_json(options = nil)
      {"url" => @url, "title" => @title, "published_on" => @published_on.strftime("%Y-%m-%dT%k:%M:%S%:z")}.to_json
    end

    def eql?(other)
      @title == other.title
    end

    def hash
      @title.hash
    end

  end

  visited_filename = "./rss_filter.json"
  waiting_filename = "./rss_filter_waiting.json"

  visited_articles = load_articles_set_from(visited_filename)
  waiting_articles = load_articles_set_from(waiting_filename)

  loop do
    new_articles = Array.new

    articles_url = URI("https://feed2json.org/convert?url=http%3A%2F%2Ffeeds.arstechnica.com%2Farstechnica%2Findex")

    response = Net::HTTP.get articles_url
    feed = JSON.parse(response)
    feed["items"].each do |item|
      title = item["title"]
      url = item["url"]
      date_published = DateTime.strptime(item["date_published"], 
                                         "%Y-%m-%dT%k:%M:%S")
      time_published = date_published.to_time.utc

      article = Article.new(url, title, time_published)
      new_articles << article
    end

    utc_now = DateTime.now.to_time.utc
    instapaper_failures = 0

    new_set = Set.new(new_articles)
    super_set = Set.new(waiting_articles)
    super_set.merge(new_set)

    super_set.each do |article|
      unless article.nil?
        two_weeks_in_seconds = 2 * 14 * 24 * 60 * 60
        if utc_now - article.published_on > two_weeks_in_seconds 
          unless visited_articles.include? article
            # Add to Instapaper
            username = ENV["INSTA_USERNAME"]
            password = ENV["INSTA_PWD"]
            params = {"username" => username,
                      "password" => password,
                      "url"      => article.url,
                      "title"    => article.title,
            }

            uri = URI("https://www.instapaper.com/api/add")

            response = Net::HTTP.start(uri.hostname, uri.port, 
                                       :use_ssl => true) {|http|
              req = Net::HTTP::Get.new(uri)
              req.basic_auth(username, password)
              req.set_form_data(params)

              http.request(req)
            }

            if response.code.to_i != 201
              puts "Instapaper status code: #{response.code}"
              puts response.body
              puts "\n\n"
              instapaper_failures += 1
              if instapaper_failures >= 3
                exit(1)
              end
            else
              # Add to previously seen articles
              visited_articles.add(article)
              if waiting_articles.include?(article)
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
