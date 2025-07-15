# frozen_string_literal: true

require "open3"

module Textbringer
  module Commands
    class Ispell
      def initialize
        @personal_dictionary_modified = false
        @stdin, @stdout, @stderr, @wait_thr =
          Open3.popen3("aspell -a")
        @stdout.gets # consume the banner
      end

      def check_word(word)
        send_command("^" + word)
        result = @stdout.readpartial(4096)
        case result
        when /\A&\s+([^\s]+)\s+\d+\s+\d+:\s+(.*)/
          [$1, $2.split(/, /)]
        when /\A\*/, /\A\+/, /\A\-/, /\A\%/
          [word, []]
        when /\A#/
          [word, nil]
        else
          raise "unexpected output from aspell: #{result}"
        end
      end

      def add_to_session_dictionary(word)
        send_command("@" + word)
      end

      def add_to_personal_dictionary(word)
        send_command("*" + word)
        @personal_dictionary_modified = true
      end

      def personal_dictionary_modified?
        @personal_dictionary_modified
      end

      def save_personal_dictionary
        send_command("#")
      end

      def send_command(line)
        @stdin.puts(line)
        @stdin.flush
      end

      def close
        @stdin.close
        @stdout.close
        @stderr.close
      end
    end

    define_keymap :ISPELL_MODE_MAP
    (?\x20..?\x7e).each do |c|
      ISPELL_MODE_MAP.define_key(c, :ispell_unknown_command)
    end
    ISPELL_MODE_MAP.define_key(?\t, :ispell_unknown_command)
    ISPELL_MODE_MAP.handle_undefined_key do |key|
      ispell_unknown_command
    end
    ISPELL_MODE_MAP.define_key(?r, :ispell_replace)
    ISPELL_MODE_MAP.define_key(?a, :ispell_accept)
    ISPELL_MODE_MAP.define_key(?i, :ispell_insert)
    ISPELL_MODE_MAP.define_key(" ", :ispell_skip)
    ISPELL_MODE_MAP.define_key(?q, :ispell_quit)

    ISPELL_STATUS = {}

    ISPELL_WORD_REGEXP = /[A-Za-z]+/

    define_command(:ispell_word) do
      buffer = Buffer.current
      word = buffer.save_excursion {
        while !buffer.beginning_of_buffer? && buffer.char_after =~ /[A-Za-z]/
          buffer.backward_char
        end
        buffer.re_search_forward(/[A-Za-z]+/, raise_error: false) &&
          buffer.match_string(0)
      }
      if word.nil?
        message("No word at point.")
        return
      end
      start_pos = buffer.match_beginning(0)
      end_pos = buffer.match_end(0)
      ispell = Ispell.new
      begin
        _original, suggestions = ispell.check_word(word)
        if suggestions.nil? || suggestions.empty?
          message("#{word.inspect} is spelled correctly.")
        else
          s = read_from_minibuffer("Correct #{word} with: ",
                                   completion_proc: ->(s) {
                                     suggestions.grep(/^#{Regexp.quote(s)}/)
                                   })
          if s
            buffer.composite_edit do
              buffer.delete_region(start_pos, end_pos)
              buffer.insert(s)
            end
          end
        end
      ensure
        ispell.close
      end
    end

    define_command(:ispell_buffer) do |recursive_edit: false|
      Buffer.current.beginning_of_buffer
      ispell_mode
      ispell_forward
      ISPELL_STATUS[:recursive_edit] = recursive_edit
      if recursive_edit
        recursive_edit()
      end
    end

    def ispell_done
      Buffer.current.delete_visible_mark
      Controller.current.overriding_map = nil
      ISPELL_STATUS[:ispell]&.close
      ISPELL_STATUS[:ispell] = nil
      if ISPELL_STATUS[:recursive_edit]
        exit_recursive_edit
      end
    end

    def ispell_mode
      ISPELL_STATUS[:ispell] = Ispell.new
      Controller.current.overriding_map = ISPELL_MODE_MAP
    end

    def ispell_forward
      buffer = Buffer.current
      while buffer.re_search_forward(ISPELL_WORD_REGEXP, raise_error: false,
                                     goto_beginning: true)
        ispell_beginning = buffer.point
        buffer.set_visible_mark
        buffer.goto_char(buffer.match_end(0))
        word = buffer.match_string(0)
        _original, suggestions = ISPELL_STATUS[:ispell].check_word(word)
        if !suggestions.nil? && !suggestions.empty?
          ISPELL_STATUS[:beginning] = ispell_beginning
          ISPELL_STATUS[:word] = word
          ISPELL_STATUS[:suggestions] = suggestions
          message("Mispelled: #{word}  [r]eplace, [a]ccept, [i]nsert, [SPC] to skip, [q]uit")
          recenter
          return
        end
      end
      Controller.current.overriding_map = nil
      if ISPELL_STATUS[:ispell]&.personal_dictionary_modified? &&
          y_or_n?("Personal dictionary modified.  Save?")
        ISPELL_STATUS[:ispell].save_personal_dictionary
      end
      message("Finished spelling check.")
      ispell_done
    end

    define_command(:ispell_replace) do
      word = ISPELL_STATUS[:word]
      suggestions = ISPELL_STATUS[:suggestions]
      Controller.current.overriding_map = nil
      s = read_from_minibuffer("Correct #{word} with: ",
                               completion_proc: ->(s) {
        suggestions.grep(/^#{Regexp.quote(s)}/)
      })
      Controller.current.overriding_map = ISPELL_MODE_MAP
      if !s.empty?
        buffer = Buffer.current
        pos = buffer.point
        buffer.goto_char(ISPELL_STATUS[:beginning])
        buffer.composite_edit do
          buffer.delete_region(buffer.point, pos)
          buffer.insert(s)
        end
      end
      ispell_forward
    end

    define_command(:ispell_accept) do
      ISPELL_STATUS[:ispell].add_to_session_dictionary(ISPELL_STATUS[:word])
      ispell_forward
    end

    define_command(:ispell_insert) do
      ISPELL_STATUS[:ispell].add_to_personal_dictionary(ISPELL_STATUS[:word])
      ispell_forward
    end

    define_command(:ispell_skip) do
      ISPELL_STATUS[:ispell].add_to_personal_dictionary(ISPELL_STATUS[:word])
      ispell_forward
    end

    define_command(:ispell_quit) do
      message("Quitting spell check.")
      ispell_done
    end

    define_command(:ispell_unknown_command) do
      word = ISPELL_STATUS[:word]
      message("Mispelled: #{word}  [r]eplace, [a]ccept, [i]nsert, [SPC] to skip, [q]uit")
      Window.beep
    end
  end
end
