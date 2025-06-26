module Textbringer::Commands
  define_command(:copy_rectangle_to_register) do
    if Buffer.current.mark.nil?
      raise EditorError, "The mark is not set"
    end
    s = Buffer.current.point
    e = Buffer.current.mark
    rectangle = Buffer.current.rectangle_region(s, e)
    register = read_char("Register: ")
    REGISTERS[register] = { type: :rectangle, data: rectangle }
  end

  define_command(:kill_rectangle) do
    if Buffer.current.mark.nil?
      raise EditorError, "The mark is not set"
    end
    s = Buffer.current.point
    e = Buffer.current.mark
    rectangle = Buffer.current.rectangle_region(s, e)
    KILL_RING.push(type: :rectangle, data: rectangle)
    Buffer.current.delete_rectangle_region(s, e)
  end

  define_command(:yank_rectangle) do
    item = KILL_RING.current
    unless item[:type] == :rectangle
      raise EditorError, "Not a rectangle in kill ring"
    end
    Buffer.current.insert_rectangle_region(Buffer.current.point, Buffer.current.mark, item[:data])
  end

  define_command(:delete_rectangle) do
    if Buffer.current.mark.nil?
      raise EditorError, "The mark is not set"
    end
    s = Buffer.current.point
    e = Buffer.current.mark
    Buffer.current.delete_rectangle_region(s, e)
  end

  define_command(:open_rectangle) do
    if Buffer.current.mark.nil?
      raise EditorError, "The mark is not set"
    end
    s = Buffer.current.point
    e = Buffer.current.mark
    rectangle = Buffer.current.rectangle_region(s, e).map { |line| " " * line.display_width }
    Buffer.current.insert_rectangle_region(s, e, rectangle)
  end

  define_command(:clear_rectangle) do
    if Buffer.current.mark.nil?
      raise EditorError, "The mark is not set"
    end
    s = Buffer.current.point
    e = Buffer.current.mark
    rectangle = Buffer.current.rectangle_region(s, e).map { |line| " " * line.display_width }
    Buffer.current.delete_rectangle_region(s, e)
    Buffer.current.insert_rectangle_region(s, e, rectangle)
  end

  define_command(:string_rectangle) do
    if Buffer.current.mark.nil?
      raise EditorError, "The mark is not set"
    end
    s = Buffer.current.point
    e = Buffer.current.mark
    str = read_string("String: ")
    rectangle = Buffer.current.rectangle_region(s, e).map { |line| str + line }
    Buffer.current.delete_rectangle_region(s, e)
    Buffer.current.insert_rectangle_region(s, e, rectangle)
  end
end
