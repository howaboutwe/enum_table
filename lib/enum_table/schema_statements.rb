module EnumTable
  module SchemaStatements
    def create_enum_table(table_name, options={})
      table = NewTable.new(self, table_name, options)
      yield table if block_given?
      table._create
      enum_tables_updated
    end

    def change_enum_table(table_name)
      yield Table.new(self, table_name)
    end

    def drop_enum_table(table_name)
      drop_table table_name
      execute "DELETE FROM enum_tables WHERE table_name = #{quote table_name}"
      enum_tables_updated
    end

    def enum_tables
      return [] if !table_exists?('enum_tables')
      @enum_tables ||= execute("SELECT table_name FROM enum_tables").
        map { |row| row[0] }.sort
    end

    def enum_tables_updated
      @enum_tables = nil
    end

    DEFAULT_VALUE_ATTRIBUTES = {type: :string, limit: 255, null: false}.freeze

    class NewTable
      def initialize(connection, name, options)
        @connection = connection
        @name = name
        @options = options
        @value = DEFAULT_VALUE_ATTRIBUTES.dup
        @adds = []
        values = options.delete(:values) and
          values.each { |args| add(*args) }
      end

      def _create
        @connection.create_table @name, @options do |t|
          t.column :value, @value.delete(:type), @value
        end
        unless @connection.table_exists?(:enum_tables)
          @connection.create_table :enum_tables, id: false, force: true do |t|
            t.string :table_name, null: false, limit: 255
          end
        end
        @connection.execute "INSERT INTO enum_tables(table_name) VALUES(#{@connection.quote @name})"
        table = Table.new(@connection, @name, 0)
        @adds.each { |args| table.add(*args) }
      end

      def value(options)
        @value.update(options)
      end

      def add(*args)
        @adds << args
      end
    end

    class Table
      def initialize(connection, name, max_id=nil)
        @connection = connection
        @name = name
        @max_id = @connection.execute("SELECT max(id) FROM #{@connection.quote_table_name @name}").to_a[0][0] || 0
      end

      def add(value, id=nil)
        id ||= @max_id + 1
        @max_id = id if id > @max_id
        @connection.execute "INSERT INTO #{@connection.quote_table_name @name}(id, value) VALUES(#{id}, #{@connection.quote value})"
      end

      def remove(value)
        @connection.execute "DELETE FROM #{@connection.quote_table_name @name} WHERE value = #{@connection.quote value}"
      end
    end
  end
end
