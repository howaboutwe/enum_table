module EnumTable
  autoload :VERSION, 'enum_table/version'
  autoload :Record, 'enum_table/record'
  autoload :Reflection, 'enum_table/reflection'
  autoload :SchemaDumper, 'enum_table/schema_dumper'
  autoload :SchemaStatements, 'enum_table/schema_statements'
end

require 'enum_table/railtie' if defined?(Rails)
ActiveRecord::Base.send :include, EnumTable::Record
ActiveRecord::ConnectionAdapters::AbstractAdapter.send :include, EnumTable::SchemaStatements
