ROOT = File.expand_path('..', File.dirname(__FILE__))
$:.unshift "#{ROOT}/lib"

require 'minitest/autorun'
require 'active_record'
require 'enum_table'

ADAPTER = ENV['ENUM_TABLE_ADAPTER'] || 'sqlite3'
CONFIG = YAML.load_file("#{ROOT}/test/database.yml")[ADAPTER].merge(adapter: ADAPTER)
case ADAPTER
when /sqlite/
  ActiveRecord::Base.establish_connection(CONFIG)
when /postgres/
  ActiveRecord::Base.establish_connection(CONFIG.merge('database' => 'postgres'))
else
  ActiveRecord::Base.establish_connection(CONFIG.merge('database' => nil))
end

MiniTest::Spec.class_eval do
  def recreate_database
    drop_database
    create_database
  end

  def connection
    ActiveRecord::Base.connection
  end

  def create_database
    unless ADAPTER =~ /sqlite/
      connection.create_database CONFIG['database']
    end
    ActiveRecord::Base.establish_connection(CONFIG)
  end

  def drop_database
    case ADAPTER
    when /sqlite/
      # Nothing to do - in-memory database.
    when /postgres/
      # Postgres barfs if you drop the selected database.
      ActiveRecord::Base.establish_connection(CONFIG.merge('database' => 'postgres'))
      connection.drop_database CONFIG['database']
    else
      connection.drop_database CONFIG['database']
    end
  end

  def self.use_database
    mod = Module.new do
      extend Minitest::Spec::DSL

      before { recreate_database }
      after { drop_database }
    end
    include mod
  end
end
