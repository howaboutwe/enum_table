module EnumTable
  class Reflection
    def initialize(name, options={})
      @name = name
      @id_name = options[:id_name] || :"#{name}_id"
      @type = options[:type] || :symbol
      @type == :string || @type == :symbol or
        raise ArgumentError, "invalid type: #{type.inspect}"

      @strings_to_ids = {}
      @values_to_ids = {}
      @ids_to_values = {}
      @populate_procs = []
      @populated = false
    end

    def initialize_copy(other)
      @name = other.name
      @id_name = other.id_name
      @type = other.type

      @strings_to_ids = other.instance_variable_get(:@strings_to_ids).dup
      @values_to_ids = other.instance_variable_get(:@values_to_ids).dup
      @ids_to_values = other.instance_variable_get(:@ids_to_values).dup
      @populate_procs = other.instance_variable_get(:@populate_procs).dup
      @populated = false
    end

    attr_reader :name
    attr_accessor :id_name, :type

    def to_populate(&block)
      @populate_procs << block
    end

    def add_value(id, value)
      id = id.to_i
      @strings_to_ids[value.to_s] = id

      cast_value = @type == :string ? value.to_s : value.to_sym
      @values_to_ids[cast_value] = id
      @ids_to_values[id] = cast_value
    end

    def id(value)
      ensure_populated
      if value.is_a?(String) || type == :string
        @strings_to_ids[value.to_s.strip]
      else
        @values_to_ids[value]
      end
    end

    def value(id)
      ensure_populated
      @ids_to_values[id]
    end

    def values
      ensure_populated
      @values_to_ids.keys
    end

    private

    def ensure_populated
      return if @populated
      @populate_procs.each { |p| p.call(self) }
      @populate_procs.clear
      @populated = true
    end
  end
end
