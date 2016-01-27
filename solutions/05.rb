require 'digest/sha1'

class ObjectStore
  class Message
    attr_reader :message, :result

    def initialize(message, success = true, result = nil)
      @message = message
      @success = success
      @result = result
    end

    def success?
      @success
    end

    def error?
      not @success
    end
  end

  class Commit
    attr_reader :content, :message, :date, :hash

    def initialize(content = {}, message = "")
      @content = content
      @message = message
      @date = Time.now
      @hash = Digest::SHA1.hexdigest(formated_date.to_s + @message)
    end

    def objects
      @content.values
    end

    def to_s
      "Commit #{@hash}\nDate: #{formated_date}\n\n\t#{@message}"
    end

    private

    def formated_date
      @date.strftime("%a %b %d %H:%M %Y %z")
    end
  end

  class BranchManager
    class Branch
      attr_accessor :added, :removed, :committed

      def initialize(committed, added = {}, removed = [])
        @added = added
        @removed = removed
        @committed = committed
      end

      private

      def commit(message)
        count = @added.size + @removed.size
        content = @committed[-1].content.merge(@added).
                  reject { |key, _| @removed.include?(key) }
        @committed << Commit.new(content, message)
        clear
        Message.new("#{message}\n\t#{count} objects changed", true,
                    @committed[-1])
      end

      def clear
        @added = {}
        @removed = []
      end
    end

    attr_accessor :name, :current

    def initialize
      @branches = {master: Branch.new([Commit.new])}
      @name = :master
      @current = @branches[:master]
    end

    def create(name)
      if @branches.has_key?(symbol_name = name.to_sym)
        Message.new("Branch #{name} already exists.", false)
      else
        @branches[symbol_name] = Branch.new(@current.committed.dup)
        Message.new("Created branch #{name}.")
      end
    end

    def checkout(branch_name)
      if @branches.has_key?(symbol_name = branch_name.to_sym)
        @current, @name = @branches[symbol_name], symbol_name
        Message.new("Switched to branch #{@name}.")
      else
        Message.new("Branch #{branch_name} does not exist.", false)
      end
    end

    def remove(branch_name)
      if branch_name.to_sym == @name
        Message.new("Cannot remove current branch.", false)
      elsif @branches.has_key?(branch_name.to_sym)
        @branches.delete(branch_name.to_sym)
        Message.new("Removed branch #{branch_name}.", true)
      else
        Message.new("Branch #{branch_name} does not exist.", false)
      end
    end

    def list
      message = @branches.keys.sort.map do |item|
        if item == @name
          "* #{item}"
        else
          "  #{item}"
        end
      end.join("\n")
      Message.new(message)
    end
  end

  attr_reader :branch

  def initialize
    @branch = BranchManager.new
  end

  def add(name, object)
    added[name.to_sym] = object
    Message.new("Added #{name} to stage.", true, object)
  end

  def commit(message)
    if added.empty? and removed.empty?
      Message.new("Nothing to commit, working directory clean.", false)
    else
      @branch.current.send(:commit, message)
    end
  end

  def remove(name)
    if committed[1].content.include?(symbol_name = name.to_sym)
      removed << symbol_name unless removed.include?(symbol_name)
      Message.new("Added #{name} for removal.", true,
               committed[1].content[symbol_name])
    else
      Message.new("Object #{name} is not committed.", false)
    end
  end

  def checkout(hash)
    if index = committed[1..-1].find_index { |commit| commit.hash == hash }
      committed.pop(committed.size - index - 2)
      Message.new("HEAD is now at #{hash}.", true, committed[-1])
    else
      Message.new("Commit #{hash} does not exist.", false)
    end
  end

  def head
    if committed.size > 1
      Message.new("#{committed[-1].message}", true, committed[-1])
    else
      Message.new("Branch #{@branch.name} does not have any commits yet.",
                  false)
    end
  end

  def log
    if committed.size == 1
      Message.new("Branch #{@branch.name} does not have any commits yet.",
                  false)
    else
      message = committed.reverse[0...-1].map { |item| item.to_s }.join("\n\n")
      Message.new(message)
      end
  end

  def get(name)
    if committed[-1].content.has_key?(name.to_sym)
      Message.new("Found object #{name}.",
                  true,
                  committed[-1].content[name.to_sym])
    else
      Message.new("Object #{name} is not committed.", false)
    end
  end

  def self.init(&block)
    container = self.new
    container.instance_eval(&block) if block_given?
    container
  end

  private

  def added
    @branch.current.added
  end

  def committed
    @branch.current.committed
  end

  def removed
    @branch.current.removed
  end
end
