# frozen_string_literal: true

require "drb"

module Textbringer
  module Commands
    define_command(:server_start,
                   doc: "Start Textbringer server.") do
      uri = CONFIG[:server_uri] ||
        "drbunix:" + File.expand_path("server.sock", "~/.textbringer")
      options = CONFIG[:server_options] || { UNIXFileMode: 0600 }
      DRb.start_service(uri, Proxy.new, options)
    end

    define_command(:server_kill,
                   doc: "Kill Textbringer server.") do
      DRb.stop_service
    end

    define_command(:server_edit_done,
                   doc: "Finish server edit.") do
      queue = Buffer.current[:client_wait_queue]
      if queue.nil?
        raise EditorError, "No waiting clients"
      end
      if Buffer.current.modified? &&
          y_or_n?("Save file #{Buffer.current.file_name}?")
        save_buffer
      end
      kill_buffer(Buffer.current, force: true)
      queue.push(:done)
    end
  end

  class Proxy
    def execute_command(mid, *args)
      foreground do
        Commands.send(mid, *args)
      end
    end

    def eval(s)
      foreground do
        Controller.current.instance_eval(s)
      end
    end

    def visit_file(filename, wait: true)
      queue = Queue.new if wait
      foreground do
        find_file(filename)
        Buffer.current[:client_wait_queue] = queue if wait
      end
      queue.deq if wait
    end

    private

    def foreground
      next_tick! do
        yield
        Window.redisplay
      end
    end
  end
end
