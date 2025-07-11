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
        result = @stdout.gets.chomp
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
      word = buffer.word_at_point
      if word.nil?
        message("No word at point.")
        return
      end
      ispell = Ispell.new
      begin
        _original, suggestions = ispell.check_word(word)
        if suggestions.nil? || suggestions.empty?
          message("#{word.inspect} is spelled correctly.")
        else
          s = read_from_minibuffer("Correct #{word} with: ",
                                   completion: ->(s) {
                                     suggestions.grep(/^#{Regexp.quote(s)}/)
                                   })
          if s
            buffer.delete_region(buffer.point - word.length, buffer.point)
            buffer.insert(s)
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
          while (m = buffer.re_search_forward(/\w+/))
            word = m[0]
            _original, suggestions = ispell.check_word(word)
            next if suggestions.nil? || suggestions.empty?
            buffer.goto_char(m.begin(0))
            Window.current.recenter
            Window.redisplay
            s = read_from_minibuffer("Correct #{word} with: ",
                                     completion: ->(s) {
                                       suggestions.grep(/^#{Regexp.quote(s)}/)
                                     })
            if s
              buffer.delete_region(m.begin(0), m.end(0))
              buffer.insert(s)
            end
          end
        end
      ensure
        ispell.close
      end
      message("Finished spelling check.")
    end
  end
end
