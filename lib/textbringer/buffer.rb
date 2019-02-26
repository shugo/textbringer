# frozen_string_literal: true

require "nkf"
require "unicode/display_width"
require "json"
require "fileutils"
require "editorconfig"

module Textbringer
  class Buffer
    extend Enumerable

    attr_accessor :mode, :keymap
    attr_reader :name, :file_name, :file_encoding, :file_format, :point, :marks
    attr_reader :current_line, :current_column, :visible_mark

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
      case e
      when Encoding::US_ASCII
        Encoding::UTF_8
      when Encoding::ASCII_8BIT
        s.force_encoding(Encoding::UTF_8)
        if s.valid_encoding?
          Encoding::UTF_8
        else
          s.force_encoding(Encoding::ASCII_8BIT)
          Encoding::ASCII_8BIT
        end
      else
        e
      end
    }

    if !defined?(@@detect_encoding_proc)
      @@detect_encoding_proc = DEFAULT_DETECT_ENCODING

      @@table = {}
      @@list = []
      @@current = nil
      @@minibuffer = nil
      @@global_mark_ring = nil
    end

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

    def self.list
      @@list.dup
    end

    def self.add(buffer)
      @@table[buffer.name] = buffer
      @@list.push(buffer)
    end

    def self.current
      @@current
    end

    def self.current=(buffer)
      if buffer && buffer.name && @@table.key?(buffer.name)
        @@list.delete(buffer)
        @@list.unshift(buffer)
      end
      @@current = buffer
    end

    def self.minibuffer
      @@minibuffer ||= Buffer.new(name: "*Minibuffer*")
    end

    def self.global_mark_ring
      @@global_mark_ring ||= Ring.new(CONFIG[:global_mark_ring_max])
    end

    def self.other(buffer = @@current)
      @@list.find { |buf|  buf != buffer } || Buffer.find_or_new("*scratch*")
    end

    def self.last
      @@list.last
    end

    def self.bury(buffer = @@current)
      @@list.delete(buffer)
      @@list.push(buffer)
      @@current = @@list.first
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
      buffer = @@table.each_value.find { |b|
        b.file_name == file_name
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
      @@list.each(&block)
    end

    def self.display_width(s)
      Unicode::DisplayWidth.of(s, CONFIG[:east_asian_ambiguous_width])
    end

    def expand_tab(s)
      # TODO: Support multibyte characters
      tw = self[:tab_width]
      fmt = "A#{tw}"
      s.b.gsub(/([^\t]{#{tw}})|([^\t]*)\t/n) {
        [$+].pack(fmt)
      }.force_encoding(Encoding::UTF_8)
    end

    def display_width(s)
      Buffer.display_width(expand_tab(s))
    end

    # s might not be copied.
    def initialize(s = +"", name: nil,
                   file_name: nil,
                   file_encoding: CONFIG[:default_file_encoding],
                   file_mtime: nil, new_file: true, undo_limit: UNDO_LIMIT,
                   read_only: false)
      set_contents(s, file_encoding)
      @name = name
      @file_name = file_name
      self.file_encoding = file_encoding
      @file_mtime = file_mtime
      @new_file = new_file
      @undo_limit = undo_limit
      @point = 0
      @gap_start = 0
      @gap_end = 0
      @marks = []
      @mark = nil
      @mark_ring = Ring.new(CONFIG[:mark_ring_max],
                            on_delete: ->(mark) { mark.delete })
      @current_line = 1
      @current_column = 1  # One-based character count
      @goal_column = nil   # Zero-based display width count
      @undo_stack = []
      @redo_stack = []
      @undoing = false
      @composite_edit_level = 0
      @composite_edit_actions = []
      @version = 0
      @modified = false
      @mode = FundamentalMode.new(self)
      @keymap = nil
      @attributes = {}
      @save_point_level = 0
      @match_offsets = []
      @visible_mark = nil
      @read_only = read_only
      @callbacks = {}
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

    def file_name=(file_name)
      @file_name = file_name
      basename = File.basename(file_name)
      if /\A#{Regexp.quote(basename)}(<\d+>)?\z/ !~ name
        self.name = basename
      end
    end

    def file_encoding=(enc)
      @file_encoding = Encoding.find(enc)
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

    def read_only?
      @read_only
    end

    def read_only=(value)
      @read_only = value
      if @read_only
        @modified = false
      end
    end

    def read_only_edit
      self.read_only = false
      begin
        yield
      ensure
        self.read_only = true
      end
    end

    def kill
      @@table.delete(@name)
      @@list.delete(self)
      if @@current == self
        @@current = nil
      end
      @marks.each do |mark|
        mark.detach
      end
      fire_callbacks(:killed)
    end

    def on_killed(&callback)
      add_callback(:killed, callback)
    end

    def current?
      @@current == self
    end

    def on(name, &callback)
      @callbacks[name] ||= []
      @callbacks[name].push(callback)
    end

    def modified=(modified)
      @modified = modified
      if @composite_edit_level == 0 && modified
        fire_callbacks(:modified)
      end
    end

    def modified?
      @modified
    end

    def on_modified(&callback)
      add_callback(:modified, callback)
    end

    def [](name)
      if @attributes.key?(name)
        @attributes[name]
      else
        CONFIG[name]
      end
    end

    def []=(name, value)
      @attributes[name] = value
    end

    def new_file?
      @new_file
    end

    def self.open(file_name, name: File.basename(file_name))
      buffer = Buffer.new(name: name,
                          file_name: file_name, new_file: false)
      buffer.revert
      buffer.read_only = !File.writable?(file_name)
      buffer
    end

    def revert(enc = nil)
      if @file_name.nil?
        raise EditorError, "Buffer has no file name"
      end
      clear
      s, mtime = File.open(@file_name,
                           external_encoding: Encoding::ASCII_8BIT,
                           binmode: true) { |f|
        f.flock(File::LOCK_SH)
        [f.read, f.mtime]
      }
      enc ||= @@detect_encoding_proc.call(s) || Encoding::ASCII_8BIT
      s.force_encoding(enc)
      unless s.valid_encoding?
        enc = Encoding::ASCII_8BIT
        s.force_encoding(enc)
      end
      set_contents(s, enc)
      @file_mtime = mtime
      @modified = false
    end

    def save(file_name = @file_name)
      if file_name.nil?
        raise EditorError, "File name is not set"
      end
      file_name = File.expand_path(file_name)
      config = EditorConfig.load_file(file_name)
      if config["trim_trailing_whitespace"]
        trim_trailing_whitespace
      end
      if config["insert_final_newline"]
        insert_final_newline
      end
      begin
        File.open(file_name, "w",
                  external_encoding: @file_encoding, binmode: true) do |f|
          f.flock(File::LOCK_EX)
          write_to_file(f)
          f.flush
        end
        @file_mtime = File.mtime(file_name)
      rescue Errno::EISDIR
        if @name
          file_name = File.expand_path(@name, file_name)
          retry
        else
          raise
        end
      end
      if file_name != @file_name
        self.file_name = file_name
      end
      @version += 1
      @modified = false
      @new_file = false
      @read_only = false
    end

    def file_modified?
      !@file_mtime.nil? && File.mtime(@file_name) != @file_mtime
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

    def byte_before(location = @point)
      if location <= point_min || location > point_max
        nil
      else
        byte_after(location - 1)
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

    def char_before(location = @point)
      if @binary
        byte_before(location)
      else
        if beginning_of_buffer?
          nil
        else
          pos = get_pos(location, -1)
          substring(pos, location)
        end
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
      if !@binary && /[\x80-\xbf]/n.match?(byte_after(pos))
        raise ArgumentError, "Position is in the middle of a character"
      end
      @goal_column = nil
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
      @goal_column = nil
    end

    def insert(x, merge_undo = false)
      s = x.to_s
      check_read_only_flag
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
      self.modified = true
      @goal_column = nil
      self
    end

    def newline
      indentation = save_point { |saved|
        if /[ \t]/.match?(char_after)
          next ""
        end
        beginning_of_line
        s = @point
        while /[ \t]/.match?(char_after)
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
      check_read_only_flag
      adjust_gap
      s = @point
      pos = get_pos(@point, n)
      if n > 0
        str = substring(s, pos)
        # fill the gap with NUL to avoid invalid byte sequence in UTF-8
        @contents[@gap_end...user_to_gap(pos)] = "\0" * (pos - @point)
        @gap_end += pos - @point
        @marks.each do |m|
          if m.location > pos
            m.location -= pos - @point
          elsif m.location > @point
            m.location = @point
          end
        end
        push_undo(DeleteAction.new(self, s, s, str))
        self.modified = true
      elsif n < 0
        str = substring(pos, s)
        update_line_and_column(@point, pos)
        # fill the gap with NUL to avoid invalid byte sequence in UTF-8
        @contents[user_to_gap(pos)...@gap_start] = "\0" * (@point - pos)
        @marks.each do |m|
          if m.location >= @point
            m.location -= @point - pos
          elsif m.location > pos
            m.location = pos
          end
        end
        @point = @gap_start = pos
        push_undo(DeleteAction.new(self, s, pos, str))
        self.modified = true
      end
      @goal_column = nil
    end

    def backward_delete_char(n = 1)
      delete_char(-n)
    end

    def forward_char(n = 1)
      pos = get_pos(@point, n)
      update_line_and_column(@point, pos)
      @point = pos
      @goal_column = nil
    end

    def backward_char(n = 1)
      forward_char(-n)
    end

    def forward_word(n = 1, regexp: /\p{Letter}|\p{Number}/)
      n.times do
        while !end_of_buffer? && regexp !~ char_after
          forward_char
        end
        while !end_of_buffer? && regexp =~ char_after
          forward_char
        end
      end
    end

    def backward_word(n = 1, regexp: /\p{Letter}|\p{Number}/)
      n.times do
        break if beginning_of_buffer?
        backward_char
        while !beginning_of_buffer? && regexp !~ char_after
          backward_char
        end
        while !beginning_of_buffer? && regexp =~ char_after
          backward_char
        end
        if regexp !~ char_after
          forward_char
        end
      end
    end

    def forward_line(n = 1)
      if n > 0
        n.times do
          end_of_line
          break if end_of_buffer?
          forward_char
        end
      elsif n < 0
        (-n).times do
          beginning_of_line
          break if beginning_of_buffer?
          backward_char
          beginning_of_line
        end
      end
    end

    def backward_line(n = 1)
      forward_line(-n)
    end

    def next_line(n = 1)
      column = get_goal_column
      n.times do
        end_of_line
        forward_char
        adjust_column(column)
      end
      @goal_column = column
    end

    def previous_line(n = 1)
      column = get_goal_column
      n.times do
        beginning_of_line
        backward_char
        beginning_of_line
        adjust_column(column)
      end
      @goal_column = column
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
      while !beginning_of_line?
        backward_char
      end
      @point
    end

    def beginning_of_line?
      beginning_of_buffer? || byte_before == "\n"
    end

    def end_of_line
      while !end_of_line?
        forward_char
      end
      @point
    end

    def end_of_line?
      end_of_buffer? || byte_after == "\n"
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
      if mark.nil?
        raise EditorError, "The mark is not set"
      end
      update_line_and_column(@point, mark.location)
      @point, mark.location = mark.location, @point
    end

    # The buffer should not be modified in the given block
    # because current_line/current_column is not updated in save_point.
    def save_point
      saved = new_mark
      column = @goal_column
      @save_point_level += 1
      begin
        yield(saved)
      ensure
        point_to_mark(saved)
        saved.delete
        @goal_column = column
        @save_point_level -= 1
      end
    end

    # Don't save Buffer.current.
    def save_excursion
      old_point = new_mark
      old_mark = @mark&.dup
      old_column = @goal_column
      begin
        yield
      ensure
        point_to_mark(old_point)
        old_point.delete
        if old_mark
          @mark.location = old_mark.location
          old_mark.delete
        end
        @goal_column = old_column
      end
    end

    def mark
      if @mark.nil?
        raise EditorError, "The mark is not set"
      end
      @mark.location
    end

    def set_mark(pos = @point)
      if @mark
        @mark.location = pos
      else
        push_mark(pos)
      end
    end

    # Set mark at pos, and push the mark on the mark ring.
    # Unlike Emacs, the new mark is pushed on the mark ring instead of
    # the old one.
    def push_mark(pos = @point)
      @mark = new_mark
      @mark.location = pos
      @mark_ring.push(@mark)
      if self != Buffer.minibuffer
        global_mark_ring = Buffer.global_mark_ring
        if global_mark_ring.empty? || global_mark_ring.current.buffer != self
          push_global_mark(pos)
        end
      end
    end

    def on_global_mark_ring?
      mark_ring = Buffer.global_mark_ring
      if mark_ring.empty?
        return false
      end
      current = mark_ring.current
      if current&.buffer == self
        return true
      end
      next_mark = mark_ring[-1]
      if next_mark&.buffer ==  self
        return true
      end
      false
    end

    def push_global_mark(pos = @point, force: false)
      if force || !on_global_mark_ring?
        mark = new_mark
        mark.location = pos
        Buffer.global_mark_ring.push(mark)
        true
      else
        false
      end
    end

    def pop_mark
      return if @mark_ring.empty?
      @mark = @mark_ring.rotate(1)
    end

    def pop_to_mark
      goto_char(mark)
      pop_mark
    end

    def set_visible_mark(pos = @point)
      @visible_mark ||= new_mark
      @visible_mark.location = pos
    end

    def delete_visible_mark
      if @visible_mark
        @visible_mark.delete
        @visible_mark = nil
      end
    end

    def self.region_boundaries(s, e)
      if s > e
        [e, s]
      else
        [s, e]
      end
    end

    def copy_region(s = @point, e = mark, append = false)
      s, e = Buffer.region_boundaries(s, e)
      str = substring(s, e)
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
      check_read_only_flag
      old_pos = @point
      s, e = Buffer.region_boundaries(s, e)
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
        self.modified = true
      end
    end

    def replace(str, start: point_min, end: point_max)
      composite_edit do
        delete_region(start, binding.local_variable_get(:end))
        goto_char(start)
        insert(str)
      end
    end

    def clear
      check_read_only_flag
      @contents = +""
      @point = @gap_start = @gap_end = 0
      @marks.each do |m|
        m.location = 0
      end
      @current_line = 1
      @current_column = 1
      @goal_column = nil
      self.modified = true
      @undo_stack.clear
      @redo_stack.clear
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
      if @mark.nil? || !point_at_mark?(@mark)
        push_mark
      end
      insert(s)
    end

    def yank
      insert_for_yank(KILL_RING.current)
    end

    def yank_pop
      delete_region
      insert_for_yank(KILL_RING.rotate(1))
    end

    def undo
      check_read_only_flag
      if @undo_stack.empty?
        raise EditorError, "No further undo information"
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
      check_read_only_flag
      if @redo_stack.empty?
        raise EditorError, "No further redo information"
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

    def re_search_forward(s, raise_error: true, count: 1)
      if count < 0
        return re_search_backward(s, raise_error: raise_error, count: -count)
      end
      re = new_regexp(s)
      pos = @point
      count.times do
        i = byteindex(true, re, pos)
        if i.nil?
          if raise_error
            raise SearchError, "Search failed"
          else
            return nil
          end
        end
        pos = match_end(0)
      end
      goto_char(pos)
    end

    def re_search_backward(s, raise_error: true, count: 1)
      if count < 0
        return re_search_forward(s, raise_error: raise_error, count: -count)
      end
      re = new_regexp(s)
      pos = @point
      count.times do
        p = pos
        begin
          i = byteindex(false, re, p)
          if i.nil?
            if raise_error
              raise SearchError, "Search failed"
            else
              return nil
            end
          end
          p = get_pos(p, -1)
        rescue RangeError
          if raise_error
            raise SearchError, "Search failed"
          else
            return nil
          end
        end while match_end(0) > pos
        pos = match_beginning(0)
      end
      goto_char(pos)
    end

    def looking_at?(re)
      if re.is_a?(Regexp)
        r = /\G#{re}/
      else
        r = "\\G(?:#{re})"
      end
      byteindex(true, r, @point) == @point
    end

    def byteindex(forward, re, pos)
      @match_offsets = []
      method = forward ? :index : :rindex
      adjust_gap(0, point_max)
      s = @contents[0...@gap_start]
      if @binary
        offset = pos
      else
        offset = s.byteslice(0, pos).force_encoding(Encoding::UTF_8).size
        s.force_encoding(Encoding::UTF_8)
      end
      begin
        i = s.send(method, re, offset)
        if i
          m = Regexp.last_match
          if m.nil?
            # A bug of rindex
            @match_offsets.push([pos, pos])
            pos
          else
            b = m.pre_match.bytesize
            e = b + m.to_s.bytesize
            if e <= bytesize
              @match_offsets.push([b, e])
              match_beg = m.begin(0)
              match_str = m.to_s
              (1 .. m.size - 1).each do |j|
                cb, ce = m.offset(j)
                if cb.nil?
                  @match_offsets.push([nil, nil])
                else
                  bb = b + match_str[0, cb - match_beg].bytesize
                  be = b + match_str[0, ce - match_beg].bytesize
                  @match_offsets.push([bb, be])
                end
              end
              b
            else
              nil
            end
          end
        else
          nil
        end
      end
    end

    def match_beginning(n)
      @match_offsets[n]&.first
    end

    def match_end(n)
      @match_offsets[n]&.last
    end

    def match_string(n)
      b, e = @match_offsets[n]
      if b.nil?
        nil
      else
        substring(b, e)
      end
    end

    def replace_match(str)
      new_str = str.gsub(/\\(?:([0-9]+)|(&)|(\\))/) { |s|
        case
        when $1
          match_string($1.to_i)
        when $2
          match_string(0)
        when $3
          "\\"
        end
      }
      b = match_beginning(0)
      e =  match_end(0)
      goto_char(b)
      composite_edit do
        delete_region(b, e)
        insert(new_str)
      end
    end

    def replace_regexp_forward(regexp, to_str)
      result = 0
      rest = substring(point, point_max)
      composite_edit do
        delete_region(point, point_max)
        new_str = rest.gsub(new_regexp(regexp)) {
          result += 1
          m = Regexp.last_match
          to_str.gsub(/\\(?:([0-9]+)|(&)|(\\))/) { |s|
          case
          when $1
            m[$1.to_i]
          when $2
            m.to_s
          when $3
            "\\"
          end
          }
        }
        insert(new_str)
      end
      result
    end

    def transpose_chars
      if end_of_line?
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
      /\A\0*\z/.match?(@contents[@gap_start...@gap_end])
    end

    def composite_edit
      @composite_edit_level += 1
      begin
        yield
      ensure
        @composite_edit_level -= 1
        if @composite_edit_level == 0 && !@composite_edit_actions.empty?
          action = CompositeAction.new(self,
                                       @composite_edit_actions.first.location)
          @composite_edit_actions.each do |i|
            action.add_action(i)
          end
          action.version = @composite_edit_actions.first.version
          push_undo(action)
          @composite_edit_actions.clear
        end
      end
      fire_callbacks(:modified)
    end

    def apply_mode(mode_class)
      @keymap = nil
      @mode = mode_class.new(self)
      Utils.run_hooks(mode_class.hook_name)
    end

    def indent_to(column)
      s = if self[:indent_tabs_mode]
        "\t" * (column / self[:tab_width]) + " " * (column % self[:tab_width])
      else
        " " * column
      end
      insert(s)
    end

    def dump(path)
      File.binwrite(path, to_s)
      metadata = {
        "name" => name,
        "file_name" => file_name,
        "file_encoding" => file_encoding.name,
        "file_format" => file_format.to_s
      }
      File.binwrite(path + ".metadata", metadata.to_json)
    end

    def self.load(path)
      buffer = Buffer.new(File.binread(path))
      metadata = JSON.parse(File.binread(path + ".metadata"))
      buffer.name = metadata["name"]
      buffer.file_name = metadata["file_name"] if metadata["file_name"]
      buffer.file_encoding = Encoding.find(metadata["file_encoding"])
      buffer.file_format = metadata["file_format"].intern
      buffer.modified = true
      buffer
    end

    def self.dump_unsaved_buffers(dir)
      FileUtils.mkdir_p(dir)
      @@list.each do |buffer|
        if /\A\*/ !~ buffer.name && buffer.modified?
          buffer.dump(File.expand_path(buffer.object_id.to_s, dir))
        end
      end
    end

    def self.dumped_buffers_exist?(dir)
      !Dir.glob(File.expand_path("*.metadata", dir)).empty?
    end

    def self.load_dumped_buffers(dir)
      Dir.glob(File.expand_path("*.metadata", dir)).map do |metadata_path|
        path = metadata_path.sub(/\.metadata\z/, "")
        buffer = Buffer.load(path)
        add(buffer)
        File.unlink(metadata_path)
        File.unlink(path)
        buffer
      end
    end

    def current_symbol
      from = save_point { skip_re_backward(@mode.symbol_pattern); @point }
      to = save_point { skip_re_forward(@mode.symbol_pattern); @point }
      from < to ? substring(from, to) : nil
    end

    def skip_re_forward(re)
      while re =~ char_after
        forward_char
      end
    end

    def skip_re_backward(re)
      while re =~ char_before
        backward_char
      end
    end

    def gsub(*args, &block)
      if block
        s = to_s.gsub(*args) { |*params|
          block.binding.eval('->(backref) { $~ = backref }').call($~)
          block.call(*params)
        }
      else
        s = to_s.gsub(*args)
      end

      composite_edit do
        delete_region(point_min, point_max)
        insert(s)
      end
      self
    end

    def trim_trailing_whitespace
      save_excursion do
        beginning_of_buffer
        composite_edit do
          while re_search_forward(/[ \t]+$/, raise_error: false)
            replace_match("")
          end
        end
      end
    end

    def insert_final_newline
      save_excursion do
        end_of_buffer
        if char_before != "\n"
          insert("\n")
        end
      end
    end

    private

    def set_contents(s, enc)
      case s.encoding
      when Encoding::UTF_8, Encoding::ASCII_8BIT
        @contents = s.frozen? ? s.dup : s
      else
        @contents = s.encode(Encoding::UTF_8)
      end
      @contents.force_encoding(Encoding::ASCII_8BIT)
      self.file_encoding = enc
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
        @file_format = CONFIG[:default_file_format]
      end
    end

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

    def get_goal_column
      if @goal_column
        @goal_column
      else
        prev_point = @point
        beginning_of_line
        display_width(substring(@point, prev_point))
      end
    end

    def adjust_column(column)
      s = @point
      w = 0
      while !end_of_line? &&
          (w = display_width(substring(s, @point))) < column
        forward_char
      end
      if w > column
        backward_char
      end
    end

    def write_to_file(f)
      [@contents[0...@gap_start], @contents[@gap_end..-1]].each do |s|
        s.force_encoding(Encoding::UTF_8) unless @binary
        case @file_format
        when :dos
          s.gsub!(/\n/, "\r\n")
        when :mac
          s.gsub!(/\n/, "\r")
        end
        f.write(s)
      end
    end

    def push_undo(action)
      return if @undoing || @undo_limit == 0
      if @composite_edit_level > 0
        @composite_edit_actions.push(action)
      else
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

    def new_regexp(s)
      if s.is_a?(Regexp)
        s
      else
        Regexp.new(s, self[:case_fold_search] ? Regexp::IGNORECASE : 0)
      end
    end

    def check_read_only_flag
      if @read_only
        raise ReadOnlyError, "Buffer is read only: #{self.inspect}"
      end
    end

    def fire_callbacks(name)
      @callbacks[name]&.each do |callback|
        callback.call(self)
      end
    end
  end

  class Mark
    attr_reader :buffer, :file_name
    attr_accessor :location

    def initialize(buffer, location)
      @buffer = buffer
      @file_name = nil
      @location = location
    end

    def inspect
      "#<Mark:#{@buffer&.name || @file_name}:#{@location}>"
    end

    def delete
      if @buffer
        @buffer.marks.delete(self)
      end
    end

    def deleted?
      !@buffer.marks.include?(self)
    end

    def detach
      if @buffer
        @file_name = @buffer.file_name
        @buffer = nil
      end
    end

    def detached?
      @buffer.nil?
    end

    def dup
      mark = @buffer.new_mark
      mark.location = @location
      mark
    end
  end

  KILL_RING = Ring.new

  class UndoableAction
    attr_accessor :version
    attr_reader :location

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
      @buffer.delete_region(@location, @location + @string.bytesize)
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
      @buffer.delete_region(@insert_location,
                            @insert_location + @string.bytesize)
    end
  end

  class CompositeAction < UndoableAction
    def initialize(buffer, location)
      super(buffer, location)
      @actions = []
    end

    def add_action(action)
      @actions.push(action)
    end

    def undo
      @actions.reverse_each do |action|
        action.undo
      end
    end

    def redo
      @actions.each do |action|
        action.redo
      end
    end
  end
end
