# frozen_string_literal: true

module TextBringer
  class Buffer
    attr_reader :point, :marks

    GAP_SIZE = 256

    def initialize
      @contents = String.new
      @point = 0
      @gap_start = 0
      @gap_end = 0
      @marks = []
    end

    def to_s
      @contents[0...@gap_start] + @contents[@gap_end..-1]
    end

    def get_string(n)
      if @point >= @gap_start || @point + n <= @gap_start
        @contents[user_to_gap(@point), n]
      else
        len = @gap_start - @point
        @contents[user_to_gap(@point), len] + @contents[@gap_end, n - len]
      end
    end

    def size
      @contents.size - gap_size
    end

    def insert(s)
      size = s.size
      adjust_gap(size)
      @contents[@point, size] = s
      @marks.each do |m|
        if m.location > @point
          m.location += size
        end
      end
      @point = @gap_start += size
    end

    def delete_char(n = 1)
      adjust_gap
      if n > 0
        if @gap_end + n > @contents.size
          raise RangeError, "out of buffer"
        end
        @gap_end += n
        @marks.each do |m|
          if m.location > @point
            m.location -= n
          end
        end
      elsif n < 0
        if @gap_start + n < 0
          raise RangeError, "out of buffer"
        end
        @marks.each do |m|
          if m.location > @point
            m.location += n
          end
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

    def find_first_in_forward(s)
      gpos = user_to_gap(@point)
      while gpos = @contents.index(s, gpos)
        if pos = gap_to_user(gpos)
          return @point = pos
        end
        gpos += s.size
      end
      end_of_buffer
    end

    def find_first_in_backward(s)
      gpos = user_to_gap(@point)
      while gpos = @contents.rindex(s, gpos)
        if pos = gap_to_user(gpos + s.size)
          return @point = pos
        end
      end
      beginning_of_buffer
    end

    def new_mark
      Mark.new(self, @point).tap { |m|
        @marks << m
      }
    end

    def point_to_mark(mark)
      @point = mark.location
    end

    def mark_to_point(mark)
      @mark.location = @point
    end

    def point_at_mark?(mark)
      @point == mark.location
    end

    def point_before_mark?(mark)
      @point < mark.location
    end

    def point_after_mark?(mark)
      @point > mark.location
    end

    def swap_point_and_mark(mark)
      @point, mark.location = mark.location, @point
    end

    private

    def adjust_gap(min_size = 0)
      if @gap_start < @point
        len = user_to_gap(@point) - @gap_end
        @contents[@gap_start, len] = @contents[@gap_end, len]
        @gap_start += len
        @gap_end += len
      elsif @gap_start > @point
        len = @gap_start - @point
        @contents[@gap_end - len, len] = @contents[@point, len]
        @gap_start -= len
        @gap_end -= len
      end
      if gap_size < min_size
        new_gap_size = GAP_SIZE + min_size
        extended_size = new_gap_size - gap_size
        @contents[@gap_end, extended_size] = "\0" * extended_size
        @gap_end += extended_size
      end
    end

    def gap_size
      @gap_end - @gap_start
    end

    def user_to_gap(pos)
      if pos <= @gap_start
        pos
      else
        gap_size + pos 
      end
    end

    def gap_to_user(gpos)
      if gpos <= @gap_start
        gpos
      elsif gpos >= @gap_end
        gpos - gap_size
      else
        nil
      end
    end
  end

  class Mark
    attr_accessor :location

    def initialize(buffer, location)
      @buffer = buffer
      @location = location
    end

    def delete
      @buffer.marks.delete(self)
    end
  end
end
