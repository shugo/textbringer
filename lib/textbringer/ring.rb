module Textbringer
  class Ring
    include Enumerable

    def initialize(max = 30, on_delete: ->(x) {})
      @max = max
      @ring = []
      @current = -1
      @on_delete = on_delete
    end

    def clear
      @ring.clear
      @current = -1
    end

    def push(obj)
      @current += 1
      if @ring.size < @max
        @ring.insert(@current, obj)
      else
        if @current == @max
          @current = 0
        end
        @on_delete.call(@ring[@current])
        @ring[@current] = obj
      end
    end

    def pop
      x = @ring[@current]
      rotate(1)
      x
    end

    def current
      if @ring.empty?
        raise EditorError, "Ring is empty"
      end
      @ring[@current]
    end

    def rotate(n)
      @current = get_index(n)
      @ring[@current]
    end

    def [](n = 0)
      @ring[get_index(n)]
    end

    def empty?
      @ring.empty?
    end

    def size
      @ring.size
    end

    def each(&block)
      @ring.each(&block)
    end

    def to_a
      @ring.to_a
    end

    private

    def get_index(n)
      if @ring.empty?
        raise EditorError, "Ring is empty"
      end
      i = @current - n
      if 0 <= i && i < @ring.size
        i
      else
        i % @ring.size
      end
    end
  end
end
