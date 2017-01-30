# frozen_string_literal: true

module Textbringer
  module Dabbrev
    refine Buffer do
      def dabbrev_expand(contd)
        if contd && self[:dabbrev_stem]
          buffers = self[:dabbrev_buffers]
          buffer = self[:dabbrev_buffer]
          stem = self[:dabbrev_stem]
          pos = self[:dabbrev_pos]
          direction = self[:dabbrev_direction]
          candidates = self[:dabbrev_candidates]
        else
          buffers = Buffer.to_a
          buffer = buffers.pop
          stem = save_excursion {
            pos = point
            backward_word(regexp: /[\p{Letter}\p{Number}_\-]/)
            substring(point, pos)
          }
          if stem.empty?
            raise "No possible abbreviation"
          end
          pos = point
          direction = :backward
          candidates = []
        end
        candidates_exclusion = candidates.empty? ? "" :
          "(?!(?:" + candidates.map { |s|
            Regexp.quote(s)
          }.join("|") + ")\\b)"
        re = /\b#{Regexp.quote(stem)}#{candidates_exclusion}
              ([\p{Letter}\p{Number}_\-]+)/x
        candidate = nil
        loop do
          pos, candidate = buffer.dabbrev_search(re, pos, direction)
          if pos
            break
          else
            if direction == :backward
              pos = buffer.point
              direction = :forward
            else
              buffer = buffers.pop
              if buffer
                pos = buffer.point
                direction = :backward
              else
                break
              end
            end
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
    end
  end

  using Dabbrev

  module Commands
    GLOBAL_MAP.define_key("\e/", :dabbrev_expand_command)

    define_command(:dabbrev_expand_command) do
      contd = Controller.current.last_command == :dabbrev_expand_command
      Buffer.current.dabbrev_expand(contd)
    end
  end
end
