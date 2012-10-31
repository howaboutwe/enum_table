require_relative '../test_helper'

describe EnumTable::Reflection do
  let(:reflection) { EnumTable::Reflection.new(:gender, female: 1, male: 2) }

  describe "#initialize" do
    it "uses symbol values if :type is :symbol" do
      reflection = EnumTable::Reflection.new(:gender, type: :symbol)
      reflection.add_value 1, 'female'
      reflection.value(1).must_equal(:female)
    end

    it "uses string values if :type is :string" do
      reflection = EnumTable::Reflection.new(:gender, type: :string)
      reflection.add_value 1, :female
      reflection.value(1).must_equal('female')
    end

    it "raises an ArgumentError if :type is something else" do
      ->{ EnumTable::Reflection.new :gender, type: :other }.must_raise ArgumentError, /invalid type/
    end
  end

  describe "#initialize_copy" do
    it "sets the same name" do
      reflection = EnumTable::Reflection.new(:gender)
      copy = reflection.dup
      copy.name.must_equal :gender
    end

    it "sets the same values" do
      reflection = EnumTable::Reflection.new(:gender)
      reflection.add_value 1, :female
      copy = reflection.dup
      copy.value(1).must_equal :female
    end

    it "sets a separate collection of values" do
      reflection = EnumTable::Reflection.new(:gender)
      copy = reflection.dup
      copy.add_value(1, :female)
      reflection.value(1).must_be_nil
      copy.value(1).must_equal :female
    end

    it "sets the same type" do
      reflection = EnumTable::Reflection.new(:gender, type: :string)
      copy = reflection.dup
      copy.type.must_equal :string
    end

    it "sets the same id_name" do
      reflection = EnumTable::Reflection.new(:gender, id_name: :status_id)
      copy = reflection.dup
      copy.id_name.must_equal :status_id
    end
  end

  describe '#name' do
    it "returns the name of the reflection" do
      reflection = EnumTable::Reflection.new(:gender)
      reflection.name.must_equal :gender
    end
  end

  describe '#id_name' do
    it "can be set with an :id_name option" do
      reflection = EnumTable::Reflection.new(:gender, id_name: :gender_number)
      reflection.id_name.must_equal :gender_number
    end

    it "is the name suffixed with '_id' by default" do
      reflection = EnumTable::Reflection.new(:gender)
      reflection.id_name.must_equal :gender_id
    end
  end

  describe '#value' do
    it "returns the value for the given id" do
      reflection = EnumTable::Reflection.new(:gender)
      reflection.add_value 1, :female
      reflection.value(1).must_equal :female
    end

    it "returns nil if no value is defined for the given id" do
      reflection = EnumTable::Reflection.new(:gender)
      reflection.add_value 1, :female
      reflection.value(2).must_be_nil
    end
  end

  describe '#id' do
    it "returns the value for the given value" do
      reflection = EnumTable::Reflection.new(:gender)
      reflection.add_value 1, :female
      reflection.id(:female).must_equal 1
    end

    it "returns nil if no value is defined for the given id" do
      reflection = EnumTable::Reflection.new(:gender)
      reflection.add_value 1, :female
      reflection.id(:male).must_be_nil
    end
  end

  describe "#values" do
    it "returns the list of enum values" do
      reflection = EnumTable::Reflection.new(:gender)
      reflection.add_value 1, :female
      reflection.add_value 2, :male
      reflection.values.must_equal [:female, :male]
    end
  end
end
