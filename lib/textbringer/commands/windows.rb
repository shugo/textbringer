# frozen_string_literal: true

module Textbringer
  module Commands
    define_command(:resize_window) do
      Window.resize
    end

    define_command(:recenter) do
      Window.current.recenter
      Window.redraw
    end

    define_command(:scroll_up) do
      Window.current.scroll_up
    end

    define_command(:scroll_down) do
      Window.current.scroll_down
    end

    define_command(:delete_window) do
      Window.delete_window
    end

    define_command(:delete_other_windows) do
      Window.delete_other_windows
    end

    define_command(:split_window) do
      Window.current.split
    end

    define_command(:other_window) do
      Window.other_window
    end

    define_command(:enlarge_window) do |n = number_prefix_arg|
      Window.current.enlarge(n)
    end

    define_command(:shrink_window) do |n = number_prefix_arg|
      Window.current.shrink(n)
    end

    define_command(:switch_to_buffer) do
      |buffer_name = read_buffer("Switch to buffer: ")|
      if buffer_name.is_a?(Buffer)
        buffer = buffer_name
      else
        buffer = Buffer[buffer_name]
      end
      if buffer
        Window.current.buffer = Buffer.current = buffer
      else
        raise EditorError, "No such buffer: #{buffer_name}"
      end
    end

    define_command(:kill_buffer) do
      |name = read_buffer("Kill buffer: ", default: Buffer.current.name)|
      if name.is_a?(Buffer)
        buffer = name
      else
        buffer = Buffer[name]
      end
      if buffer.modified?
        next unless yes_or_no?("The last change is not saved; kill anyway?")
        message("Arioch! Arioch! Blood and souls for my Lord Arioch!")
      end
      buffer.kill
      if Buffer.count == 0
        buffer = Buffer.new_buffer("*scratch*")
        switch_to_buffer(buffer)
      elsif Buffer.current.nil?
        switch_to_buffer(Buffer.last)
      end
    end
  end
end
