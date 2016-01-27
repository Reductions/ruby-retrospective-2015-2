class Spreadsheet
  class Error < StandardError
    attr_reader :message

    def initialize(message)
      @message = message
    end

    def self.invalid(message)
      self.new("Invalid expression '#{message}'")
    end

    def self.cell(message)
      self.new("Cell '#{message}' does not exist")
    end

    def self.index(message)
      self.new("Invalid cell index '#{message}'")
    end

    def self.unknown(message)
      self.new("Unknown function '#{message}'")
    end

    def self.less(function, size)
      message = "Wrong number of arguments for '#{function}':"
      message << " expected at least 2, got #{size}"
      self.new(message)
    end

    def self.exact(function, size)
      message = "Wrong number of arguments for '#{function}':"
      message << " expected 2, got #{size}"
      self.new(message)
    end
  end

  class Text
    def initialize(text)
      @text = text
    end

    def to_s
      @text
    end

    def calculate(table)
      @text
    end
  end

  class Reference
    def initialize(text)
      @text = text
    end

    def to_s
      @text
    end

    def calculate(table)
      /\A= *([A-Z]+[1-9])+\z/.match(@text)
      raise Error.invalid(@text.delete('=')) if not index = $1
      result = table[index]
      return result if /\A[0-9]+\.[0-9]+\z/ !~ result and /\A[0-9]+\z/ !~ result
      return result.to_f.floor.to_s if result.to_f == result.to_f.floor
      '%.2f' % result.to_f.round(2)
    end
  end

  class Number
    def initialize(text)
      @text = text
    end

    def to_s
      @text
    end

    def calculate(table)
      /\A= *([0-9]+\.?[0-9]*)\z/.match(@text)
      raise Error.invalid(@text.delete('=')) if not result = $1
      return result.to_f.floor.to_s if result.to_f == result.to_f.floor
      '%.2f' % result.to_f.round(2)
    end
  end

  class Formula
    @@known = {
      ADD: ['+'.to_sym, 1],
      MULTIPLY: ['*'.to_sym, 1],
      SUBTRACT: ['-'.to_sym, 2],
      DIVIDE: ['/'.to_sym, 2],
      MOD: ['%'.to_sym, 2],
    }

    def initialize(text)
      @text = text
    end

    def to_s
      @text
    end

    def calculate(table)
      /\A= *([A-Z]+) *\(([A-Z0-9, .]*)\)\z/.match(@text)
      action, list = $1, $2
      raise Error.invalid(@text.delete('=')) if not action
      raise Error.invalid(@text.delete('=')) if not valid(list)
      raise Error.unknown(action) if not @@known[action.to_sym]
      helper(action.to_sym, list, table)
    end

    private

    def helper(action, list, table)
      if @@known[action][1] == 1
        multiple(action, list, table)
      else
        binary(action, list, table)
      end
    end

    def multiple(action, list, table)
      list = list.split(/ *, */)
      raise Error.less(action, list.size) if list.size < 2
      result = list.map { |item| evaluate(item).calculate(table).to_f }.
               reduce(@@known[action][0])
      return result.to_f.floor.to_s if result.to_f == result.to_f.floor
      '%.2f' % result.to_f.round(2)
    end

    def binary(action, list, table)
      list = list.split(/ *, */)
      raise Error.exact(action, list.size) if list.size != 2
      list.map! { |item| evaluate(item).calculate(table).to_f }
      result = list[0].to_f.send(@@known[action][0], list[1].to_f)
      return result.to_f.floor.to_s if result.to_f == result.to_f.floor
      '%.2f' % result.to_f.round(2)
    end

    def evaluate(cell)
      return Cell.new($1) if /\A([0-9]+\.?[0-9]*)\z/.match(cell)
      Cell.new("=#{cell}")
    end

    def valid(list)
      return true if list =~ / */
      list.split(/ *, */).each do |item|
        return true if item =~ /\A([0-9]+\.?[0-9]*)\z/
        return true if item =~ /\A*([A-Z]+[1-9])+\z/
      end
      return false
    end
  end

  class Cell
    def initialize(text)
      return @cell = Text.new(text) if text =~ /\A[^=]/
      return @cell = Number.new(text) if text =~ /\A= *[0-9.]+/
      return @cell = Reference.new(text) if text =~ /\A= *[A-Z]+[1-9]+/
      @cell = Formula.new(text)
    end

    def to_s
     @cell.to_s
    end

    def calculate(table)
      @cell.calculate(table)
    end
  end

  def initialize(sheet = '')
    /\A\s*(.*\S)\s*\z/m.match(sheet)
    return @cells = [] if not $1
    @cells = $1.split("\n")
    normalize_rows
    @cells.map! { |row| row.split(/  +|\t+/) }
    normalize_cells
  end

  def empty?
    @cells == []
  end

  def cell_at(cell)
    column, row = index(cell)
    if row >= @cells.size or column >= @cells[0].size
      raise Error.cell(cell)
    end
    @cells[row][column].to_s
  end

  def [](cell)
    column, row = index(cell)
    if row >= @cells.size or column >= @cells[0].size
      raise Error.cell(cell)
    end
    @cells[row][column].calculate(self)
  end

  def to_s
    @cells.map{ |row| row.map { |cell| cell.calculate(self) } }.
      map { |row| row.join("\t") }.join("\n")
  end

  private

  def index(cell)
    /\A([A-Z]+)([1-9][0-9]*)\z/.match(cell)
    column, row = $1, $2
    raise Error.index(cell) if not column or not row
    column = column.split('').map { |item| item.ord - 'A'.ord + 1 }.
             reduce(0) { |result, item| result * 26 + item } - 1
    return column, row.to_i - 1
  end

  def normalize_rows
    @cells.map! do |row|
      /\A\s*(.*\S)\s*\z/.match(row)
      $1
    end
  end

  def normalize_cells
    @cells.each do |row|
      row.map! do |cell|
        /\A\s*(.*\S)\s*\z/.match(cell)
        Cell.new($1)
      end
    end
  end
end
