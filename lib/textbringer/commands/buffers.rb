# frozen_string_literal: true

module Textbringer
  module Commands
    define_command(:forward_char,
                   doc: "Move point n characters forward.") do
      |n = number_prefix_arg|
      Buffer.current.forward_char(n)
    end
    
    define_command(:backward_char,
                   doc: "Move point n characters backward.") do
      |n = number_prefix_arg|
      Buffer.current.backward_char(n)
    end

    define_command(:forward_word,
                   doc: "Move point n words forward.") do
      |n = number_prefix_arg|
      Buffer.current.forward_word(n)
    end

    define_command(:backward_word,
                   doc: "Move point n words backward.") do
      |n = number_prefix_arg|
      Buffer.current.backward_word(n)
    end
    

    define_command(:next_line,
                   doc: "Move point n lines forward.") do
      |n = number_prefix_arg|
      Buffer.current.next_line(n)
    end
    
    define_command(:previous_line,
                   doc: "Move point n lines backward.") do
      |n = number_prefix_arg|
      Buffer.current.previous_line(n)
    end
    
    define_command(:delete_char,
                   doc: "Delete n characters forward.") do
      |n = number_prefix_arg|
      Buffer.current.delete_char(n)
    end
    
    define_command(:backward_delete_char,
                   doc: "Delete n characters backward.") do
      |n = number_prefix_arg|
      Buffer.current.backward_delete_char(n)
    end

    define_command(:beginning_of_line,
                   doc: "Move point to the beginning of the current line.") do
      Buffer.current.beginning_of_line
    end

    define_command(:end_of_line,
                   doc: "Move point to the end of the current line.") do
      Buffer.current.end_of_line
    end

    define_command(:beginning_of_buffer,
                   doc: "Move point to the beginning of the buffer.") do
      Buffer.current.beginning_of_buffer
    end

    define_command(:end_of_buffer,
                   doc: "Move point to the end of the buffer.") do
      Buffer.current.end_of_buffer
    end

    define_command(:push_mark,
                   doc: <<~EOD) do
        Set mark at pos, and push the mark on the mark ring.
        Unlike Emacs, the new mark is pushed on the mark ring instead of
        the old one.
      EOD
      |pos = Buffer.current.point|
      Buffer.current.push_mark(pos)
    end

    define_command(:pop_mark,
                   doc: "Pop the mark from the mark ring.") do
      Buffer.current.pop_mark
    end

    define_command(:pop_to_mark,
                   doc: <<~EOD) do
        Move point to where the mark is, and pop the mark from
        the mark ring.
      EOD
      Buffer.current.pop_to_mark
    end

    define_command(:exchange_point_and_mark,
                   doc: "Exchange the positions of point and mark.") do
      Buffer.current.exchange_point_and_mark
    end

    define_command(:copy_region,
                   doc: "Copy the region to the kill ring.") do
      Buffer.current.copy_region
    end

    define_command(:kill_region,
                   doc: "Copy and delete the region.") do
      Buffer.current.kill_region
    end

    define_command(:yank,
                   doc: "Insert the last text copied in the kill ring.") do
      Buffer.current.yank
    end

    define_command(:newline,
                   doc: "Insert a newline.") do
      Buffer.current.newline
    end

    define_command(:delete_region,
                   doc: "Delete the region without copying.") do
      Buffer.current.delete_region
    end

    define_command(:transpose_chars,
                   doc: "Transpose characters.") do
      Buffer.current.transpose_chars
    end

    define_command(:set_mark_command,
                   doc: <<~EOD) do
        Set the mark at point.

        With C-u, move point to where the mark is, and pop the mark from
        the mark ring.
      EOD
      |arg = current_prefix_arg|
      buffer = Buffer.current
      if arg
        buffer.pop_to_mark
      else
        buffer.push_mark
        message("Mark set")
      end
    end

    define_command(:goto_char,
                   doc: "Move point to pos.") do
      |pos = read_from_minibuffer("Go to char: ")|
      Buffer.current.goto_char(pos.to_i)
      Window.current.recenter_if_needed
    end

    define_command(:goto_line,
                   doc: "Move point to line n.") do
      |n = read_from_minibuffer("Go to line: ")|
      Buffer.current.goto_line(n.to_i)
      Window.current.recenter_if_needed
    end

    define_command(:self_insert,
                   doc: "Insert the character typed.") do
      |n = number_prefix_arg|
      c = Controller.current.last_key
      merge_undo = Controller.current.last_command == :self_insert
      Buffer.current.insert(c * n, merge_undo)
    end

    define_command(:quoted_insert,
                   doc: "Read a character, and insert it.") do
      |n = number_prefix_arg|
      c = Controller.current.read_char
      if !c.is_a?(String)
        raise EditorError, "Invalid key"
      end
      Buffer.current.insert(c * n)
    end

    define_command(:kill_line,
                   doc: "Kill the rest of the current line.") do
      Buffer.current.kill_line(Controller.current.last_command == :kill_region)
      Controller.current.this_command = :kill_region
    end

    define_command(:kill_word,
                   doc: "Kill a word.") do
      Buffer.current.kill_word(Controller.current.last_command == :kill_region)
      Controller.current.this_command = :kill_region
    end

    define_command(:yank_pop,
                   doc: <<~EOD) do
        Rotate the kill ring, and replace the yanked text.
      EOD
      if Controller.current.last_command != :yank
        raise EditorError, "Previous command was not a yank"
      end
      Buffer.current.yank_pop
      Controller.current.this_command = :yank
    end

    define_command(:undo,
                   doc: "Undo changes.") do
      Buffer.current.undo
      message("Undo!") unless Window.echo_area.current?
    end

    define_command(:redo_command,
                   doc: "Redo changes reverted by undo.") do
      Buffer.current.redo
      message("Redo!") unless Window.echo_area.current?
    end

    define_command(:back_to_indentation,
                   doc: "Move point to the first non-space character.") do
      buffer = Buffer.current
      buffer.beginning_of_line
      while /[ \t]/ =~ buffer.char_after
        buffer.forward_char
      end
    end

    define_command(:delete_indentation,
                   doc: <<~EOD) do
        Delete indentation and join the current line to the previous line.
      EOD
      buffer = Buffer.current
      back_to_indentation
      pos = buffer.point
      buffer.skip_re_backward(/[^\n]/)
      return if buffer.beginning_of_buffer?
      buffer.backward_char
      buffer.skip_re_backward(/[ \t]/)
      buffer.delete_region(buffer.point, pos)
      buffer.insert(" ")
      buffer.backward_char
    end
  end
end
