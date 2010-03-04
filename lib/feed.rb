require 'rubygems'
require 'feed-normalizer'
require 'open-uri'
require 'eventmachine'
require 'nokogiri'
require 'uri'

module Ceres
  class Feeds
    FEED_LINK_TYPE = ['application/rss+xml', 'text/xml', 'application/atom+xml']
    
    # This method take a website URL and return all alternate for feeds
    def self.fromURL( url )
      feed = { 
        :url => url,
        :links => []
      }
      
      uri = URI.parse( url )
      feed[:host] = uri.scheme + "://" + 
        ((uri.userinfo)?(uri.userinfo+"@"):"") + uri.host + 
        ((uri.port and uri.port != 80)?(":"+uri.port.to_s):"")
      
      doc = Nokogiri::HTML(open( url ))
      feed[:title] = doc.xpath('/html/head/title').children.to_s
      doc.xpath('//link[@rel="alternate"]').each do |link|
        if FEED_LINK_TYPE.include?( link.attribute('type').value )
          feed[:links] << {
            :type => link.attribute('type').value,
            :href => (
              (URI.parse(link.attribute('href').value).host)?
                (link.attribute('href').value):
                (URI.join(feed[:host],link.attribute('href').value).to_s)
            ),
            :title => link.attribute('title').value
          }
        end
      end

      return feed
    end
    
    class Reader
      attr_accessor :interval
      attr_reader :checking
      attr_reader :status
      
      def initialize( interval = 60*60*6 )
        # Default : we extract new feeds every 6 hours
        @interval = interval
        @checking = false
        @status = false
      end
      
      def populate
        return if @checking
        puts "** START..."
        @checking = true

        begin
          feeds = Feed.all( :active.not => "" )
          feeds.each do |feed|
            new_posts = false
            content = FeedNormalizer::FeedNormalizer.parse open(feed.feed)
            
            # Check all items
            content.entries.each do |item|            
              # Verify if the items already existe or not
              post = Post.all( :post_id => item.id )
              
              if post.nil? or post.size == 0
                new_posts = true

                Post.new( 
                  :title => item.title,
                  :content => ((item.content.nil? or item.content.size == 0)?(item.description):(item.content)),
                  :date => item.date_published || Time.now(),
                  :url => item.url,
                  :post_id => item.id,
                  :feed => feed
                ).save
              end
            end
            
            feed.last_update = content.last_updated || Time.now()
            feed.save
          end
        rescue => e
          puts "** ERROR : #{e.message}"
        end
      ensure
        @checking = false
        puts "** END..."
      end
      
      def start
        Thread.new do
          EventMachine.run do
            EM.add_periodic_timer(@interval) do
              at_exit { EM.stop_event_loop }
              @status = true
              
              populate
            end
          end
        end        
      end
      
      def stop
        EM.stop_event_loop
        @status = false
      end
      
    end
  end
end





