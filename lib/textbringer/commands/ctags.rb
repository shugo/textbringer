# frozen_string_literal: true

module Textbringer
  module Commands
    GLOBAL_MAP.define_key("\e.", :find_tag)

    CTAGS = {
      path: nil,
      tags: nil
    }

    define_command(:find_tag) do
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
      else
        tags = CTAGS[:tags]
      end
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
      file, addr = candidates.first
      find_file(file)
      case addr
      when /\A\d+\z/
        goto_line(addr.to_i)
      when %r'\A/\^(.*)\$/\z'
        beginning_of_buffer        
        re_search_forward("^" + Regexp.quote($1) + "$")
      else
        raise EditorError, "Invalid address: #{addr}"
      end
      Window.current.recenter_if_needed
    end
  end
end
