# frozen_string_literal: true

module Textbringer
  class Ring
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

    def push(str)
      @current += 1
      if @ring.size < @max
        @ring.insert(@current, str)
      else
        if @current == @max
          @current = 0
        end
        @on_delete.call(@ring[@current])
        @ring[@current] = str
      end
    end

    def pop
      x = @ring[@current]
      current(1)
      x
    end

    def current(n = 0)
      if @ring.empty?
        raise EditorError, "Ring is empty"
      end
      @current -= n
      if @current < 0
        @current += @ring.size
      end
      @ring[@current]
    end

    def empty?
      @ring.empty?
    end

    def size
      @ring.size
    end
  end
end
