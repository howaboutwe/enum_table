require_relative '../test_helper'

describe EnumTable::SchemaDumper do
  use_database

  describe "#dump" do
    let(:stream) { StringIO.new }

    describe "when there are enum tables" do
      it "does not dump the enum_tables with create_table" do
        connection.create_enum_table :user_genders
        ActiveRecord::SchemaDumper.dump(connection, stream)
        stream.string.wont_match(/create_table.*user_genders/)
      end

      it "dumps the enum tables with create_enum_table" do
        connection.create_enum_table :user_genders
        ActiveRecord::SchemaDumper.dump(connection, stream)
        stream.string.must_match(/create_enum_table.*user_genders.*force: true/)
      end

      it "populates the enum tables" do
        connection.instance_eval do
          create_enum_table :user_genders do |t|
            t.add :female, 1
            t.add :male
          end
        end
        ActiveRecord::SchemaDumper.dump(connection, stream)
        stream.string.must_include(<<-EOS.gsub(/^ *\|/, ''))
          |  create_enum_table "user_genders", force: true do |t|
          |    t.add "female", 1
          |    t.add "male", 2
          |  end
        EOS
      end

      it "dumps custom value column attributes" do
        connection.create_enum_table :user_genders do |t|
          t.value type: :binary, limit: 20, null: true
        end
        ActiveRecord::SchemaDumper.dump(connection, stream)
        stream.string.must_include(<<-EOS.gsub(/^ *\|/, ''))
          |  create_enum_table "user_genders", force: true do |t|
          |    t.value type: :binary, limit: 20, null: true
          |  end
        EOS
      end

      it "performs the necessary SQL-escaping when reading tables" do
        connection.instance_eval do
          create_enum_table "a'b" do |t|
            t.add "c'd", 1
          end
        end
        ActiveRecord::SchemaDumper.dump(connection, stream)
        stream.string.must_include(<<-EOS.gsub(/^ *\|/, ''))
          |  create_enum_table "a'b", force: true do |t|
          |    t.add "c'd", 1
          |  end
        EOS
      end
    end

    describe "when there are no enum tables" do
      it "populates no enum tables if there are none" do
        ActiveRecord::SchemaDumper.dump(connection, stream)
        stream.string.wont_include('change_enum_table')
      end

      it "does not populate enum_tables" do
        ActiveRecord::SchemaDumper.dump(connection, stream)
        stream.string.wont_include "INSERT INTO enum_tables"
      end
    end
  end
end
