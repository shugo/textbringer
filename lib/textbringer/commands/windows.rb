module Textbringer
  module Commands
    define_command(:resize_window,
                   doc: "Resize windows to fit the terminal size.") do
      Window.resize
    end

    define_command(:recenter,
                   doc: "Center point in the current window.") do
      Window.current.recenter
      Window.redraw
    end

    define_command(:scroll_up,
                   doc: "Scroll text of the current window upward.") do
      Window.current.scroll_up
    end

    define_command(:scroll_down,
                   doc: "Scroll text of the current window downward.") do
      Window.current.scroll_down
    end

    define_command(:delete_window,
                   doc: "Delete the current window.") do
      Window.delete_window
    end

    define_command(:delete_other_windows,
                   doc: "Delete windows other than the current one.") do
      Window.delete_other_windows
    end

    define_command(:split_window,
                   doc: "Split the current window vertically.") do
      Window.current.split
    end

    define_command(:other_window,
                   doc: "Switch to another window.") do
      Window.other_window
    end

    define_command(:enlarge_window, doc: <<~EOD) do
        Make the current window n lines taller.

        If n is negative, shrink the window -n lines.
        See [shrink_window] for details.
      EOD
      |n = number_prefix_arg|
      Window.current.enlarge(n)
    end

    define_command(:shrink_window, doc: <<~EOD) do |n = number_prefix_arg|
        Make the current window n lines smaller.

        If n is negative, enlarge the window -n lines.
        See [enlarge_window] for details.
      EOD
      Window.current.shrink(n)
    end

    define_command(:shrink_window_if_larger_than_buffer, doc: <<~EOD) do
        Shrink the current window if it's larger than the buffer.
      EOD
      Window.current.shrink_if_larger_than_buffer
    end

    define_command(:switch_to_buffer, doc: <<~EOD) do
        Display buffer in the current window.
      EOD
      |buffer = read_buffer("Switch to buffer: "), arg = current_prefix_arg|
      if buffer.is_a?(String)
        if arg
          buffer = Buffer.find_or_new(buffer)
        else
          buffer = Buffer[buffer]
        end
      end
      if buffer
        Window.current.buffer = Buffer.current = buffer
      else
        raise EditorError, "No such buffer: #{buffer}"
      end
    end

    define_command(:list_buffers, doc: <<~EOD) do
        List the existing buffers.
      EOD
      buffer = Buffer.find_or_new("*Buffer List*",
                                  undo_limit: 0, read_only: true)
      buffer.apply_mode(BufferListMode)
      buffer.read_only_edit do
        buffer.clear
        buffer.insert(Buffer.list.map(&:name).join("\n"))
        buffer.beginning_of_buffer
      end
      switch_to_buffer(buffer)
    end

    define_command(:bury_buffer, doc: <<~EOD) do
        Put buffer at the end of the buffer list.
      EOD
      |buffer = Buffer.current|
      if buffer.is_a?(String)
        buffer = Buffer[buffer]
      end
      Buffer.bury(buffer)
      Window.current.buffer = Buffer.current
    end

    define_command(:unbury_buffer, doc: <<~EOD) do
        Switch to the last buffer in the buffer list.
      EOD
      switch_to_buffer(Buffer.last)
    end

    define_command(:kill_buffer, doc: "Kill buffer.") do
      |buffer = read_buffer("Kill buffer: ", default: Buffer.current.name),
        force: false|
      if buffer.is_a?(String)
        buffer = Buffer[buffer]
      end
      if !force && buffer.modified?
        next unless yes_or_no?("The last change is not saved; kill anyway?")
        message("Arioch! Arioch! Blood and souls for my Lord Arioch!")
      end
      buffer.kill
      if Buffer.current.nil?
        switch_to_buffer(Buffer.other)
      end
      Window.list(include_echo_area: true).each do |window|
        if window.buffer == buffer
          window.buffer = Buffer.current
        end
      end
    end
  end
end
