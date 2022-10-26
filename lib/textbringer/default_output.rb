require "stringio"

module Textbringer
  class DefaultOutput
    def write(*args)
      Buffer.current.insert(args.join)
    end

    def flush
    end

    def method_missing(mid, ...)
      buffer = StringIO.new
      buffer.send(mid, ...)
      write(buffer.string)
    end
  end
end
