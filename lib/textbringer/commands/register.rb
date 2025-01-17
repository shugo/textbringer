module Textbringer
  module Commands
    class BufferPosition
      attr_reader :buffer, :mark

      def initialize(buffer, mark)
        @buffer = buffer
        @mark = mark
      end

      def to_s
        @mark.location.to_s
      end
    end

    REGISTERS = {}

    def REGISTERS.[]=(name, val)
      old_val = REGISTERS[name]
      if old_val.is_a?(BufferPosition)
        old_val.mark.delete
      end
      super(name, val)
    end

    def read_register(prompt)
      Window.echo_area.show(prompt)
      Window.redisplay
      begin
        register = read_char
        register
      ensure
        Window.echo_area.clear
        Window.redisplay
      end
    end

    define_command(:point_to_register) do
      |register = read_register("Point to register:")|
      unless register.is_a?(String)
        raise ArgumentError, "Invalid register: #{register}"
      end
      buffer = Buffer.current
      mark = buffer.new_mark
      REGISTERS[register] = BufferPosition.new(buffer, mark)
    end

    define_command(:jump_to_register) do
      |register = read_register("Jump to register:")|
      if !register.is_a?(String)
        raise ArgumentError, "Invalid register: #{register}"
      end
      position = REGISTERS[register]
      if !position.is_a?(BufferPosition)
        raise ArgumentError, "Register doesn't contain a buffer position"
      end
      switch_to_buffer(position.buffer)
      position.buffer.point_to_mark(position.mark)
    end

    define_command(:copy_to_register) do
      |register = read_register("Copy to register:"),
        s = Buffer.current.mark, e = Buffer.current.point,
        delete_flag = current_prefix_arg|
      buffer = Buffer.current
      str = s <= e ? buffer.substring(s, e) : buffer.substring(e, s)
      REGISTERS[register] = str
      if delete_flag
        buffer.delete_region(s, e)
      end
    end

    define_command(:append_to_register) do
      |register = read_register("Append to register:"),
        s = Buffer.current.mark, e = Buffer.current.point,
        delete_flag = current_prefix_arg|
      buffer = Buffer.current
      str = s <= e ? buffer.substring(s, e) : buffer.substring(e, s)
      val = REGISTERS[register]
      if !val.is_a?(String)
        raise ArgumentError, "Register doesn't contain text"
      end
      REGISTERS[register] = val + str
      if delete_flag
        buffer.delete_region(s, e)
      end
    end

    define_command(:insert_register) do
      |register = read_register("Insert register:"),
        arg = nil|
      if arg.nil? && Controller.current.this_command == :insert_register
        arg = !current_prefix_arg
      end
      buffer = Buffer.current
      str = REGISTERS[register]
      if arg
        buffer.push_mark
      end
      pos = buffer.point
      insert(str)
      if !arg
        buffer.push_mark
        buffer.goto_char(pos)
      end
    end

    define_command(:number_to_register) do
      |n = number_prefix_arg,
        register = read_register("Number to register:")|
      REGISTERS[register] = n
    end

    define_command(:increment_register) do
      |n = current_prefix_arg,
        register = read_register("Increment register:")|
      i = REGISTERS[register]
      case i
      when Integer
        REGISTERS[register] = i + prefix_numeric_value(n)
      when String
        append_to_register(register,
                           Buffer.current.mark, Buffer.current.point, n)
      else
        raise ArgumentError, "Register doesn't contain a number or text"
      end
    end
  end
end
