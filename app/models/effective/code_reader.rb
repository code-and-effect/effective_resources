module Effective
  class CodeReader
    attr_reader :lines

    def initialize(filename, &block)
      @lines = File.open(filename).readlines
      block.call(self) if block_given?
    end

    # Iterate over the lines with a depth, and passed the stripped line to the passed block
    def each_with_depth(from: nil, to: nil, &block)
      Array(lines).each_with_index do |line, index|
        next if index < (from || 0)

        depth = line.length - line.lstrip.length
        block.call(line.strip, depth, index)

        break if to == index
      end

      nil
    end

    # Returns the index of the first line where the passed block returns true
    def index(from: nil, to: nil, &block)
      each_with_depth(from: from, to: to) do |line, depth, index|
        return index if block.call(line, depth, index)
      end
    end

    # Returns the stripped contents of the line in which the passed block returns true
    def first(from: nil, to: nil, &block)
      each_with_depth(from: from, to: to) do |line, depth, index|
        return line if block.call(line, depth, index)
      end
    end
    alias_method :find, :first

    # Returns the stripped contents of the last line where the passed block returns true
    def last(from: nil, to: nil, &block)
      retval = nil

      each_with_depth(from: from, to: nil) do |line, depth, index|
        retval = line if block.call(line, depth, index)
      end

      retval
    end

    # Returns an array of stripped lines for each line where the passed block returns true
    def select(from: nil, to: nil, &block)
      retval = []

      each_with_depth(from: from, to: to) do |line, depth, index|
        retval << line if (block_given? == false || block.call(line, depth, index))
      end

      retval
    end

  end
end
