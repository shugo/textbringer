# frozen_string_literal: true

require "unicode/display_width"

module Textbringer
  class Buffer
    attr_accessor :name, :file_name, :file_encoding, :file_format
    attr_reader :point, :marks

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

    def initialize(s = "", name: nil,
                   file_name: nil, file_encoding: Encoding::UTF_8)
      @contents = s.encode(Encoding::UTF_8)
      @contents.force_encoding(Encoding::ASCII_8BIT)
      @name = name
      @file_name = file_name
      @file_encoding = file_encoding
      case @contents
      when /(?<!\r)\n/ 
        @file_format = :unix
      when /\r(?!\n)/
        @file_format = :mac
        @contents.gsub!(/\r/, "\n")
      when /\r\n/
        @file_format = :dos
        @contents.gsub!(/\r/, "")
      else
        @file_format = :unix
      end
      @point = 0
      @gap_start = 0
      @gap_end = 0
      @marks = []
      @mark = nil
      @column = nil
      @undo_stack = []
      @redo_stack = []
      @undoing = false
    end

    def self.open(file_name, name: File.basename(file_name))
      s = File.read(file_name)
      enc = @@auto_detect_encodings.find { |e|
        s.force_encoding(e)
        s.valid_encoding?
      }
      Buffer.new(s, name: name,
                 file_name: file_name, file_encoding: enc)
    end

    def save
      if @file_name.nil?
        raise "file name is not set"
      end
      s = to_s
      case @file_format
      when :dos
        s.gsub!(/\n/, "\r\n")
      when :mac
        s.gsub!(/\n/, "\r")
      end
      File.write(@file_name, s, encoding: @file_encoding)
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

    def point_min
      0
    end

    def point_max
      bytesize
    end

    def goto_char(pos)
      if pos < 0 || pos > size
        raise RangeError, "Out of buffer"
      end
      @point = pos
    end

    def insert(s, merge_undo = false)
      pos = @point
      size = s.bytesize
      adjust_gap(size)
      @contents[@point, size] = s.b
      @marks.each do |m|
        if m.location > @point
          m.location += size
        end
      end
      @point = @gap_start += size
      unless @undoing
        if merge_undo && @undo_stack.last.is_a?(InsertAction)
          @undo_stack.last.merge(s)
        else
          @undo_stack.push(InsertAction.new(self, pos, s))
        end
        @redo_stack.clear
      end
      @column = nil
    end

    def newline
      indentation = save_point { |saved|
        beginning_of_line
        s = @point
        while /[ \t]/ =~ char_after
          forward_char
        end
        str = substring(s, @point)
        if end_of_buffer? || char_after == "\n"
          delete_region(s, @point)
        end
        str
      }
      insert("\n" + indentation)
    end

    def delete_char(n = 1)
      adjust_gap
      s = @point
      pos = get_pos(@point, n)
      if n > 0
        str = substring(s, pos)
        @gap_end += pos - @point
        @marks.each do |m|
          if m.location > @point
            m.location -= pos - @point
          end
        end
        unless @undoing
          @undo_stack.push(DeleteAction.new(self, s, s, str))
          @redo_stack.clear
        end
      elsif n < 0
        str = substring(pos, s)
        @marks.each do |m|
          if m.location > @point
            m.location += pos - @point
          end
        end
        @point = @gap_start = pos
        unless @undoing
          @undo_stack.push(DeleteAction.new(self, s, pos, str))
          @redo_stack.clear
        end
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
        column = Unicode::DisplayWidth.of(substring(@point, prev_point), 2)
      end
      end_of_line
      forward_char
      s = @point
      while !end_of_buffer? &&
          byte_after != "\n" &&
          Unicode::DisplayWidth.of(substring(s, @point), 2) < column
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
        column = Unicode::DisplayWidth.of(substring(@point, prev_point), 2)
      end
      beginning_of_line
      backward_char
      beginning_of_line
      s = @point
      while !end_of_buffer? &&
          byte_after != "\n" &&
          Unicode::DisplayWidth.of(substring(s, @point), 2) < column
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

    def copy_region(s = @point, e = mark, append = false)
      str = s <= e ? substring(s, e) : substring(e, s)
      if append && KILL_RING.last
        KILL_RING.last.concat(str)
      else
        KILL_RING.push(str)
      end
    end

    def kill_region(s = @point, e = mark, append = false)
      copy_region(s, e, append)
      delete_region(s, e)
    end

    def delete_region(s = @point, e = mark)
      save_point do
        old_pos = @point
        if s > e
          s, e = e, s
        end
        str = substring(s, e)
        @point = s
        adjust_gap
        @gap_end += e - s
        @marks.each do |m|
          if m.location > @point
            m.location -= e - s
          end
        end
        unless @undoing
          @undo_stack.push(DeleteAction.new(self, old_pos, s, str)) 
        end
      end
    end

    def kill_line(append = false)
      save_point do |saved|
        if end_of_buffer?
          raise RangeError, "end of buffer"
        end
        if char_after == ?\n
          forward_char
        else
          end_of_line
        end
        kill_region(saved.location, @point, append)
      end
    end

    def yank
      insert(KILL_RING.last)
    end

    def undo
      if @undo_stack.empty?
        raise "No further undo information"
      end
      action = @undo_stack.pop
      @undoing = true
      begin
        action.undo
        @redo_stack.push(action)
      ensure
        @undoing = false
      end
    end

    def redo
      if @redo_stack.empty?
        raise "No further redo information"
      end
      action = @redo_stack.pop
      @undoing = true
      begin
        action.redo
        @undo_stack.push(action)
      ensure
        @undoing = false
      end
    end

    def re_search_forward(s)
      re = Regexp.new(s.dup.force_encoding(Encoding::ASCII_8BIT))
      unless @contents.index(re, user_to_gap(@point))
        raise "Search failed"
      end
      m = Regexp.last_match
      if m.begin(0) < @gap_end && m.end(0) > @gap_start
        unless @contents.index(re, @gap_end)
          raise "Search failed"
        end
      end
      goto_char(Regexp.last_match.end(0))
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
          raise RangeError, "Out of buffer" if end_of_buffer?
          b = byte_after(pos)
          pos += UTF8_CHAR_LEN[b]
          raise RangeError, "Out of buffer" if pos > bytesize
          i -= 1
        end
      else
        i = -offset
        while i > 0
          pos -= 1
          raise RangeError, "Out of buffer" if pos < 0
          while /[\x80-\xbf]/n =~ byte_after(pos)
            pos -= 1
            raise RangeError, "Out of buffer" if pos < 0
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

  class InsertAction
    def initialize(buffer, location, string)
      @buffer = buffer
      @location = location
      @string = string
    end

    def undo
      @buffer.goto_char(@location)
      @buffer.delete_char(@string.size)
    end

    def redo
      @buffer.goto_char(@location)
      @buffer.insert(@string)
    end

    def merge(s)
      @string.concat(s)
    end
  end

  class DeleteAction
    def initialize(buffer, location, insert_location, string)
      @buffer = buffer
      @location = location
      @insert_location = insert_location
      @string = string
    end

    def undo
      @buffer.goto_char(@insert_location)
      @buffer.insert(@string)
      @buffer.goto_char(@location)
    end

    def redo
      @buffer.goto_char(@insert_location)
      @buffer.delete_char(@string.size)
    end
  end
end
