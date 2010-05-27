require 'ceres'

run Capcode.application( :verbose => true, :root => File.expand_path(File.dirname(__FILE__)), :db_config => "ceres.yml" ) do 
  if Moderator.all.count <= 0
    m = Moderator.new( :login => "admin", :realname => "Admin")
    m.password = "admin"
    m.save
  end
end