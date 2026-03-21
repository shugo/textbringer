module Textbringer
  class Mode
    extend Commands
    include Commands

    @@mode_list = []

    DEFAULT_SYNTAX_TABLE = {
      control: /\p{C}+/
    }

    def self.list
      @@mode_list
    end

    class << self
      attr_accessor :mode_name
      attr_accessor :command_name
      attr_accessor :hook_name
      attr_accessor :file_name_pattern
      attr_accessor :interpreter_name_pattern
      attr_reader :syntax_table
    end

    def self.define_generic_command(name, **options)
      command_name = (name.to_s + "_command").intern
      define_command(command_name,
                     source_location_proc: -> { Buffer.current.mode.method(name).source_location rescue nil },
                     **options) do |*args|
        begin
          Buffer.current.mode.send(name, *args)
        rescue NoMethodError => e
          if (e.receiver rescue nil) == Buffer.current.mode && e.name == name
            raise EditorError,
              "#{command_name} is not supported in the current mode"
          else
            raise
          end
        end
      end
    end

    def self.define_local_command(name, **options, &block)
      define_generic_command(name, **options)
      define_method(name, &block)
      name
    end

    def self.define_syntax(face_name, re)
      @syntax_table[face_name] = re
    end

    def self.inherited(child)
      base_name = child.name.slice(/[^:]*\z/)
      child.mode_name = base_name.sub(/Mode\z/, "")
      command_name = base_name.sub(/\A[A-Z]/) { |s| s.downcase }.
        gsub(/(?<=[a-z])([A-Z])/) {
          "_" + $1.downcase
        }
      command = command_name.intern
      hook = (command_name + "_hook").intern
      child.command_name = command
      child.hook_name = hook
      define_command(command) do
        Buffer.current.apply_mode(child)
      end
      @@mode_list.push(child)
      child.instance_variable_set(:@syntax_table, DEFAULT_SYNTAX_TABLE.dup)
    end

    attr_reader :buffer

    def initialize(buffer)
      @buffer = buffer
    end

    def name
      self.class.mode_name
    end

    def syntax_table
      self.class.syntax_table
    end

    def highlight(ctx)
      syntax_table = self.class.syntax_table || DEFAULT_SYNTAX_TABLE
      if ctx.buffer.bytesize < CONFIG[:highlight_buffer_size_limit]
        base_pos = ctx.buffer.point_min
        s = ctx.buffer.to_s
      else
        base_pos = ctx.highlight_start
        s = ctx.buffer.substring(ctx.highlight_start,
              ctx.highlight_end).scrub("")
      end
      return if !s.valid_encoding?
      re_str = syntax_table.map { |name, re|
        "(?<#{name}>#{re})"
      }.join("|")
      re = Regexp.new(re_str)
      names = syntax_table.keys
      s.scan(re) do
        b = base_pos + $`.bytesize
        e = b + $&.bytesize
        name = names.find { |n| $~[n] }
        face = Face[name]
        ctx.highlight(b, e, face) if face
      end
    end
  end
end
