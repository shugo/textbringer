# frozen_string_literal: true

require "unicode/display_width"

module TextBringer
  class Buffer
    attr_reader :file_encoding, :point, :marks

    GAP_SIZE = 256

    UTF8_CHAR_LEN = Hash.new(1)
    [
      [0xc0..0xdf, 2],
      [0xe0..0xef, 3],
      [0xf0..0xf4, 4]
    ].each do |range, len|
      range.each do |c|
        UTF8_CHAR_LEN[c.chr] = len
      end
    end

    @@auto_detect_encodings = [
      Encoding::UTF_8,
      Encoding::EUC_JP,
      Encoding::Windows_31J
    ]

    def initialize(s = "", filename: nil, file_encoding: Encoding::UTF_8)
      @contents = s.encode(Encoding::UTF_8).force_encoding(Encoding::ASCII_8BIT)
      @filename = filename
      @file_encoding = file_encoding
      @point = 0
      @gap_start = 0
      @gap_end = 0
      @marks = []
      @mark = nil
      @column = nil
    end

    def self.open(filename)
      s = File.read(filename)
      enc = @@auto_detect_encodings.find { |e|
        s.force_encoding(e)
        s.valid_encoding?
      }
      Buffer.new(s, filename: filename, file_encoding: enc)
    end

    def save
      if @filename.nil?
        raise "filename is not set"
      end
      File.write(@filename, to_s, encoding: @file_encoding)
    end

    def to_s
      (@contents[0...@gap_start] +
       @contents[@gap_end..-1]).force_encoding(Encoding::UTF_8)
    end

    def substring(s, e)
      if s > @gap_start || e <= @gap_start
        @contents[user_to_gap(s)...user_to_gap(e)]
      else
        len = @gap_start - s
        @contents[user_to_gap(s), len] + @contents[@gap_end, e - s - len]
      end.force_encoding(Encoding::UTF_8)
    end

    def byte_after(location = @point)
      if location < @gap_start
        @contents.byteslice(location)
      else
        @contents.byteslice(location + gap_size)
      end
    end

    def char_after(location = @point)
      substring(location, location + UTF8_CHAR_LEN[byte_after(location)])
    end

    def bytesize
      @contents.bytesize - gap_size
    end
    alias size bytesize

    def insert(s)
      size = s.bytesize
      adjust_gap(size)
      @contents[@point, size] = s.b
      @marks.each do |m|
        if m.location > @point
          m.location += size
        end
      end
      @point = @gap_start += size
      @column = nil
    end

    def newline
      indentation = save_point { |saved|
        beginning_of_line
        s = @point
        while /[ \t]/ =~ char_after
          forward_char
        end
        substring(s, @point)
      }
      insert("\n" + indentation)
    end

    def delete_char(n = 1)
      adjust_gap
      pos = get_pos(@point, n)
      if n > 0
        @gap_end += pos - @point
        @marks.each do |m|
          if m.location > @point
            m.location -= pos - @point
          end
        end
      elsif n < 0
        @marks.each do |m|
          if m.location > @point
            m.location += pos - @point
          end
        end
        @point = @gap_start = pos
      end
      @column = nil
    end

    def backward_delete_char(n = 1)
      delete_char(-n)
    end

    def forward_char(n = 1)
      @point = get_pos(@point, n)
      @column = nil
    end

    def backward_char(n = 1)
      forward_char(-n)
    end

    def next_line
      if @column
        column = @column
      else
        prev_point = @point
        beginning_of_line
        column = substring(@point, prev_point).display_width
      end
      end_of_line
      forward_char
      s = @point
      while !end_of_buffer? &&
          byte_after != "\n" &&
          substring(s, @point).display_width < column
        forward_char
      end
      @column = column
    end

    def previous_line
      if @column
        column = @column
      else
        prev_point = @point
        beginning_of_line
        column = substring(@point, prev_point).display_width
      end
      beginning_of_line
      backward_char
      beginning_of_line
      s = @point
      while !end_of_buffer? &&
          byte_after != "\n" &&
          substring(s, @point).display_width < column
        forward_char
      end
      @column = column
    end

    def beginning_of_buffer
      @point = 0
    end

    def beginning_of_buffer?
      @point == 0
    end

    def end_of_buffer
      @point = bytesize
    end

    def end_of_buffer?
      @point == bytesize
    end

    def beginning_of_line
      while !beginning_of_buffer? &&
          byte_after(@point - 1) != "\n"
        backward_char
      end
      @point
    end

    def end_of_line
      while !end_of_buffer? &&
          byte_after(@point) != "\n"
        forward_char
      end
      @point
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
      mark.location = @point
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

    def save_point
      saved = new_mark
      column = @column
      begin
        yield(saved)
      ensure
        point_to_mark(saved)
        saved.delete
        @column = column
      end
    end

    def mark
      @mark&.location
    end

    def set_mark(pos = @point)
      @mark ||= new_mark
      @mark.location = pos
    end

    def copy_region(s = @point, e = mark)
      KILL_RING.push(s <= e ? substring(s, e) : substring(e, s))
    end

    def kill_region(s = @point, e = mark)
      copy_region(s, e)
      delete_region(s, e)
    end

    def delete_region(s = @point, e = mark)
      save_point do
        if s > e
          s, e = e, s
        end
        @point = s
        adjust_gap
        @gap_end += e - s
        @marks.each do |m|
          if m.location > @point
            m.location -= e - s
          end
        end
      end
    end

    def kill_line
      save_point do |saved|
        if end_of_buffer?
          raise RangeError, "end of buffer"
        end
        if char_after == ?\n
          forward_char
        else
          end_of_line
        end
        kill_region(saved.location, @point)
      end
    end

    def yank
      insert(KILL_RING.last)
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
        @contents[@gap_end, 0] = "\0" * extended_size
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

    def get_pos(pos, offset)
      if offset >= 0
        i = offset
        while i > 0
          raise RangeError, "out of buffer" if end_of_buffer?
          b = byte_after(pos)
          pos += UTF8_CHAR_LEN[b]
          raise RangeError, "out of buffer" if pos > bytesize
          i -= 1
        end
      else
        i = -offset
        while i > 0
          pos -= 1
          raise RangeError, "out of buffer" if pos < 0
          while /[\x80-\xbf]/n =~ byte_after(pos)
            pos -= 1
            raise RangeError, "out of buffer" if pos < 0
          end
          i -= 1
        end
      end
      pos
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

  class KillRing
    def initialize(max = 30)
      @max = max
      @ring = []
    end

    def push(str)
      if @ring.size == @max
        @ring.unshift
      end
      @ring.push(str)
    end

    def last
      if @ring.empty?
        raise "Kill ring is empty"
      end
      @ring.last
    end
  end

  KILL_RING = KillRing.new
end
