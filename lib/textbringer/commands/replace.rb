# frozen_string_literal: true

module Textbringer
  module Commands
    RE_SEARCH_STATUS = {
      last_regexp: nil
    }

    define_command(:re_search_forward) do
      |s = read_from_minibuffer("RE search: ",
                                default: RE_SEARCH_STATUS[:last_regexp])|
      RE_SEARCH_STATUS[:last_regexp] = s
      Buffer.current.re_search_forward(s)
    end

    define_command(:re_search_backward) do
      |s = read_from_minibuffer("RE search backward: ",
                                default: RE_SEARCH_STATUS[:last_regexp])|
      RE_SEARCH_STATUS[:last_regexp] = s
      Buffer.current.re_search_backward(s)
    end

    def match_beginning(n)
      Buffer.current.match_beginning(n)
    end

    def match_end(n)
      Buffer.current.match_end(n)
    end

    def match_string(n)
      Buffer.current.match_string(n)
    end

    def replace_match(s)
      Buffer.current.replace_match(s)
    end

    define_command(:query_replace_regexp) do
      |regexp = read_from_minibuffer("Query replace regexp: "),
       to_str = read_from_minibuffer("with: ")|
      n = 0
      begin
        loop do
          re_search_forward(regexp)
          Window.current.recenter_if_needed
          Buffer.current.set_visible_mark(match_beginning(0))
          begin
            Window.redisplay
            c = read_single_char("Replace?", [?y, ?n, ?!, ?q, ?.])
            case c
            when ?y
              replace_match(to_str)
              n += 1
            when ?n
              # do nothing
            when ?!
              replace_match(to_str)
              n += 1 + Buffer.current.replace_regexp_forward(regexp, to_str)
              Buffer.current.merge_undo(2)
              break
            when ?q
              break
            when ?.
              replace_match(to_str)
              n += 1
              break
            end
          ensure
            Buffer.current.delete_visible_mark
          end
        end
      rescue SearchError
      end
      if n == 1
        message("Replaced 1 occurrence")
      else
        message("Replaced #{n} occurrences")
      end
    end
  end
end
