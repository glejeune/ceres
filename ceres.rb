require 'rubygems'
require 'capcode'
require 'capcode/base/dm'

# Require Ceres libs
require 'lib/feed'
require 'lib/core_ext'

# -- Modele -------------------------------------------------------------------

class Parameter < Capcode::Base
  include Capcode::Resource
  
  property :id, Serial
  property :name, String
  property :int_value, Integer
  property :str_value, String
end

class Feed < Capcode::Base
  include Capcode::Resource
  
  property :id, Serial

  property :host, String
  property :url, String
  property :feed, String
  property :title, String
  property :description, Text
  property :active, String
  
  property :last_update, Date
  
  has n, :posts
end

class Post < Capcode::Base
  include Capcode::Resource
  property :id, Serial
  
  property :title, String
  property :content, Text
  property :date, Date
  property :url, String
  property :post_id, String
  property :author, String
  
  belongs_to :feed
  
  def self.paginate( opts = {} )
    opts = {:page => 1, :per_page => 10, :order => :date.desc}.merge(opts)    
    
    # Get order
    order = opts.delete(:order) || []
    # Get all posts
    all = Post.all( :order => order )
    
    # Set number or pages
    number_of_pages = all.count / opts[:per_page]
    number_of_pages = ((all.count - (number_of_pages * opts[:per_page])) > 0)?(number_of_pages+1):number_of_pages
    
    # Set page number
    page = opts[:page]
    page = 1 if page < 1
    page = number_of_pages if page > number_of_pages
    
    # Set previous and next page
    previous_page = (page > 1)?(page - 1):nil
    next_page = (page < number_of_pages)?(page + 1):nil
    
    start = (page-1)*opts[:per_page]
    
    [all[start, opts[:per_page]], page, previous_page, next_page, number_of_pages]
  end
end

class Moderator < Capcode::Base
  include Capcode::Resource
  property :id, Serial
  
  property :login, String
  property :realname, String
  property :password_hash, String
  property :password_salt, String
  
  def password=(pass)
    salt = [Array.new(6){rand(256).chr}.join].pack("m").chomp
    self.password_salt, self.password_hash = salt, Digest::SHA256.hexdigest( pass + salt )
  end

  def self.authenticate( login, password )
    user = Moderator.first( :login => login )
    if user.blank? || Digest::SHA256.hexdigest( password + user.password_salt ) != user.password_hash
      return nil
    end
    return user
  end
end

# -- Controller ---------------------------------------------------------------

module Capcode
  set :erb, "views"
  set :static, "public"
  
  before_filter :check_login
  before_filter :user_logged, :only => [
    :Administration, 
    :ActivateFeed, 
    :DeactivateFeed, 
    :DeleteFeed, 
    :AddModerator, 
    :DeleteModerator
  ]
  
  def check_login
    if session[:user]
      @user = Moderator.get(session[:user])
    else
      @user = nil
    end
    nil
  end
  
  def user_logged
    if session[:user]
      nil
    else
      redirect Capcode::Login
    end
  end
  
  class Index < Route '/', '/page/(.*)'
    def get( page = 1 )
      @posts, @page, @previous_page, @next_page, @number_of_pages = Post.paginate( :page => page.to_i )
      render :erb => :index
    end
  end
  
  class Style < Route '/style'
    def get
      render :static => "style.css", :exact_path => false
    end
  end
  
  class ProposeFeed < Route '/feed/propose'
    def get
      @alternates = nil
      render :erb => :propose
    end
    
    def post
      if params['url'].nil? or params['url'].size == 0
        @alternates = nil
      else
        @alternates = Ceres::Feeds.fromURL( params['url'] )
      end
      render :erb => :propose
    end
  end
  
  class AcceptFeed < Route '/feed/accept'
    def get
      redirect ProposeFeed
    end
    
    def post
      feed = Feed.new(params)
      if feed.save
        redirect Index 
      else
        @error = true
        render :erb => :proposal
      end
    end
  end
  
  class Login < Route '/login'
    def get
      if session[:user]
        redirect Index
      else
        render :erb => :login
      end
    end
    
    def post
      user = Moderator.authenticate( params['login'], params['password'] )
      if user
        session[:user] = user.id
      end
      
      redirect Index
    end
  end
  
  class Logout < Route '/logout'
    def get
      session.delete(:user)
      redirect Index
    end
  end
  
  class Contributors < Route '/contributors'
    def get
      @contributors = Feed.all( :active.not => "" )
      render :erb => :contributors
    end
  end
  
  class Atom < Route '/atom'
    def get
      @posts, @previous_page, @next_page, @number_of_pages = Post.paginate( )
      render :erb => "atom.rxml", :content_type => "application/atom+xml", :layout => :none
    end
  end
  
  class Administration < Route '/admin'
    def get
      @feeds = Feed.all
      @users = Moderator.all
      @colors = ["#EEEEEE", "#AAAAAA"]
      @reader = READER
      render :erb => :administration
    end
  end
  
  class ActivateFeed < Route '/feed/activate/(.*)'
    def get( id )
      feed = Feed.get(id.to_i)
      feed.active = "yes"
      feed.save
      redirect Administration
    end
  end
  
  class DeactivateFeed < Route '/feed/deactivate/(.*)'
    def get( id )
      feed = Feed.get(id.to_i)
      feed.active = nil
      feed.save
      redirect Administration
    end
  end
  
  class DeleteFeed < Route '/delete/(.*)'
    def get( id )
      feed = Feed.get(id.to_i)
      feed.posts.each do |post|
        post.destroy!
      end
      feed.destroy!
      redirect Administration
    end
  end

  class AddModerator < Route '/add/moderator'
    def get
      redirect Administration
    end
    def post
      m = Moderator.new( :login => params['login'], :realname => params['realname'])
      m.password = params['password']
      m.save
      redirect Administration
    end
  end
  
  class DeleteModerator < Route '/delete/moderator/(.*)'
    def get( id )
      Moderator.get( id.to_i ).destroy!
      redirect Administration
    end
  end

  class AjaxFeedChecking < Route '/ajax/feed/checking'
    def get
      render :json => READER.checking
    end
  end

  class AjaxFeedCheckNow < Route '/ajax/feed/check'
    def get
      READER.populate
      render 200 => "Ok"
    end
  end
  
  class AjaxFeedInterval < Route '/ajax/feed/interval/(.*)'
    def get( interval )
      interval = interval.to_i      
      puts "** INFO: Change interval to #{interval}"
      
      param = Parameter.first( :name => "interval" )
      param = Parameter.new( :name => "interval" ) if param.nil?
      param.int_value = interval
      if param.save
        READER.interval = interval
        
        begin
          READER.stop
        rescue
          puts "** ERROR: stop"
        end
        
        begin
          READER.start
        rescue
          puts "** ERROR: start"
        end
      else
        interval = READER.interval
      end
      
      render :json => interval
    end
  end
end

if $0 == __FILE__
  Capcode.run( :db_config => "ceres.yml" ) do 
    
    p = Parameter.first( :name => "interval" )
    interval = (p.nil?)?(60):(p.int_value)
    READER = Ceres::Feeds::Reader.new(interval)
    READER.start
    puts "** interval : #{interval} seconds"
    
    if Moderator.all.count <= 0
      puts "** Create user admin with password admin..."
      m = Moderator.new( :login => "admin", :realname => "Admin")
      m.password = "admin"
      m.save
    end
  end
end