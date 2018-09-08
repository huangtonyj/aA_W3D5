require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    if @db_query.nil?
      @db_query = DBConnection.execute2(<<-SQL)
        SELECT *
        FROM #{table_name}
        LIMIT 1
      SQL
    end

    @db_query.first.map(&:to_sym)
  end


  def self.finalize!
    self.columns.each do |col_name|

      define_method(col_name) do
        self.attributes[col_name]
      end

      define_method("#{col_name}=") do |value|
        self.attributes[col_name] = value
      end

    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.to_s.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT *
      FROM #{table_name}
    SQL
    parse_all(results)
  end

  def self.parse_all(results)
    results.map do |result|
      self.new(result)
    end
  end

  def self.find(id)
    # self.all.find {|obj| obj.id == id}

    result = DBConnection.execute(<<-SQL, id)
      SELECT *
      FROM #{self.table_name}
      WHERE id == ?
    SQL

    parse_all(result).first
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      if self.class.columns.include?(attr_name.to_sym)
        send("#{attr_name}=", value)
      else
        raise "unknown attribute '#{attr_name}'"
      end
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    @attributes.values
  end

  def insert
    table = "#{self.class.table_name}"
    columns = self.class.columns.drop(1)
    col_names = columns.join(", ")
    question_marks = (["?"] * columns.length).join(", ")

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{table} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    table = "#{self.class.table_name}"
    sets = self.class.columns.map {|attr_name| "#{attr_name} = ?"}.drop(1).join(", ")

    DBConnection.execute(<<-SQL, *attribute_values.rotate)
      UPDATE
        #{table}
      SET
        #{sets}
      WHERE
        id = ?
    SQL
  end

  def save
    id.nil? ? insert : update
  end
end
