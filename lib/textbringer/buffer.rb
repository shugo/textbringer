# frozen_string_literal: true

require "unicode/display_width"

module Textbringer
  class Buffer
    attr_accessor :name, :file_name, :file_encoding, :file_format
    attr_reader :point, :marks

    GAP_SIZE = 256
    UNDO_LIMIT = 1000

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
      @yank_start = new_mark
      @undo_stack = []
      @redo_stack = []
      @undoing = false
      @version = 0
      @modified = false
    end

    def modified?
      @modified
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
      @version += 1
      @modified = false
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
      @column = nil
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
          @redo_stack.clear
        else
          push_undo(InsertAction.new(self, pos, s))
        end
      end
      @modified = true
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
        push_undo(DeleteAction.new(self, s, s, str))
        @modified = true
      elsif n < 0
        str = substring(pos, s)
        @marks.each do |m|
          if m.location > @point
            m.location += pos - @point
          end
        end
        @point = @gap_start = pos
        push_undo(DeleteAction.new(self, s, pos, str))
        @modified = true
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

    def forward_word(n = 1)
      n.times do
        while !end_of_buffer? && /\p{Letter}|\p{Number}/ !~ char_after
          forward_char
        end
        while !end_of_buffer? && /\p{Letter}|\p{Number}/ =~ char_after
          forward_char
        end
      end
    end

    def backward_word(n = 1)
      n.times do
        break if beginning_of_buffer?
        backward_char
        while !beginning_of_buffer? && /\p{Letter}|\p{Number}/ !~ char_after
          backward_char
        end
        while !beginning_of_buffer? && /\p{Letter}|\p{Number}/ =~ char_after
          backward_char
        end
        if /\p{Letter}|\p{Number}/ !~ char_after
          forward_char
        end
      end
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
      if @mark.nil?
        raise "The mark is not set"
      end
      @mark.location
    end

    def set_mark(pos = @point)
      @mark ||= new_mark
      @mark.location = pos
    end

    def copy_region(s = @point, e = mark, append = false)
      str = s <= e ? substring(s, e) : substring(e, s)
      if append && !KILL_RING.empty?
        KILL_RING.current.concat(str)
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
        push_undo(DeleteAction.new(self, old_pos, s, str)) 
        @modified = true
      end
    end

    def kill_line(append = false)
      save_point do |saved|
        if end_of_buffer?
          raise RangeError, "End of buffer"
        end
        if char_after == ?\n
          forward_char
        else
          end_of_line
        end
        pos = @point
        point_to_mark(saved)
        kill_region(@point, pos, append)
      end
    end

    def kill_word(append = false)
      save_point do |saved|
        if end_of_buffer?
          raise RangeError, "End of buffer"
        end
        forward_word
        pos = @point
        point_to_mark(saved)
        kill_region(@point, pos, append)
      end
    end

    def insert_for_yank(s)
      mark_to_point(@yank_start)
      insert(s)
    end

    def yank
      insert_for_yank(KILL_RING.current)
    end

    def yank_pop
      delete_region(@yank_start.location, @point)
      insert_for_yank(KILL_RING.current(1))
    end

    def undo
      if @undo_stack.empty?
        raise "No further undo information"
      end
      action = @undo_stack.pop
      @undoing = true
      begin
        was_modified = @modified
        action.undo
        if action.version == @version
          @modified = false
          action.version = nil
        elsif !was_modified
          action.version = @version
        end
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
        was_modified = @modified
        action.redo
        if action.version == @version
          @modified = false
          action.version = nil
        elsif !was_modified
          action.version = @version
        end
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
      m = Regexp.last_match
      if /[\x80-\xbf]/n =~ @contents[m.end(0)]
        raise "Search failed"
      end
      goto_char(gap_to_user(m.end(0)))
    end

    def transpose_chars
      if end_of_buffer? || char_after == "\n"
        backward_char
      end
      if beginning_of_buffer?
        raise RangeError, "Beginning of buffer"
      end
      backward_char
      c = char_after
      delete_char
      forward_char
      insert(c)
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
        raise RangeError, "Position is in gap"
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

    def push_undo(action)
      return if @undoing
      if @undo_stack.size >= UNDO_LIMIT
        @undo_stack[0, @undo_stack.size + 1 - UNDO_LIMIT] = []
      end
      if !modified?
        action.version = @version
      end
      @undo_stack.push(action)
      @redo_stack.clear
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
      @current = -1
    end

    def push(str)
      @current += 1
      if @ring.size < @max
        @ring.insert(@current, str)
      else
        if @current == @max
          @current = 0
        end
        @ring[@current] = str
      end
    end

    def current(n = 0)
      if @ring.empty?
        raise "Kill ring is empty"
      end
      @current -= n
      if @current < 0
        @current += @ring.size
      end
      @ring[@current]
    end

    def empty?
      @ring.empty?
    end
  end

  KILL_RING = KillRing.new

  class UndoableAction
    attr_accessor :version

    def initialize(buffer, location)
      @version = nil
      @buffer = buffer
      @location = location
    end
  end

  class InsertAction < UndoableAction
    def initialize(buffer, location, string)
      super(buffer, location)
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

  class DeleteAction < UndoableAction
    def initialize(buffer, location, insert_location, string)
      super(buffer, location)
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
