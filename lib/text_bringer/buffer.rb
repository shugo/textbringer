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
        @point = @gap_start += n
      end
    end

    def forward_char(n = 1)
      new_point = @point + n
      if new_point < 0 || new_point > size
        raise RangeError, "out of buffer"
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
      if @gap_start < @point
        len = user_to_gap(@point) - @gap_end
        @buf[@gap_start, len] = @buf[@gap_end, len]
        @gap_start += len
        @gap_end += len
      elsif @gap_start > @point
        len = @gap_start - @point
        @buf[@gap_end - len, len] = @buf[@point, len]
        @gap_start -= len
        @gap_end -= len
      end
      if gap_size < min_size
        new_gap_size = GAP_SIZE + min_size
        extended_size = new_gap_size - gap_size
        @buf[@gap_end, extended_size] = "\0" * extended_size
        @gap_end += extended_size
      end
    end

    def gap_size
      @gap_end - @gap_start
    end

    def user_to_gap(location)
      if location <= @gap_start
        location
      else
        gap_size + location 
      end
    end
  end
end
