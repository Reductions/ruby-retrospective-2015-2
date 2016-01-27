module TurtleGraphics
  module Canvas
    class ASCII
      def initialize(list)
        @ratio = list.map.
                 with_index { |item, index| [index.to_f / (list.size - 1), item] }
      end

      def generate_by(grid)
        max = grid.flatten.max.to_f
        grid.map { |row| row.map { |cell| pixel(cell / max) }.join}.join("\n")
      end

      def pixel(frequency)
        @ratio.drop_while { |item| item[0] < frequency }[0][1]
      end
    end

    class HTML
      def initialize(pixel_size)
        @size = pixel_size
      end

      def generate_by(grid)
        result = "<!DOCTYPE html><html><head><title>Turtle graphics</title><style>"
        result << "table{border-spacing: 0;}tr{padding: 0;}td{width: #{@size}px;"
        result << "height: #{@size}px;background-color: black;padding: 0;}</style>"
        result << "</head><body><table>#{table(grid)}</table></body></html>"
      end

      def table(grid)
        grid.map { |row| make_row(row, grid) }.join
      end

      def make_row(row, grid)
        max = grid.flatten.max.to_f
        "<tr>" + row.map { |cell| pixel(cell / max) }.join + "</tr>"
      end

      def pixel(opasity)
        "<td style=\"opacity: #{format('%.2f', opasity)}\"></td>"
      end
    end
  end

  class Turtle
    attr_accessor :grid

    @@cours = {right: [0, 1], down: [1, 0], left: [0, -1], up: [-1, 0]}

    def initialize (rows, columns)
      @grid = []
      rows.times { @grid.push(Array.new(columns, 0)) }
      @position = {column: 0, row: 0}
      @direction = @@cours.keys
    end

    def spawn_at(row, column)
      @position[:column] = column
      @position[:row] = row
      @grid[row][column] += 1
    end

    def look(orientation)
      @direction.rotate(1) unless @direction[0] == orientation
    end

    def turn_left
      @direction = @direction.rotate(-1)
    end

    def turn_right
      @direction = @direction.rotate(1)
    end

    def move
      if current == 0
        @grid[@position[:row]][@position[:column]] += 1
      end
      @position[:row] += @@cours[@direction[0]][0]
      @position[:column] += @@cours[@direction[0]][1]
      @position[:row] = @position[:row].modulo(@grid.size)
      @position[:column] = @position[:column].modulo(@grid[0].size)
      @grid[@position[:row]][@position[:column]] += 1
    end

    def draw(canvas = nil, &block)
      instance_eval(&block)
      if canvas
        canvas.generate_by(@grid)
      else
        @grid
      end
    end

    def current
      @grid[@position[:row]][@position[:column]]
    end
  end
end
