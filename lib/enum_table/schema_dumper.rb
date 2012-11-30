module EnumTable
  module SchemaDumper
    extend ActiveSupport::Concern

    included do
      alias_method_chain :tables, :enum_table
      alias_method_chain :ignore_tables, :enum_table
    end

    def tables_with_enum_table(stream)
      tables_without_enum_table(stream)
      table_names = @connection.enum_tables
      table_names.each do |table_name|
        stream.puts "  create_enum_table #{table_name.inspect}, force: true do |t|"
        enum_table_column(stream, table_name, 'value', SchemaStatements::DEFAULT_VALUE_ATTRIBUTES)
        @connection.execute("SELECT id, value FROM #{table_name} ORDER BY id").each do |row|
          stream.puts "    t.add #{row[1].to_s.inspect}, #{row[0]}"
        end
        stream.puts "  end"
        stream.puts
      end
    end

    def ignore_tables_with_enum_table
      ignore_tables_without_enum_table + @connection.enum_tables << 'enum_tables'
    end

    private

    def enum_table_column(stream, table_name, column_name, defaults)
      column = @connection.columns(table_name).find { |c| c.name == column_name }
      custom_attributes = {}
      COLUMN_ATTRIBUTES.each do |attribute|
        value = column.send(attribute)
        value == defaults[attribute] or
          custom_attributes[attribute] = value
      end
      if custom_attributes.present?
        formatted = custom_attributes.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')
        stream.puts "    t.#{column_name} #{formatted}"
      end
    end

    COLUMN_ATTRIBUTES = [:default, :type, :limit, :null, :precision, :scale]
  end
end

# This is not loaded in enum_table.rb as it's only needed when dumping the
# schema. Instead, we make rake tasks load this file explicitly.
ActiveRecord::SchemaDumper.send :include, EnumTable::SchemaDumper
