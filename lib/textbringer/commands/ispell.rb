# frozen_string_literal: true

require "open3"
require "uri"

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
        result = @stdout.gets
        if result.nil? || result == "\n"
          # aspell can't handle word, which may contain multibyte characters
          return [word, nil]
        end
        @stdout.gets
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
    ISPELL_MODE_MAP.define_key("\C-g", :ispell_quit)

    ISPELL_STATUS = {}

    URI_REGEXP = URI::RFC2396_PARSER.make_regexp(["http", "https", "ftp", "mailto"])
    ISPELL_WORD_REGEXP = /(?<uri>#{URI_REGEXP})|(?<word>[[:alpha:]]+(?:'[[:alpha:]]+)*)/

    define_command(:ispell_buffer) do |recursive_edit: false|
      ISPELL_STATUS[:recursive_edit] = false
      Buffer.current.beginning_of_buffer
      ispell_mode
      if !ispell_forward
        ISPELL_STATUS[:recursive_edit] = recursive_edit
        if recursive_edit
          recursive_edit()
        end
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
      ISPELL_STATUS[:recursive_edit] = false
    end

    def ispell_mode
      ISPELL_STATUS[:ispell] = Ispell.new
      Controller.current.overriding_map = ISPELL_MODE_MAP
    end

    def ispell_forward
      buffer = Buffer.current
      while buffer.re_search_forward(ISPELL_WORD_REGEXP, raise_error: false,
                                     goto_beginning: true)
        if buffer.last_match[:word].nil?
          buffer.goto_char(buffer.match_end(0))
          next
        end
        ispell_beginning = buffer.point
        buffer.set_visible_mark
        buffer.goto_char(buffer.match_end(0))
        word = buffer.match_string(0)
        _original, suggestions = ISPELL_STATUS[:ispell].check_word(word)
        if !suggestions.nil? && !suggestions.empty?
          ISPELL_STATUS[:beginning] = ispell_beginning
          ISPELL_STATUS[:word] = word
          ISPELL_STATUS[:suggestions] = suggestions
          message_misspelled
          recenter
          return false
        end
      end
      Controller.current.overriding_map = nil
      if ISPELL_STATUS[:ispell]&.personal_dictionary_modified? &&
          y_or_n?("Personal dictionary modified.  Save?")
        ISPELL_STATUS[:ispell].save_personal_dictionary
      end
      message("Finished spelling check.")
      ispell_done
      true
    end

    define_command(:ispell_replace) do
      word = ISPELL_STATUS[:word]
      suggestions = ISPELL_STATUS[:suggestions]
      Controller.current.overriding_map = nil
      begin
        s = read_from_minibuffer("Correct #{word} with: ",
                                 completion_proc: ->(s) {
          suggestions.grep(/^#{Regexp.quote(s)}/)
        })
      rescue Quit
        message_misspelled
        return
      ensure
        Controller.current.overriding_map = ISPELL_MODE_MAP
      end
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
      ispell_forward
    end

    define_command(:ispell_quit) do
      message("Quitting spell check.")
      ispell_done
    end

    define_command(:ispell_unknown_command) do
      message_misspelled
      Window.beep
    end

    def message_misspelled
      word = ISPELL_STATUS[:word]
      message("Misspelled: #{word}  [r]eplace, [a]ccept, [i]nsert, [SPC] to skip, [q]uit")
    end
  end
end
