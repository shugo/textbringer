module Textbringer
  module Commands
    CTAGS = {
      path: nil,
      tags: nil,
      tags_mtime: nil,
      name: nil,
      candidates: nil,
      index: nil,
      tag_mark_stack: []
    }

    define_command(:find_tag) do |next_p = current_prefix_arg|
      tags = get_tags
      if next_p
        name = CTAGS[:name]
        if name.nil?
          raise EditorError, "Tag search not started yet"
        end
        candidates = CTAGS[:candidates]
        index = CTAGS[:index]
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
        name = buffer.current_symbol
        if name.nil?
          raise EditorError, "No name found at point"
        end
        candidates = tags[name]
        if candidates.empty?
          raise EditorError, "Tag not found: #{name}"
        end
        CTAGS[:name] = name
        CTAGS[:candidates] = candidates
        index = 0
      end
      file, addr, n = candidates[index]
      case addr
      when /\A\d+\z/
        push_tag_mark_and_find_file(file)
        goto_line(addr.to_i)
      when %r'\A/\^(.*?)(\$)?/\z'
        re = "^" + Regexp.quote($1.gsub(/\\([\\\/])/, "\\1")) + $2.to_s
        push_tag_mark_and_find_file(file)
        beginning_of_buffer
        n.times do
          re_search_forward(re)
        end
        beginning_of_line
      when %r'\A\?\^(.*)\$\?\z'
        push_tag_mark_and_find_file(file)
        end_of_buffer
        n.times do
          re_search_backward("^" + Regexp.quote($1) + "$")
        end
      else
        raise EditorError, "Invalid address: #{addr}"
      end
      CTAGS[:index] = index
      Window.current.recenter_if_needed
    end

    def get_tags
      path = File.expand_path("tags")
      mtime = File.mtime(path)
      if CTAGS[:path] != path || CTAGS[:tags_mtime] != mtime
        CTAGS[:path] = path
        tags = Hash.new { |h, k| h[k] = [] }
        File.read(path).scan(/^(.*?)\t(.*?)\t(.*?)(?:;".*)?$/) do
          |name, file, addr|
          n = tags[name].count { |f,| f == file } + 1
          tags[name].push([file, addr, n])
        end
        CTAGS[:tags] = tags
        CTAGS[:tags_mtime] = mtime
        message("Loaded #{path}")
      end
      CTAGS[:tags]
    end

    private

    def push_tag_mark_and_find_file(file)
      Buffer.current.push_global_mark(force: true)
      find_file(file)
    end
  end
end
