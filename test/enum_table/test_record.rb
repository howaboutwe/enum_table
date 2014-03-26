require_relative '../test_helper'

describe EnumTable do
  use_database

  before do
    connection.create_table :users do |t|
      t.integer :gender_id
      t.integer :status_id
      t.string :user_type
      t.integer :lock_version
    end
    Object.const_set :User, Class.new(ActiveRecord::Base)
  end

  after { Object.send :remove_const, :User }

  describe '.enum' do
    before do
      connection.create_table(:user_genders) { |t| t.string :value }
      connection.execute "INSERT INTO user_genders(id, value) VALUES (1, 'female')"
      connection.execute "INSERT INTO user_genders(id, value) VALUES (2, 'male')"
    end

    it "defines an enum by a conventionally named table by default" do
      User.enum :gender
      User.enums[:gender].value(1).must_equal(:female)
    end

    it "returns the reflection" do
      reflection = User.enum :gender
      reflection.must_be_kind_of EnumTable::Reflection
      reflection.name.must_equal :gender
    end

    it "performs the necessary SQL-escaping when reading the table" do
      connection.create_table("a'b") { |t| t.string :value }
      connection.execute "INSERT INTO `a'b`(id, value) VALUES (1, 'c''d')"
      Object.const_set :AB, Class.new(ActiveRecord::Base) { self.table_name = "a'b" }
      begin
        AB.enum :e, table: "a'b"
        AB.enums[:e].value(1).must_equal(:"c'd")
      ensure
        Object.send :remove_const, :AB
      end
    end

    it "accepts the :table name as a string" do
      connection.create_table(:custom_table) { |t| t.string :value }
      connection.execute "INSERT INTO custom_table(id, value) VALUES (1, 'male')"
      connection.execute "INSERT INTO custom_table(id, value) VALUES (2, 'female')"
      User.enum :gender, table: 'custom_table'
      User.enums[:gender].value(1).must_equal(:male)
    end

    it "accepts the :table name as a symbol" do
      connection.create_table(:custom_table) { |t| t.string :value }
      connection.execute "INSERT INTO custom_table(id, value) VALUES (1, 'male')"
      connection.execute "INSERT INTO custom_table(id, value) VALUES (2, 'female')"
      User.enum :gender, table: :custom_table
      User.enums[:gender].value(1).must_equal(:male)
    end

    it "accepts the :table directly as a hash" do
      User.enum :gender, table: {male: 1, female: 2}
      User.enums[:gender].value(1).must_equal :male
    end

    it "accepts the :table as an array" do
      User.enum :gender, table: [:male, :female]
      User.enums[:gender].value(1).must_equal :male
    end

    it "passes other options to the Reflection" do
      User.enum :gender, id_name: :gender_number
      enum = User.enums[:gender]
      enum.id_name.must_equal :gender_number
    end

    it "does not cry immediately if the enum table does not exist" do
      User.enum(:status)
    end

    it "does cry when you first try to use the enum if the enum table does not exist" do
      User.enum(:status)
      exception = nil
      begin
        User.enum_id(:status, 'awesome')
      rescue => exception
      end
      exception.must_be_kind_of StandardError
    end

    describe "when missing tables are allowed" do
      before { EnumTable.missing_tables_allowed }
      after { EnumTable.reset }

      it "does not cry when you first use the enum if the table does not exist" do
        User.enum(:status)
        User.enum_id(:status, 'awesome').must_equal nil
      end
    end


    describe "on a subclass" do
      before do
        User.inheritance_column = :user_type
        Object.const_set :Subuser, Class.new(User)
      end

      after do
        Object.send :remove_const, :Subuser
      end

      it "makes any values in the superclass available in the subclass" do
        User.enum :gender, table: {female: 1}
        Subuser.enum :gender, table: {male: 2}
        Subuser.reflect_on_enum(:gender).id(:female).must_equal 1
      end

      it "makes any values added in the subclass not available to the superclass" do
        User.enum :gender, table: {female: 1}
        Subuser.enum :gender, table: {male: 2}
        User.reflect_on_enum(:gender).id(:male).must_be_nil
      end

      it "inherits options from the superclass that aren't given for the subclass" do
        User.enum :gender, table: {female: 1, male: 2}, type: :string, id_name: :status_id
        Subuser.enum :gender
        reflection = Subuser.reflect_on_enum(:gender)
        reflection.id(:female).must_equal 1
        reflection.type.must_equal :string
        reflection.id_name.must_equal :status_id
      end

      it "inherits options from the superclass if no enum call is made in the subclass" do
        User.enum :gender, table: {female: 1, male: 2}
        Subuser.reflect_on_enum(:gender).id(:female).must_equal 1
      end

      it "allows overriding the :type option in the subclass" do
        User.enum :gender, type: :symbol
        Subuser.enum :gender, type: :string
        User.reflect_on_enum(:gender).type.must_equal :symbol
        Subuser.reflect_on_enum(:gender).type.must_equal :string
      end

      it "allows overriding the :id_name option in the subclass" do
        User.enum :gender, id_name: :status_id, type: :symbol
        Subuser.enum :gender, id_name: :status_id, type: :string
        User.reflect_on_enum(:gender).type.must_equal :symbol
        Subuser.reflect_on_enum(:gender).type.must_equal :string
      end
    end
  end

  describe ".reflect_on_enum" do
    before { User.enum :gender, table: {} }

    it "returns the reflection for the named enum" do
      reflection = User.reflect_on_enum(:gender)
      reflection.name.must_equal :gender
    end

    it "returns nil if there is no such enum" do
      User.reflect_on_enum(:invalid).must_be_nil
    end
  end

  describe ".enum_id" do
    before { User.enum :gender, table: {female: 1} }

    it "raises an ArgumentError if the enum name is invalid" do
      ->{ User.enum_id(:bad) }.must_raise ArgumentError
    end

    it "returns the id for the given enum value" do
      User.enum_id(:gender, :female).must_equal 1
    end
  end

  describe ".initialize_attributes" do
    before { User.enum :gender, table: {female: 1, male: 2} }

    it "converts enums to their underlying IDs" do
      attributes = User.initialize_attributes('gender' => 'female')
      attributes.must_equal('gender_id' => 1)
    end

    it "does not prevent optimistic locking from working, which also uses this internal method in AR < 4" do
      user = User.create(gender: :male)
      user.lock_version.must_equal 0

      user = User.find(user.id)
      user.update_attributes(gender: :female)
      user.lock_version.must_equal 1
    end

    it "should favor the ID if both the id and value are present in the attributes hash (so enums override columns)" do
      attributes = User.initialize_attributes('gender_id' => 1, 'gender' => :male)
      attributes['gender_id'].must_equal 1
      attributes.key?('gender').must_equal false
    end

    it "should take an options hash in addition to the attributes hash and not raise an error" do
      User.initialize_attributes({ 'gender' => 'female' }, { :some => :stuff }).wont_be_nil
    end
  end

  describe "#enum_id" do
    before { User.enum :gender, table: {female: 1} }

    it "raises an ArgumentError if the enum name is invalid" do
      user = User.new
      ->{ user.enum_id(:bad) }.must_raise ArgumentError
    end

    it "returns the id for the given enum value" do
      user = User.new
      user.enum_id(:gender, :female).must_equal 1
    end
  end

  describe "#read_enum" do
    before { User.enum :gender, table: {female: 1, male: 2} }

    it "raises an ArgumentError if the enum name is invalid" do
      user = User.new
      ->{ user.read_enum(:bad) }.must_raise ArgumentError
    end

    it "returns the value mapped to the id" do
      user = User.new(gender_id: 1)
      user.read_enum(:gender).must_equal :female
    end

    it "returns nil if the id is not mapped" do
      user = User.new(gender_id: 3)
      user.read_enum(:gender).must_be_nil
    end

    describe "when loading an existing record" do
      before do
        connection.execute "INSERT INTO users(id, gender_id) VALUES(1, 1)"
      end

      it "returns the correct value" do
        user = User.find(1)
        user.read_enum(:gender).must_equal :female
      end
    end
  end

  describe "#write_enum" do
    before { User.enum :gender, table: {female: 1, male: 2} }

    it "raises an ArgumentError if the enum name is invalid" do
      user = User.new
      ->{ user.write_enum(:bad, :female) }.must_raise ArgumentError
    end

    it "sets the id to the id mapped to the given value" do
      user = User.new
      user.write_enum(:gender, :female)
      user.gender_id.must_equal 1
    end

    it "sets the id to nil if the given value is not mapped to an id" do
      user = User.new
      user.write_enum(:gender, :other)
      user.gender_id.must_be_nil
    end
  end

  describe "#read_attribute" do
    before { User.enum :gender, table: {female: 1, male: 2} }

    it "reads enums" do
      user = User.new(gender_id: 1)
      user.read_attribute(:gender).must_equal :female
    end

    it "allows string names for enums" do
      user = User.new(gender_id: 1)
      user.read_attribute('gender').must_equal :female
    end

    it "still reads attributes" do
      user = User.new(gender_id: 1)
      user.read_attribute(:gender_id).must_equal 1
    end
  end

  describe "#write_attribute" do
    before { User.enum :gender, table: {female: 1, male: 2} }

    it "writes enums" do
      user = User.new
      user.write_attribute(:gender, :female)
      user.gender_id.must_equal 1
    end

    it "allows string names for enums" do
      user = User.new
      user.write_attribute('gender', :female)
      user.gender_id.must_equal 1
    end

    it "still writes attributes" do
      user = User.new
      user.write_attribute(:gender_id, 1)
      user.gender_id.must_equal 1
    end
  end

  describe "#query_enum" do
    before { User.enum :gender, table: {female: 1, male: 2} }

    it "raises an ArgumentError if the enum name is invalid" do
      user = User.new
      ->{ user.query_enum(:bad) }.must_raise ArgumentError
    end

    it "returns true if the is mapped to a value" do
      user = User.new(gender_id: 1)
      user.query_enum(:gender).must_equal true
    end

    it "returns false if the given value is not mapped to an id" do
      user = User.new(gender_id: 3)
      user.query_enum(:gender).must_equal false
    end
  end

  describe "#enum_changed?" do
    before do
      User.enum :gender, table: {female: 1, male: 2}
      User.create(gender_id: 1)
    end

    it "raises an ArgumentError if the enum name is invalid" do
      user = User.first
      ->{ user.enum_changed?(:bad) }.must_raise ArgumentError
    end

    it "returns true if the enum value changed" do
      user = User.first
      user.gender = :male
      user.enum_changed?(:gender).must_equal true
    end

    it "returns true if the id attribute changed" do
      user = User.first
      user.gender_id = 2
      user.enum_changed?(:gender).must_equal true
    end

    it "returns false if the attribute value has not changed" do
      user = User.first
      user.enum_changed?(:gender).must_equal false
    end
  end

  describe "#enum_was" do
    before do
      User.enum :gender, table: {female: 1, male: 2}
      User.create(gender_id: 1)
    end

    it "raises an ArgumentError if the enum name is invalid" do
      user = User.first
      ->{ user.enum_was(:bad) }.must_raise ArgumentError
    end

    it "returns the old value if the enum value changed" do
      user = User.first
      user.gender = :male
      user.enum_was(:gender).must_equal :female
    end

    it "returns the old value if the id attribute changed" do
      user = User.first
      user.gender_id = 2
      user.enum_was(:gender).must_equal :female
    end

    it "returns the current value if the enum has not changed" do
      user = User.first
      user.enum_was(:gender).must_equal :female
    end
  end

  describe "#enum_change" do
    before do
      User.enum :gender, table: {female: 1, male: 2}
      User.create(gender_id: 1)
    end

    it "raises an ArgumentError if the enum name is invalid" do
      user = User.first
      ->{ user.enum_change(:bad) }.must_raise ArgumentError
    end

    it "returns the old and new values if the enum value changed" do
      user = User.first
      user.gender = :male
      user.enum_change(:gender).must_equal [:female, :male]
    end

    it "returns the old and new values if the enum id changed" do
      user = User.first
      user.gender_id = 2
      user.enum_change(:gender).must_equal [:female, :male]
    end

    it "returns nil if the enum has not changed" do
      user = User.first
      user.enum_change(:gender).must_be_nil
    end
  end

  describe "#ENUM" do
    before { User.enum :gender, table: {female: 1, male: 2} }

    it "returns the enum value" do
      user = User.new(gender_id: 1)
      user.gender.must_equal :female
    end
  end

  describe "#ENUM=" do
    before { User.enum :gender, table: {female: 1, male: 2} }

    it "sets the enum value" do
      user = User.new
      user.gender = :female
      user.gender_id.must_equal 1
    end
  end

  describe "#ENUM?" do
    before { User.enum :gender, table: {female: 1, male: 2} }

    it "returns true if the enum value is present" do
      user = User.new(gender_id: nil)
      user.gender?.must_equal false

      user = User.new(gender_id: 1)
      user.gender?.must_equal true
    end
  end

  describe "#ENUM_changed?" do
    before do
      User.enum :gender, table: {female: 1, male: 2}
      User.create(gender_id: 1)
    end

    it "returns the changed flag for the enum" do
      user = User.first
      user.gender_changed?.must_equal false

      user.gender_id = 2
      user.gender_changed?.must_equal true
    end
  end

  describe "#ENUM_was" do
    before do
      User.enum :gender, table: {female: 1, male: 2}
      User.create(gender_id: 1)
    end

    it "returns the changed flag for the enum" do
      user = User.first
      user.gender_was.must_equal :female
    end
  end

  describe "#ENUM_change" do
    before do
      User.enum :gender, table: {female: 1, male: 2}
      User.create(gender_id: 1)
    end

    it "returns the old and new values for the enum" do
      user = User.first
      user.gender_change.must_be_nil

      user.gender_id = 2
      user.gender_change.must_equal [:female, :male]
    end
  end

  describe "roundtripping" do
    it "roundtrips a value through write and read" do
      User.enum :gender, table: {female: 1, male: 2}
      user = User.new
      user.gender = :female
      user.gender.must_equal :female
    end

    it "roundtrips a value through persistence" do
      User.enum :gender, table: {female: 1, male: 2}
      User.create(gender: :female)
      User.first.gender.must_equal :female
    end

    it "supports strings values" do
      User.enum :gender, table: {female: 1, male: 2}, type: :string
      User.create(gender: 'female')
      User.first.gender.must_equal 'female'
    end
  end

  describe ".where" do
    it "supports filtering by enums with symbol keys" do
      User.enum :gender, table: {female: 1, male: 2}
      female = User.create(gender_id: 1)
      male   = User.create(gender_id: 2)
      User.where(gender: :female).to_a.must_equal [female]
    end

    it "supports filtering by enums with string keys" do
      User.enum :gender, table: {female: 1, male: 2}
      female = User.create(gender_id: 1)
      male   = User.create(gender_id: 2)
      User.where('gender' => :female).to_a.must_equal [female]
    end

    it "supports filtering by multiple values" do
      User.enum :gender, table: {female: 1, male: 2, other: 3}
      female = User.create(gender_id: 1)
      male   = User.create(gender_id: 2)
      other  = User.create(gender_id: 3)
      User.where(gender: [:female, :male]).to_a.must_equal [female, male]
    end

    it "still supports filtering by other attributes" do
      User.enum :gender, table: {female: 1, male: 2}
      female1 = User.create(gender_id: 1, status_id: 1)
      male1   = User.create(gender_id: 2, status_id: 1)
      male2   = User.create(gender_id: 2, status_id: 2)
      User.where(gender: :male, status_id: 1).to_a.must_equal [male1]
    end
  end

  if ActiveRecord::VERSION::MAJOR < 4
    describe "dynamic finders" do
      it "support retrieval by enums" do
        User.enum :gender, table: {female: 1, male: 2}
        female = User.create(gender_id: 1)
        male   = User.create(gender_id: 2)

        User.find_by_gender(:female).must_equal female
        User.find_all_by_gender(:female).must_equal [female]
      end
    end
  else
    describe ".find_or_initialize_by" do
      it "supports building with enums" do
        User.enum :gender, table: {female: 1, male: 2}

        user = User.find_or_initialize_by(gender: :female)
        user.gender_id.must_equal 1
        user.gender.must_equal :female
        user.save!
      end

      it "supports finding by enums" do
        female = User.create(gender_id: 1)
        male   = User.create(gender_id: 2)

        User.enum :gender, table: {female: 1, male: 2}

        user = User.find_or_initialize_by(gender: :female)
        user.must_equal female
      end
    end
  end

  describe "when the inheritance column is an enum" do
    before do
      connection.add_column :users, :type_id, :integer
      User.enum :type, table: {Admin: 1, Member: 2}
      Object.const_set :Admin, Class.new(User)
      Object.const_set :Member, Class.new(User)
    end

    after do
      Object.send :remove_const, :Admin
      Object.send :remove_const, :Member

      # Instantiating STI classes goes through ActiveSupport::Dependencies.
      ActiveSupport::Dependencies.clear
    end

    it "sets the type ID when instantiating" do
      admin = Admin.create
      admin.type_id.must_equal 1
    end

    it "instantiates the correct class through the superclass" do
      admin = Admin.create
      user = User.find(admin.id)
      user.class.must_equal Admin
      user.id.must_equal admin.id
    end

    it "finds and instantiates the correct class through the subclass" do
      admin = Admin.create
      found = Admin.find(admin.id)
      found.class.must_equal Admin
      found.id.must_equal admin.id
    end

    it "filters correctly when finding through the subclass" do
      admin = Admin.create
      Admin.find(admin.id).must_equal admin
      Member.find_by_id(admin.id).must_be_nil
    end
  end

  describe "when an enum has the same name as a column" do
    before do
      connection.add_column :users, :gender, :string
      User.enum :gender, table: {female: 1, male: 2}
    end

    # TODO: It's probably desirable to write the column if it's present, for
    # transitioning to an enum.
    it "only writes the enum id" do
      User.create(gender_id: 1)
      results = connection.execute("SELECT gender_id, gender FROM users").to_a
      results.size.must_equal 1
      results[0][0].must_equal 1
      results[0][1].must_equal nil
    end

    it "favors the enum when loading" do
      connection.execute "INSERT INTO users(gender_id, gender) VALUES(1, 'male')"
      User.first.gender_id.must_equal 1
      User.first.gender.must_equal :female
    end
  end
end
