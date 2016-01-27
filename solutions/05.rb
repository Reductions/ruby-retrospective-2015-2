require 'digest/sha1'

class Commit
  attr_reader :content, :message, :date, :hash

  def initialize(content = {}, message = "")
    @content = content
    @message = message
    @date = Time.now
    @hash = Digest::SHA1.hexdigest(message + @date.to_s)
  end

  def objects
    @content.values
  end

  def to_s
    "Commit #{@hash}\nDate: #{@date}\n\n\t#{@message}"
  end
end

class Information
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

class Branch
  attr_accessor :added, :removed, :commited

  def initialize(commited, added = {}, removed = [])
    @added = added
    @removed = removed
    @commited = commited
  end
end

class BranchManager
  def initialize
    @branches = {master: Branch.new([Commit.new])}
    @current = :master
  end

  def name
    @current.to_s
  end

  def current
    @branches[@current]
  end

  def create(name)
    if @branches.has_key(name.to_sym)
      Information.new("Branch #{name} already exists.", false)
    else
      @branches[name.to_sym] = @branches[@current]
      Information.new("Creat branch #{name}.")
    end
  end

  def checkout(branch_name)
    if @branches.has_key?(branch_name.to_sym)
      @current = branch_name.to_sym
      Information.new("Switched to branch #{@current}")
    else
      Information.new("Branch #{branch_name} does not exist", false)
    end
  end

  def remove(branch_name)
    if branch_name.to_sym == @current
      Information.new("Can't remove current branch.", false)
    elsif @branches.has_key(branch_name.to_sym)
      Information.new("Branch #{branch_name} does not exist.", false)
    else
      Information.new("Removed branch #{branch_name}", true)
    end
  end

  def list
    message = @branches.keys.sort { |first, second| first <=> second }
      .map do |item|
      if item == @current
        "* #{item}"
      else
        item.to_s
      end
    end
      .join("\n")
    Information.new(message)
  end
end

class ContentManager
  attr_accessor :branch

  def initialize
    @branch = BranchManager.new
  end

  def add(name, object)
    added[name.to_sym] = object
    Information.new("Added #{name} to stage.", true, object)
  end

  def commit(message)
    if added.empty?
      Information.new("Nothing to commit, working directory clean.", false)
    else
      count = added.size + removed.size
      new_content = commited[-1].content.merge(added)
                    .delete_if { |key, _| removed.member?(key) }
      commited.push(Commit.new(new_content,message))
      added, removed = {}, []
      Information.new("#{message}\n\t#{count} objects changed",
                      true,
                      commited[-1])
    end
  end

  def remove(name)
    if commited[-1].content.hash_key(name.to_sym)
      removed.push(name.to_sym)
      Information.new("Added #{name} for removal.",
                      true,
                      @commited[-1].content[name.to_sym])
    else
      Information.new("Object #{name} is not committed.", false)
    end
  end

  def checkout(hash)
    index = commited.find_index { |item| item.hash == hash }
    if index
      @branch.current.commited = commited[0..index]
      Information.new("HEAD is now at #{hash}", true, commited[-1])
    else
      Information.new("Commit #{hash} does not exist.", false)
    end
  end

  def head
    if commited.size > 1
      Information.new("#{commited[-1].message}", true, commited[-1])
    else
      Information.new("Branch #{@branch.name} does not have any commits yet.",
                      false)
    end
  end

  def log
    if commited.size == 1
      Information.new("Branch #{@branch.name} does not have any commits yet.",
                      false)
    else
      message = commited[1..-1].map { |item| item.to_s }.join("\n\n")
      Information.new(message)
    end
  end

  def get(name)
    if commited[-1].content.has_key?(name.to_sym)
      Information.new("Found object #{name}.",
                      true,
                      commited[-1].content[name.to_sym])
    else
      Information.new("Object #{name} is not commited.", false)
    end
  end

  def execute
    yield
  end

  private

  def added
    @branch.current.added
  end

  def commited
    @branch.current.commited
  end

  def removed
    @branch.current.removed
  end
end

class ObjectStore
  def ObjectStore.init(&block)
    if block_given?
      container = ContentManager.new
      container.instance_eval(&block)
      container
    else
      ContentManager.new
    end
  end
end
