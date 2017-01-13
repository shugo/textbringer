# frozen_string_literal: true

module Textbringer
  module Minibuffer
    def message(msg)
      Window.echo_area.show(msg)
    end

    def read_from_minibuffer(prompt, completion_proc: nil, default: nil)
      if Buffer.current == Buffer.minibuffer
        raise "Command attempted to use minibuffer while in minibuffer"
      end
      buffer = Buffer.current
      window = Window.current
      old_completion_proc = Buffer.minibuffer[:completion_proc]
      Buffer.minibuffer[:completion_proc] = completion_proc
      begin
        Buffer.minibuffer.delete_region(Buffer.minibuffer.point_min,
                                        Buffer.minibuffer.point_max)
        Buffer.current = Buffer.minibuffer
        Window.current = Window.echo_area
        if default
          prompt = prompt.sub(/:/, " (default #{default}):")
        end
        Window.echo_area.prompt = prompt
        Window.echo_area.redisplay
        Window.update
        recursive_edit
        s = Buffer.minibuffer.to_s.chomp
        if default && s.empty?
          default
        else
          s
        end
      ensure
        Window.echo_area.clear
        Window.echo_area.redisplay
        Window.update
        Buffer.current = buffer
        Window.current = window
        Buffer.minibuffer[:completion_proc] = old_completion_proc
      end
    end

    def read_file_name(prompt, default: nil)
      f = ->(s) {
        files = Dir.glob(s + "*")
        if files.size > 0
          x, *xs = files
          file = x.size.downto(1).lazy.map { |i|
            x[0, i]
          }.find { |i|
            xs.all? { |j| j.start_with?(i) }
          }
          if file && files.size == 1 &&
             File.directory?(file) && !file.end_with?(?/)
            file + "/"
          else
            file
          end
        else
          nil
        end
      }
      read_from_minibuffer(prompt, completion_proc: f, default: default)
    end

    def complete(s, candidates)
      xs = candidates.select { |i| i.start_with?(s) }
      if xs.size > 0
        y, *ys = xs
        y.size.downto(1).lazy.map { |i|
          y[0, i]
        }.find { |i|
          ys.all? { |j| j.start_with?(i) }
        }
      else
        nil
      end
    end

    def read_buffer(prompt, default: (Buffer.last || Buffer.current)&.name)
      f = ->(s) { complete(s, Buffer.names) }
      read_from_minibuffer(prompt, completion_proc: f, default: default)
    end

    def read_command_name(prompt)
      f = ->(s) {
        complete(s.tr("-", "_"), Commands.list.map(&:to_s))
      }
      read_from_minibuffer(prompt, completion_proc: f)
    end

    def yes_or_no?(prompt)
      loop {
        s = read_from_minibuffer(prompt + " (yes or no) ")
        case s
        when "yes"
          return true
        when "no"
          return false
        else
          message("Please answer yes or no.")
        end
      }
    end

    def y_or_n?(prompt)
      loop {
        s = read_from_minibuffer(prompt + " (y or n) ")
        case s
        when "y"
          return true
        when "n"
          return false
        else
          message("Please answer y or n.")
        end
      }
    end
  end
end
