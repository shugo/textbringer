require "stringio"

module Textbringer
  class DefaultOutput
    def write(*args)
      Buffer.current.insert(args.join)
    end

    def flush
    end

    [
      :print,
      :printf,
      :putc,
      :puts,
      :"<<"
    ].each do |mid|
      define_method(mid) do |*args|
        buffer = StringIO.new
        buffer.send(mid, *args)
        write(buffer.string)
      end
    end
  end
end
