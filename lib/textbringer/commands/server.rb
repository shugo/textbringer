require "drb"

module Textbringer
  module Commands
    define_command(:server_start,
                   doc: "Start Textbringer server.") do
      uri = CONFIG[:server_uri] ||
        "drbunix:" + File.expand_path("server.sock", "~/.textbringer")
      server = Server.new(uri)
      server.start
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

  class Server
    def initialize(uri)
      @uri = uri
    end

    def start
      front = FrontObject.new
      default_options = unix_domain? ? { UNIXFileMode: 0600 } : {}
      options = default_options.merge(CONFIG[:server_options] || {})
      begin
        DRb.start_service(@uri, front, options)
      rescue Errno::EADDRINUSE
        if unix_domain? && !unix_domain_server_alive?
          # Remove the socket file in case another server died unexpectedly before.
          File.unlink(unix_domain_socket_path)
          DRb.start_service(@uri, front, options)
        else
          raise ExistError, "There is an existing Textbringer server"
        end
      end
    end

    private

    def unix_domain?
      @uri.start_with?("drbunix:")
    end

    def unix_domain_socket_path
      @uri.sub(/\Adrbunix:/, "")
    end

    def unix_domain_server_alive?
      socket = Socket.new(:UNIX, :STREAM)
      sockaddr = Socket.sockaddr_un(unix_domain_socket_path)
      begin
        socket.connect_nonblock(sockaddr)
      rescue Errno::EINPROGRESS
        return true
      rescue Errno::ECONNREFUSED
        return false
      ensure
        socket.close
      end
    end
  end

  class Server::ExistError < EditorError
  end

  class Server::FrontObject
    def eval(s)
      with_redisplay do
        Controller.current.instance_eval(s).inspect
      end
    end

    def visit_file(filename, wait: true)
      queue = Queue.new if wait
      with_redisplay do
        find_file(filename)
        Buffer.current[:client_wait_queue] = queue if wait
      end
      queue.deq if wait
    end

    private

    def with_redisplay
      foreground! do
        begin
          yield
        ensure
          Window.redisplay
        end
      end
    end
  end
end
