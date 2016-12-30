# frozen_string_literal: true

module TextBringer
  class Buffer
    attr_reader :point

    GAP_SIZE = 256

    def initialize
      @buf = String.new
      @point = 0
      @gap_start = 0
      @gap_end = 0
    end

    def to_s
      @buf.dup.tap { |s|
        s[@gap_start...@gap_end] = ""
      }
    end

    def size
      @buf.size - gap_size
    end

    def insert(s)
      adjust_gap(s.size)
      @buf[@point, s.size] = s
      @point = @gap_start += s.size
    end

    def delete_char(n = 1)
      adjust_gap
      if n > 0
        if @gap_end + n > @buf.size
          raise RangeError, "out of buffer"
        end
        @gap_end += n
      elsif n < 0
        if @gap_start + n < 0
          raise RangeError, "out of buffer"
        end
        @point = @gap_start -= 1
      end
    end

    def forward_char(n = 1)
      new_point = @point + n
      if new_point < 0 || new_point > size
        raise ArgumentError, "out of bounds"
      end
      @point = new_point
    end

    def backward_char(n = 1)
      forward_char(-n)
    end

    def beginning_of_buffer
      @point = 0
    end

    def end_of_buffer
      @point = size
    end

    private

    def adjust_gap(min_size = 0)
      return if @point == @gap_start && gap_size >= min_size
      @buf[@gap_start...@gap_end] = ""
      @gap_start = @point
      new_gap_size = GAP_SIZE + min_size
      @gap_end = @gap_start + new_gap_size
      @buf[@gap_start, 0] = "\0" * new_gap_size
    end

    def gap_size
      @gap_end - @gap_start
    end
  end
end
