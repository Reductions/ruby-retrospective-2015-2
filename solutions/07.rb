module LazyMode
  class Date
    def initialize(date)
      @year = date.split("-")[0]
      @month = date.split("-")[1]
      @day = date.split("-")[2]
    end

    def to_s
      "#{@year}-#{@month}-#{@month}"
    end

    def year
      @year.to_i
    end

    def month
      @year.to_i
    end

    def day
      @year.to_i
    end
  end

  def self.create_file (name, &block)
    file = File.new(name)
    file.instance_eval(&block)
    file
  end

  private

  class File
    attr_reader :name, :notes

    def initialize(name)
      @name = name
      @notes = []
    end

    def note(name, *tags, &block)
      new = Note.new(name, tags, @name)
      new.instance_eval(&block)
      @notes.push(new)
    end
  end

  class Note
    attr_reader :notes, :header, :tags, :file_name, :file_name, :date

    def initialize(header, *tags, file_name)
      @header = header
      @notes = []
      @tags = tags[0]
      @status = :topostpone
      @body = ""
      @file_name = file_name
    end

    def note(name, *tags, &block)
      new = Note.new(name, tags, @file_name)
      new.instance_eval(&block)
      @notes.push(new)
    end

    def status(new_status = @status)
      @status = new_status
    end

    def body(new_body = @body)
      @body = new_body
    end

    def scheduled(schedule)
      @date = Date.new(schedule.split(" ")[0])
    end
  end
end
