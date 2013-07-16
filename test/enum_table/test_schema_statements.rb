require_relative '../test_helper'

describe EnumTable::SchemaStatements do
  use_database

  describe "#create_enum_table" do
    it "creates an enum table with the default name and default schema if none are given" do
      connection.create_enum_table :genders
      connection.tables.sort.must_equal ['enum_tables', 'genders']
      connection.columns(:genders).map(&:name).must_equal ['id', 'value']
      connection.columns(:genders).map(&:type).must_equal [:integer, :string]
      connection.columns(:genders).map(&:null).must_equal [false, false]
    end

    it "accepts :values as a Hash" do
      connection.create_enum_table :genders, values: {female: 2, male: 5}
      read_table('genders').must_equal [[2, 'female'], [5, 'male']]
    end

    it "accepts :values as an Array" do
      connection.create_enum_table :genders, values: [:female, :male]
      read_table('genders').must_equal [[1, 'female'], [2, 'male']]
    end

    it "passes on other options to create_table" do
      connection.create_table :genders
      ->{ connection.create_enum_table :genders }.must_raise(ActiveRecord::StatementInvalid)
      connection.create_enum_table :genders, force: true
    end

    it "allows configuring the type column in the block" do
      connection.create_enum_table :genders do |t|
        t.value type: :integer, limit: 2
      end
      column = connection.columns(:genders).find { |c| c.name == 'value' }
      column.type.must_equal :integer
      column.limit.must_equal 2
    end

    it "records the enum_table" do
      connection.create_enum_table :genders
      result = connection.execute "SELECT table_name FROM enum_tables"
      result.map { |row| row[0] }.must_equal ['genders']
    end

    it "does not populate the table if no values are given" do
      connection.create_enum_table :genders
      read_table('genders').must_equal []
    end

    it "populates the table from values given in the block" do
      connection.create_enum_table :genders do |t|
        t.add :female, 1
        t.add :male, 2
      end
      read_table('genders').must_equal [[1, 'female'], [2, 'male']]
    end

    it "performs the necessary SQL escaping in value names" do
      connection.create_enum_table "a'b" do |t|
        t.add "c'd", 1
      end
      read_table("a'b").must_equal [[1, "c'd"]]
    end
  end

  describe "#change_enum_table" do
    before do
      connection.execute "CREATE TABLE genders(id integer, value varchar(20))"
      connection.execute "INSERT INTO genders (id, value) VALUES (1, 'female'), (2, 'male')"
    end

    it "inserts values added in the block" do
      connection.change_enum_table :genders do |t|
        t.add :other, 3
      end
      read_table('genders').must_equal [[1, 'female'], [2, 'male'], [3, 'other']]
    end

    it "defaults the ID to the next available" do
      connection.change_enum_table :genders do |t|
        t.add :other
      end
      read_table('genders').must_equal [[1, 'female'], [2, 'male'], [3, 'other']]
    end

    it "deletes values removed in the block" do
      connection.change_enum_table :genders do |t|
        t.remove :male
      end
      read_table('genders').must_equal [[1, 'female']]
    end

    it "performs the necessary SQL escaping in value names" do
      connection.create_enum_table "a'b" do |t|
        t.add "c'd", 1
      end

      connection.change_enum_table "a'b" do |t|
        t.remove "c'd"
        t.add "e'f", 1
      end
      read_table("a'b").must_equal [[1, "e'f"]]
    end
  end

  describe "#drop_enum_table" do
    it "removes the table from enum_tables if required" do
      connection.create_enum_table :genders
      connection.drop_enum_table :genders
      result = connection.execute "SELECT table_name FROM enum_tables"
      result.to_a.must_equal []
    end
  end

  describe "#enum_tables" do
    it "returns the names of the enum tables" do
      connection.create_enum_table :genders
      connection.create_enum_table :statuses
      connection.enum_tables.must_equal ['genders', 'statuses']
    end

    it "returns no tables if no enum tables have ever existed" do
      connection.enum_tables.must_equal []
    end

    it "returns no tables if all enum tables have been dropped" do
      connection.create_enum_table :genders
      connection.drop_enum_table :genders
      connection.enum_tables.must_equal []
    end

    it "clears memoized tables when an enum table is created" do
      connection.create_enum_table :genders
      connection.enum_tables.must_equal ['genders']
      connection.create_enum_table :statuses
      connection.enum_tables.must_equal ['genders', 'statuses']
    end

    it "clears memoized tables when an enum table is dropped" do
      connection.create_enum_table :genders
      connection.create_enum_table :statuses
      connection.enum_tables.must_equal ['genders', 'statuses']
      connection.drop_enum_table :genders
      connection.enum_tables.must_equal ['statuses']
    end
  end

  def read_table(name)
    rows = []
    connection.execute("SELECT id, value FROM #{connection.quote_table_name name} ORDER BY id").each do |row|
      rows << [row[0], row[1]]
    end
    rows
  end
end
