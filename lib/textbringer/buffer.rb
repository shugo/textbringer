# frozen_string_literal: true

require "nkf"
require "unicode/display_width"

module Textbringer
  class Buffer
    extend Enumerable

    attr_accessor :file_name, :keymap
    attr_reader :name, :file_encoding, :file_format, :point, :marks
    attr_reader :current_line, :current_column

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

    DEFAULT_DETECT_ENCODING = ->(s) {
      @@auto_detect_encodings.find { |e|
        s.force_encoding(e)
        s.valid_encoding?
      }
    }

    NKF_DETECT_ENCODING = ->(s) {
      e = NKF.guess(s)
      e == Encoding::US_ASCII ? Encoding::UTF_8 : e
    }

    @@detect_encoding_proc = DEFAULT_DETECT_ENCODING

    @@table = {}
    @@list = []
    @@current = nil
    @@minibuffer = nil

    def self.auto_detect_encodings
      @@auto_detect_encodings
    end

    def self.auto_detect_encodings=(encodings)
      @@auto_detect_encodings = encodings
    end

    def self.detect_encoding_proc
      @@detect_encoding_proc
    end

    def self.detect_encoding_proc=(f)
      @@detect_encoding_proc = f
    end

    def self.add(buffer)
      @@table[buffer.name] = buffer
      @@list.unshift(buffer)
    end

    def self.current
      @@current
    end

    def self.current=(buffer)
      if buffer && buffer.name && @@table.key?(buffer.name)
        @@list.delete(buffer)
        @@list.push(buffer)
      end
      @@current = buffer
    end

    def self.minibuffer
      @@minibuffer ||= Buffer.new(name: "*Minibuffer*")
    end

    def self.last
      if @@list.last == @@current
        @@list[-2]
      else
        @@list.last
      end
    end

    def self.count
      @@table.size
    end

    def self.[](name)
      @@table[name]
    end

    def self.find_or_new(name, **opts)
      @@table[name] ||= new_buffer(name, **opts)
    end

    def self.names
      @@table.keys
    end

    def self.kill_em_all
      @@table.clear
      @@list.clear
      @@current = nil
    end

    def self.find_file(file_name)
      file_name = File.expand_path(file_name)
      buffer = @@table.each_value.find { |buffer|
        buffer.file_name == file_name
      }
      if buffer.nil?
        name = File.basename(file_name)
        begin
          buffer = Buffer.open(file_name, name: new_buffer_name(name))
          add(buffer)
        rescue Errno::ENOENT
          buffer = new_buffer(name, file_name: file_name)
        end
      end
      buffer
    end

    def self.new_buffer(name, **opts)
      buffer = Buffer.new(**opts.merge(name: new_buffer_name(name)))
      add(buffer)
      buffer
    end

    def self.new_buffer_name(name)
      if @@table.key?(name)
        (2..Float::INFINITY).lazy.map { |i|
          "#{name}<#{i}>"
        }.find { |i| !@@table.key?(i) }
      else
        name
      end
    end

    def self.each(&block)
      @@table.each_value(&block)
    end

    def self.display_width(s)
      # ncurses seems to treat ambiguous east asian characters as narrow.
      Unicode::DisplayWidth.of(s, 1)
    end

    # s might not be copied.
    def initialize(s = String.new, name: nil,
                   file_name: nil, file_encoding: Encoding::UTF_8,
                   new_file: true, undo_limit: UNDO_LIMIT)
      case s.encoding
      when Encoding::UTF_8, Encoding::ASCII_8BIT
        @contents = s.frozen? ? s.dup : s
      else
        @contents = s.encode(Encoding::UTF_8)
      end
      @contents.force_encoding(Encoding::ASCII_8BIT)
      @name = name
      @file_name = file_name
      self.file_encoding = file_encoding
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
      @new_file = new_file
      @undo_limit = undo_limit
      @point = 0
      @gap_start = 0
      @gap_end = 0
      @marks = []
      @mark = nil
      @current_line = 1
      @current_column = 1
      @desired_column = nil
      @yank_start = new_mark
      @undo_stack = []
      @redo_stack = []
      @undoing = false
      @version = 0
      @modified = false
      @keymap = nil
      @attributes = {}
      @save_point_level = 0
    end

    def inspect
      "#<Buffer:#{@name || '0x%x' % object_id}>"
    end

    def name=(name)
      if @@table[@name] == self
        @@table.delete(@name)
        @name = Buffer.new_buffer_name(name)
        @@table[@name] = self
      else
        @name = name
      end
    end

    def file_encoding=(enc)
      @file_encoding = enc
      @binary = enc == Encoding::ASCII_8BIT
    end

    def binary?
      @binary
    end

    def file_format=(format)
      case format
      when /\Aunix\z/i
        @file_format = :unix
      when /\Ados\z/i
        @file_format = :dos
      when /\Amac\z/i
        @file_format = :mac
      else
        raise ArgumentError, "Unknown file format: #{format}"
      end
    end

    def kill
      @@table.delete(@name)
      @@list.delete(self)
      if @@current == self
        @@current = nil
      end
    end

    def current?
      @@current == self
    end

    def modified?
      @modified
    end

    def [](name)
      @attributes[name]
    end

    def []=(name, value)
      @attributes[name] = value
    end

    def new_file?
      @new_file
    end

    def self.open(file_name, name: File.basename(file_name))
      s = File.read(file_name)
      enc = @@detect_encoding_proc.call(s) || Encoding::ASCII_8BIT
      s.force_encoding(enc)
      unless s.valid_encoding?
        enc = Encoding::ASCII_8BIT
        s.force_encoding(enc)
      end
      Buffer.new(s, name: name,
                 file_name: file_name, file_encoding: enc,
                 new_file: false)
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
      @new_file = false
    end

    def to_s
      result = (@contents[0...@gap_start] + @contents[@gap_end..-1])
      result.force_encoding(Encoding::UTF_8) unless @binary
      result
    end

    def substring(s, e)
      result =
        if s > @gap_start || e <= @gap_start
          @contents[user_to_gap(s)...user_to_gap(e)]
        else
          len = @gap_start - s
          @contents[user_to_gap(s), len] + @contents[@gap_end, e - s - len]
        end
      result.force_encoding(Encoding::UTF_8) unless @binary
      result
    end

    def byte_after(location = @point)
      if location < @gap_start
        @contents.byteslice(location)
      else
        @contents.byteslice(location + gap_size)
      end
    end

    def char_after(location = @point)
      if @binary
        byte_after(location)
      else
        s = substring(location, location + UTF8_CHAR_LEN[byte_after(location)])
        s.empty? ? nil : s
      end
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

    def get_line_and_column(pos)
      line = 1 + @contents[0...user_to_gap(pos)].count("\n")
      if pos == point_min
        column = 1
      else
        i = @contents.rindex("\n", user_to_gap(pos - 1))
        if i
          i += 1
        else
          i = 0
        end
        column = 1 + substring(gap_to_user(i), pos).size
      end
      [line, column]
    end

    def goto_char(pos)
      if pos < 0 || pos > size
        raise RangeError, "Out of buffer"
      end
      if !@binary && /[\x80-\xbf]/n =~ byte_after(pos)
        raise ArgumentError, "Position is in the middle of a character"
      end
      @desired_column = nil
      if @save_point_level == 0
        @current_line, @current_column = get_line_and_column(pos)
      end
      @point = pos
    end

    def goto_line(n)
      pos = point_min
      i = 1
      while i < n && pos < @contents.bytesize
        pos = @contents.index("\n", pos)
        break if pos.nil?
        i += 1
        pos += 1
      end
      @point = gap_to_user(pos)
      @current_line = i
      @current_column = 1
      @desired_column = nil
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
      update_line_and_column(pos, @point)
      unless @undoing
        if merge_undo && @undo_stack.last.is_a?(InsertAction)
          @undo_stack.last.merge(s)
          @redo_stack.clear
        else
          push_undo(InsertAction.new(self, pos, s))
        end
      end
      @modified = true
      @desired_column = nil
    end

    def newline
      indentation = save_point { |saved|
        if /[ \t]/ =~ char_after
          next ""
        end
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
        # fill the gap with NUL to avoid invalid byte sequence in UTF-8
        @contents[@gap_end...user_to_gap(pos)] = "\0" * (pos - @point)
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
        update_line_and_column(@point, pos)
        # fill the gap with NUL to avoid invalid byte sequence in UTF-8
        @contents[user_to_gap(pos)...@gap_start] = "\0" * (@point - pos)
        @marks.each do |m|
          if m.location >= @point
            m.location -= @point - pos
          end
        end
        @point = @gap_start = pos
        push_undo(DeleteAction.new(self, s, pos, str))
        @modified = true
      end
      @desired_column = nil
    end

    def backward_delete_char(n = 1)
      delete_char(-n)
    end

    def forward_char(n = 1)
      pos = get_pos(@point, n)
      update_line_and_column(@point, pos)
      @point = pos
      @desired_column = nil
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

    def next_line(n = 1)
      if @desired_column
        column = @desired_column
      else
        prev_point = @point
        beginning_of_line
        column = Buffer.display_width(substring(@point, prev_point))
      end
      n.times do
        end_of_line
        forward_char
        s = @point
        while !end_of_buffer? && byte_after != "\n" &&
          Buffer.display_width(substring(s, @point)) < column
          forward_char
        end
      end
      @desired_column = column
    end

    def previous_line(n = 1)
      if @desired_column
        column = @desired_column
      else
        prev_point = @point
        beginning_of_line
        column = Buffer.display_width(substring(@point, prev_point))
      end
      n.times do
        beginning_of_line
        backward_char
        beginning_of_line
        s = @point
        while !end_of_buffer? && byte_after != "\n" &&
          Buffer.display_width(substring(s, @point)) < column
          forward_char
        end
      end
      @desired_column = column
    end

    def beginning_of_buffer
      if @save_point_level == 0
        @current_line = 1
        @current_column = 1
      end
      @point = 0
    end

    def beginning_of_buffer?
      @point == 0
    end

    def end_of_buffer
      goto_char(bytesize)
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

    def new_mark(location = @point)
      Mark.new(self, location).tap { |m|
        @marks << m
      }
    end

    def point_to_mark(mark)
      goto_char(mark.location)
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

    def exchange_point_and_mark(mark = @mark)
      update_line_and_column(@point, mark.location)
      @point, mark.location = mark.location, @point
    end

    def save_point
      saved = new_mark
      column = @desired_column
      @save_point_level += 1
      begin
        yield(saved)
      ensure
        point_to_mark(saved)
        saved.delete
        @desired_column = column
        @save_point_level -= 1
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
      old_pos = @point
      if s > e
        s, e = e, s
      end
      update_line_and_column(old_pos, s)
      save_point do
        str = substring(s, e)
        @point = s
        adjust_gap
        len = e - s
        # fill the gap with NUL to avoid invalid byte sequence in UTF-8
        @contents[@gap_end, len] = "\0" * len
        @gap_end += len
        @marks.each do |m|
          if m.location > e
            m.location -= len
          elsif m.location > s
            m.location = s
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
      re = Regexp.new(s)
      b, e = byteindex(true, re, @point)
      if b.nil?
        raise "Search failed"
      end
      goto_char(gap_to_user(e))
    end

    def byteindex(forward, re, pos)
      method = forward ? :index : :rindex
      adjust_gap(0, bytesize)
      if @binary
        offset = pos
      else
        offset = @contents[0...pos].force_encoding(Encoding::UTF_8).size
        @contents.force_encoding(Encoding::UTF_8)
      end
      begin
        i = @contents.send(method, re, offset)
        if i
          m = Regexp.last_match
          if m.nil?
            # A bug of rindex/
            [i, i]
          else
            b = m.pre_match.bytesize
            e = b + m.to_s.bytesize
            e <= bytesize ? [b, e] : nil
          end
        else
          nil
        end
      ensure
        @contents.force_encoding(Encoding::ASCII_8BIT)
      end
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

    def gap_filled_with_nul?
      /\A\0*\z/ =~ @contents[@gap_start...@gap_end] ? true : false
    end

    private

    def adjust_gap(min_size = 0, pos = @point)
      if @gap_start < pos
        len = user_to_gap(pos) - @gap_end
        @contents[@gap_start, len] = @contents[@gap_end, len]
        @gap_start += len
        @gap_end += len
      elsif @gap_start > pos
        len = @gap_start - pos
        @contents[@gap_end - len, len] = @contents[pos, len]
        @gap_start -= len
        @gap_end -= len
      end
      # fill the gap with NUL to avoid invalid byte sequence in UTF-8
      @contents[@gap_start...@gap_end] = "\0" * (@gap_end - @gap_start)
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
      if @binary
        result = pos + offset
        if result < 0 || result > bytesize
          raise RangeError, "Out of buffer"
        end
        return result
      end
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

    def update_line_and_column(pos, new_pos)
      return if @save_point_level > 0
      if pos < new_pos
        n = @contents[user_to_gap(pos)...user_to_gap(new_pos)].count("\n")
        if n == 0
          @current_column += substring(pos, new_pos).size
        else
          @current_line += n
          i = @contents.rindex("\n", user_to_gap(new_pos - 1))
          if i
            i += 1
          else
            i = 0
          end
          @current_column = 1 + substring(gap_to_user(i), new_pos).size
        end
      elsif pos > new_pos
        n = @contents[user_to_gap(new_pos)...user_to_gap(pos)].count("\n")
        if n == 0
          @current_column -= substring(new_pos, pos).size
        else
          @current_line -= n
          i = @contents.rindex("\n", user_to_gap(new_pos - 1))
          if i
            i += 1
          else
            i = 0
          end
          @current_column = 1 + substring(gap_to_user(i), new_pos).size
        end
      end
    end

    def push_undo(action)
      return if @undoing || @undo_limit == 0
      if @undo_stack.size >= @undo_limit
        @undo_stack[0, @undo_stack.size + 1 - @undo_limit] = []
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

    def clear
      @ring.clear
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
