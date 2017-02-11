# frozen_string_literal: true

module Textbringer
  module Commands
    [
      :forward_char,
      :backward_char,
      :forward_word,
      :backward_word,
      :next_line,
      :previous_line,
      :delete_char,
      :backward_delete_char,
    ].each do |name|
      define_command(name) do |n = number_prefix_arg|
        Buffer.current.send(name, n)
      end
    end

    [
      :beginning_of_line,
      :end_of_line,
      :beginning_of_buffer,
      :end_of_buffer,
      :exchange_point_and_mark,
      :copy_region,
      :kill_region,
      :yank,
      :newline,
      :delete_region,
      :transpose_chars
    ].each do |name|
      define_command(name) do
        Buffer.current.send(name)
      end
    end

    define_command(:set_mark_command) do
      Buffer.current.set_mark
      message("Mark set")
    end

    define_command(:goto_char) do
      |n = read_from_minibuffer("Go to char: ")|
      Buffer.current.goto_char(n.to_i)
      Window.current.recenter_if_needed
    end

    define_command(:goto_line) do
      |n = read_from_minibuffer("Go to line: ")|
      Buffer.current.goto_line(n.to_i)
      Window.current.recenter_if_needed
    end

    define_command(:self_insert) do |n = number_prefix_arg|
      c = Controller.current.last_key
      merge_undo = Controller.current.last_command == :self_insert
      n.times do
        Buffer.current.insert(c, merge_undo)
      end
    end

    define_command(:quoted_insert) do |n = number_prefix_arg|
      c = Controller.current.read_char
      if !c.is_a?(String)
        raise EditorError, "Invalid key"
      end
      n.times do
        Buffer.current.insert(c)
      end
    end

    define_command(:kill_line) do
      Buffer.current.kill_line(Controller.current.last_command == :kill_region)
      Controller.current.this_command = :kill_region
    end

    define_command(:kill_word) do
      Buffer.current.kill_word(Controller.current.last_command == :kill_region)
      Controller.current.this_command = :kill_region
    end

    define_command(:yank_pop) do
      if Controller.current.last_command != :yank
        raise EditorError, "Previous command was not a yank"
      end
      Buffer.current.yank_pop
      Controller.current.this_command = :yank
    end

    define_command(:undo) do
      Buffer.current.undo
      message("Undo!") unless Window.echo_area.current?
    end

    define_command(:redo) do
      Buffer.current.redo
      message("Redo!") unless Window.echo_area.current?
    end
  end
end
