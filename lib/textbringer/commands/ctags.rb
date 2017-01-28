# frozen_string_literal: true

module Textbringer
  module Commands
    GLOBAL_MAP.define_key("\e.", :find_tag)

    CTAGS = {
      path: nil,
      tags: nil,
      name: nil,
      candidates: nil,
      index: nil
    }

    define_command(:find_tag) do |next_p = current_prefix_arg|
      prev_file = nil
      tags = get_tags
      if next_p
        name = CTAGS[:name]
        if name.nil?
          raise EditorError, "Tag search not started yet"
        end
        candidates = CTAGS[:candidates]
        index = CTAGS[:index]
        prev_file, = candidates[index]
        if next_p == :-
          index -= 1
        else
          index += 1
        end
        if index < 0
          raise EditorError, "No previous tags for #{name}"
        end
        if index >= candidates.size
          raise EditorError, "No more tags for #{name}"
        end
      else
        buffer = Buffer.current
        name = buffer.save_excursion {
          buffer.backward_word(regexp: /[A-Za-z_\-]/)
          if buffer.looking_at?(/[A-Za-z_\-]+/)
            match_string(0)
          else
            nil
          end
        }
        if name.nil?
          raise EditorError, "No name found at point"
        end
        candidates = tags[name]
        if candidates.empty?
          raise EditorError, "Tag not found: #{name}"
        end
        CTAGS[:name] = name
        CTAGS[:candidates] = candidates
        CTAGS[:index] = index = 0
      end
      file, addr = candidates[index]
      find_file(file)
      case addr
      when /\A\d+\z/
        goto_line(addr.to_i)
      when %r'\A/\^(.*)\$/\z'
        if file == prev_file
          if next_p == :-
            beginning_of_line
          else
            end_of_line
          end
        else
          beginning_of_buffer
        end
        re = "^" + Regexp.quote($1) + "$"
        if next_p == :-
          re_search_backward(re)
        else
          re_search_forward(re)
        end
        beginning_of_line
      else
        raise EditorError, "Invalid address: #{addr}"
      end
      Window.current.recenter_if_needed
    end

    def get_tags
      path = File.expand_path("tags")
      if CTAGS[:path] != path
        CTAGS[:path] = path
        tags = Hash.new { |h, k| h[k] = [] }
        File.read(path).scan(/^(.*?)\t(.*?)\t(.*?)(?:;".*)?$/) do
          |name, file, addr|
          tags[name].push([file, addr])
        end
        CTAGS[:tags] = tags
        message("Loaded #{path}")
      end
      CTAGS[:tags]
    end
  end
end
