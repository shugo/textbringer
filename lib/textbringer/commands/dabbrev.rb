# frozen_string_literal: true

module Textbringer
  module DabbrevExtension
    refine Buffer do
      def dabbrev_expand(contd = false)
        if contd && self[:dabbrev_stem]
          buffers = self[:dabbrev_buffers]
          buffer = self[:dabbrev_buffer]
          stem = self[:dabbrev_stem]
          pos = self[:dabbrev_pos]
          direction = self[:dabbrev_direction]
          candidates = self[:dabbrev_candidates]
        else
          buffers = Buffer.to_a
          buffers.delete(self)
          buffer = self
          stem = get_stem_at_point
          pos = point
          direction = :backward
          candidates = []
        end
        re = dabbrev_regexp(stem, candidates)
        candidate = nil
        loop do
          pos, candidate = buffer.dabbrev_search(re, pos, direction)
          break if pos
          if direction == :backward
            pos = buffer.point
            direction = :forward
          else
            buffer = buffers.pop
            break if buffer.nil?
            pos = buffer.point
            direction = :backward
          end
        end
        if !candidates.empty?
          undo
        end
        if candidate
          candidates.push(candidate)
          insert(candidate)
        else
          self[:dabbrev_stem] = nil
          raise EditorError, "No more abbreviation"
        end
        self[:dabbrev_buffers] = buffers
        self[:dabbrev_buffer] = buffer
        self[:dabbrev_stem] = stem
        self[:dabbrev_pos] = pos
        self[:dabbrev_direction] = direction
        self[:dabbrev_candidates] = candidates
      end

      def dabbrev_search(re, pos, direction)
        re_search_method = direction == :forward ?
          :re_search_forward : :re_search_backward
        save_excursion do
          goto_char(pos)
          if send(re_search_method, re, raise_error: false)
            [point, match_string(1)]
          else
            nil
          end
        end
      end

      private

      def get_stem_at_point
        save_excursion {
          pos = point
          backward_word(regexp: /[\p{Letter}\p{Number}_\-]/)
          if point == pos
            raise EditorError, "No possible abbreviation"
          end
          substring(point, pos)
        }
      end

      def dabbrev_regexp(stem, candidates)
        candidates_exclusion = candidates.empty? ? "" :
          "(?!(?:" + candidates.map { |s|
            Regexp.quote(s)
          }.join("|") + ")\\b)"
        /\b#{Regexp.quote(stem)}#{candidates_exclusion}
        ([\p{Letter}\p{Number}_\-]+)/x
      end
    end
  end

  using DabbrevExtension

  module Commands
    GLOBAL_MAP.define_key("\e/", :dabbrev_expand_command)

    define_command(:dabbrev_expand_command) do
      contd = Controller.current.last_command == :dabbrev_expand_command
      Buffer.current.dabbrev_expand(contd)
    end
  end
end
