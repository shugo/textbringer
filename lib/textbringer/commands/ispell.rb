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
  end
end
