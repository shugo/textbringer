module Textbringer
  class CompletionPopup
    MAX_VISIBLE_ITEMS = 10
    MIN_WIDTH = 20
    MAX_WIDTH = 60

    attr_reader :items, :selected_index, :start_point

    def self.instance
      @instance ||= new
    end

    def initialize
      @floating_window = nil
      @items = []
      @selected_index = 0
      @start_point = nil
      @prefix = ""
    end

    def show(items:, start_point:, prefix: "")
      @items = items
      @start_point = start_point
      @prefix = prefix
      @selected_index = 0

      return if @items.empty?

      create_or_update_window
      render
      @floating_window.show
    end

    def hide
      @floating_window&.hide
    end

    def close
      if @floating_window
        @floating_window.close
        @floating_window = nil
      end
      @items = []
      @selected_index = 0
      @start_point = nil
      @prefix = ""
    end

    def visible?
      @floating_window&.visible? || false
    end

    def select_next
      return unless visible? && !@items.empty?
      @selected_index = (@selected_index + 1) % @items.size
      render
      @floating_window.redisplay
    end

    def select_previous
      return unless visible? && !@items.empty?
      @selected_index = (@selected_index - 1) % @items.size
      render
      @floating_window.redisplay
    end

    def accept
      return nil unless visible? && !@items.empty?
      item = current_item
      close
      item
    end

    def cancel
      close
      nil
    end

    def current_item
      return nil if @items.empty?
      @items[@selected_index]
    end

    private

    def create_or_update_window
      lines = visible_item_count
      columns = calculate_width

      if @floating_window && !@floating_window.deleted?
        @floating_window.resize(lines, columns)
        y, x = FloatingWindow.calculate_cursor_position(lines, columns, Window.current)
        @floating_window.move_to(y: y, x: x)
      else
        @floating_window = FloatingWindow.at_cursor(
          lines: lines,
          columns: columns,
          face: :completion_popup,
          current_line_face: :completion_popup_selected
        )
      end
    end

    def visible_item_count
      [@items.size, MAX_VISIBLE_ITEMS].min
    end

    def calculate_width
      max_label_width = @items.map { |item| display_width(item[:label]) }.max || 0
      max_detail_width = @items.map { |item|
        item[:detail] ? display_width(item[:detail]) + 2 : 0
      }.max || 0

      width = max_label_width + max_detail_width + 2  # padding
      [[width, MIN_WIDTH].max, MAX_WIDTH].min
    end

    def display_width(str)
      return 0 unless str
      Buffer.display_width(str)
    end

    def render
      buffer = @floating_window.buffer
      buffer.read_only = false
      begin
        buffer.clear

        # Calculate visible range with scroll
        visible_count = visible_item_count
        scroll_offset = calculate_scroll_offset(visible_count)

        visible_items = @items[scroll_offset, visible_count]
        visible_items.each_with_index do |item, index|
          line = format_item(item)
          buffer.insert(line)
          buffer.insert("\n")
        end

        # Go to the selected line so current_line_face highlights it
        relative_index = @selected_index - scroll_offset
        buffer.goto_line(relative_index + 1)
        buffer.beginning_of_line
      ensure
        buffer.read_only = true
      end
    end

    def calculate_scroll_offset(visible_count)
      if @selected_index < visible_count
        0
      else
        @selected_index - visible_count + 1
      end
    end

    def format_item(item)
      label = item[:label] || ""
      detail = item[:detail]

      # Build the display string
      result = label
      if detail
        result = "#{label}  #{detail}"
      end

      # Truncate if too long
      width = calculate_width
      if display_width(result) > width
        result = truncate_to_width(result, width - 1) + "…"
      end

      result
    end

    def truncate_to_width(str, max_width)
      result = ""
      current_width = 0
      str.each_char do |char|
        char_width = Buffer.display_width(char)
        break if current_width + char_width > max_width
        result << char
        current_width += char_width
      end
      result
    end
  end
end
