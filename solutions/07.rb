module LazyMode
  class Date
    attr_reader :year, :day, :month

    def initialize(date)
      date =~ /(.*)-(.*)-(.*)/
      @year, @month, @day = $1.to_i, $2.to_i, $3.to_i
    end

    def to_s
      "#{@year.to_s.rjust(4,'0')}-#{@month.to_s.rjust(2,'0')}-" +
        "#{@month.to_s.rjust(2,'0')}"
    end

    def ==(other)
      year == other.year and month == other.month and day == other.day
    end

    def >=(other)
      ([year, month, day] <=> [other.year, other.month, other.day]) >= 1
    end

    def add(delay)
      /\+([0-9]*)([wdm])/ =~ delay
      multiplier, period = $1, $2
      @day += multiplier.to_i * {w: 7, d: 1, m: 30}[period.to_sym]
      @month, @day = @month + (@day - 1) / 30, (@day - 1) % 30 + 1
      @year, @month = @year + (@month - 1) / 12, (@month - 1) % 12 + 1
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

    def initialize(name, notes = [])
      @name = name
      @notes = notes
    end

    def note(name, *tags, &block)
      new = Note.new(name, tags, @name)
      new.instance_eval(&block)
      @notes.push(new)
    end

    def daily_agenda(date)
      note_list = @notes.map { |note| note.to_list(date) }.flatten.
                  select { |note| note.date == date }
      File.new("daily_agenda for #{date}", note_list)
    end

    def weekly_agenda(date)
      deadline = date.dup
      deadline.add("+1w")
      note_list = @notes.map { |note| note.to_list(deadline) }.flatten.
                  select { |note| note.date >= date and deadline >= note.date}
      File.new("daily_agenda for #{date}", note_list)
    end

    def where(tag: nil, text: nil, status: nil)
      list = @notes.dup
      list.select! { |note| note.tags.include?(tag) or tag == nil }
      list.select! { |note| note.status == status or status == nil }
      list.select! { |note| text == nil or
                     note.body =~ text or note.header =~ text }
      File.new("filtered", list)
    end
  end

  class ExactNote
    attr_reader :header, :tags, :file_name, :status, :body, :date

    def initialize(note)
      @header = note.header
      @tags = note.tags
      @status = note.status
      @body = note.body
      @file_name = note.file_name
      @date = note.date.dup
    end

  end

  class Note
    attr_reader :notes, :header, :tags, :file_name, :date, :status, :body

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
      schedule =~ /([0-9-]* ?(\+[1-9][0-9]*[wmd])*)/
      @date, @delay = Date.new($1), $2
    end

    def to_list(deadline)
      repeat(deadline).concat(@notes.map { |item| item.to_list(deadline) })
    end

    def repeat(deadline)
      list = [ExactNote.new(self)]
      return list unless @delay
      until list.last.date >= deadline
        list << ExactNote.new(list.last)
        list.last.date.add(@delay)
      end
      list
    end
  end
end
