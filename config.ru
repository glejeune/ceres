require 'ceres'

run( Capcode.application( :verbose => true, :root => File.expand_path(File.dirname(__FILE__)), :db_config => "ceres.yml" ) do |k|
	p = Parameter.first( :name => "interval" )
  interval = (p.nil?)?(60):(p.int_value)
  READER = Ceres::Feeds::Reader.new(interval)
  READER.start
  $stdout.puts "** interval : #{interval} seconds"

  if Moderator.all.count <= 0
    m = Moderator.new( :login => "admin", :realname => "Admin")
    m.password = "admin"
    m.save
  end
end )