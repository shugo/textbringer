# frozen_string_literal: true

module Textbringer
  module Commands
    REGISTERS = {}

    BufferPosition = Struct.new(:buffer, :mark)

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
      position = REGISTERS[register]
      if position
        position.mark.delete
      end
      buffer = Buffer.current
      mark = buffer.new_mark
      position = BufferPosition.new(buffer, mark)
      REGISTERS[register] = position
    end

    define_command(:jump_to_register) do
      |register = read_register("Jump to register:")|
      unless register.is_a?(String)
        raise ArgumentError, "Invalid register: #{register}"
      end
      position = REGISTERS[register]
      if position
        switch_to_buffer(position.buffer)
        position.buffer.point_to_mark(position.mark)
      end
    end
  end
end
