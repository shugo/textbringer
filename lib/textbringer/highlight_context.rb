module Textbringer
  class HighlightContext
    attr_reader :buffer, :highlight_start, :highlight_end

    def initialize(buffer:, highlight_start:, highlight_end:,
                   highlight_on:, highlight_off:)
      @buffer = buffer
      @highlight_start = highlight_start
      @highlight_end = highlight_end
      @highlight_on = highlight_on
      @highlight_off = highlight_off
    end

    def highlight(start_offset, end_offset, face)
      start_offset = @highlight_start if start_offset < @highlight_start &&
        @highlight_start < end_offset
      @highlight_on[start_offset] = face
      @highlight_off[end_offset] = true
    end
  end
end
