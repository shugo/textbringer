# frozen_string_literal: true

require "open3"

module Textbringer
  module Commands
    class Ispell
      def initialize
        @stdin, @stdout, @stderr, @wait_thr =
          Open3.popen3("aspell -a")
        @stdout.gets # consume the banner
      end

      def check_word(word)
        @stdin.puts("^" + word)
        result = @stdout.readpartial(4096)
        case result
        when /\A&\s+([^\s]+)\s+\d+\s+\d+:\s+(.*)/
          [$1, $2.split(/, /)]
        when /\A\*/, /\A\+/
          [word, []]
        when /\A#/
          [word, nil]
        else
          raise "unexpected output from aspell: #{result}"
        end
      end

      def close
        @stdin.close
        @stdout.close
        @stderr.close
      end
    end

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

    define_command(:ispell_buffer) do
      buffer = Buffer.current
      ispell = Ispell.new
      begin
        buffer.save_excursion do
          buffer.beginning_of_buffer
          while buffer.re_search_forward(/[A-Za-z]+/, raise_error: false)
            word = buffer.match_string(0)
            _original, suggestions = ispell.check_word(word)
            next if suggestions.nil? || suggestions.empty?
            buffer.save_excursion do
              buffer.goto_char(buffer.match_beginning(0))
              buffer.set_visible_mark
            end
            recenter
            Window.redisplay
            s = read_from_minibuffer("Correct #{word} with: ",
                                     completion_proc: ->(s) {
                                       suggestions.grep(/^#{Regexp.quote(s)}/)
                                     })
            if !s.empty?
              pos = buffer.point
              buffer.backward_word
              buffer.composite_edit do
                buffer.delete_region(buffer.point, pos)
                buffer.insert(s)
              end
            end
          end
        end
      ensure
        ispell.close
        Buffer.current.delete_visible_mark
      end
      message("Finished spelling check.")
    end
  end
end
