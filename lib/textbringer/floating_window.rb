require "curses"

module Textbringer
  class FloatingWindow < Window
    # Class-level tracking (separate from @@list)
    @@floating_windows = []

    def self.floating_windows
      @@floating_windows.dup
    end

    def self.close_all_floating
      @@floating_windows.dup.each(&:close)
    end

    def self.redisplay_all_floating
      @@floating_windows.each do |win|
        win.redisplay unless win.deleted?
      end
    end

    # Initialize with dimensions and position
    # @param lines [Integer] Height of the floating window
    # @param columns [Integer] Width of the floating window
    # @param y [Integer] Screen Y coordinate
    # @param x [Integer] Screen X coordinate
    # @param buffer [Buffer, nil] Optional buffer, creates new if nil
    # @param face [Symbol, nil] Face name to apply to the window (default: :floating_window)
    def initialize(lines, columns, y, x, buffer: nil, face: :floating_window)
      super(lines, columns, y, x)

      # Create or assign buffer
      if buffer
        self.buffer = buffer
      else
        # Create a dedicated buffer for this floating window
        name = "*floating-#{object_id}*"
        self.buffer = Buffer.new_buffer(name, undo_limit: 0)
      end

      # Store face for rendering
      @face = face

      # Track this floating window
      @@floating_windows << self
      @visible = false
    end

    # Factory methods for common positioning patterns
    def self.at_cursor(lines:, columns:, window: Window.current, buffer: nil, face: :floating_window)
      y, x = calculate_cursor_position(lines, columns, window)
      new(lines, columns, y, x, buffer: buffer, face: face)
    end

    def self.centered(lines:, columns:, buffer: nil, face: :floating_window)
      y = (Curses.lines - lines) / 2
      x = (Curses.cols - columns) / 2
      new(lines, columns, y, x, buffer: buffer, face: face)
    end

    # Override: Not part of main window list management
    def echo_area?
      false
    end

    def active?
      @visible && !deleted?
    end

    def floating_window?
      true
    end

    # Visibility management
    def show
      # Save current window to prevent focus change
      old_current = Window.current
      @visible = true
      redisplay
      # Restore focus to original window
      Window.current = old_current if Window.current != old_current
      self
    end

    def hide
      @visible = false
      Window.redisplay  # Refresh underlying windows
      self
    end

    def visible?
      @visible && !deleted?
    end

    # Override delete to clean up from floating window list
    def delete
      return if deleted?

      @@floating_windows.delete(self)
      @visible = false

      # Delete associated buffer if auto-generated
      if @buffer && @buffer.name.start_with?("*floating-")
        @buffer.kill
      end

      super  # Call Window#delete

      Window.redisplay
    end

    alias_method :close, :delete

    # Move to new position
    def move_to(y:, x:)
      @y = y
      @x = x
      redisplay if visible?
      self
    end

    # Resize window
    def resize(lines, columns)
      @lines = lines
      @columns = columns

      # Recreate pad with new size
      old_window = @window
      initialize_window(lines, columns, @y, @x)

      redisplay if visible?
      self
    end

    # Override redisplay to use pad refresh
    def redisplay
      return if @buffer.nil? || !@visible || deleted?

      @buffer.save_point do |point|
        @window.erase

        # Get face attributes if face is specified
        face_attrs = 0
        if @face && Window.has_colors?
          face = Face[@face]
          face_attrs = face.attributes if face
        end

        @window.attrset(face_attrs)
        @in_region = false
        @in_isearch = false
        @current_highlight_attrs = face_attrs

        # Start from top of window
        @buffer.point_to_mark(@top_of_window)
        @cursor.y = @cursor.x = 0

        # Render lines
        line_num = 0
        while line_num < @lines && !@buffer.end_of_buffer?
          @window.setpos(line_num, 0)

          # Render characters on this line
          col = 0
          while col < @columns && !@buffer.end_of_buffer?
            cury = @window.cury
            curx = @window.curx

            # Apply face attributes without modifying cursor tracking
            if @buffer.point_at_mark?(point)
              @cursor.y = cury
              @cursor.x = curx
            end

            c = @buffer.char_after
            break if c.nil?

            if c == "\n"
              @buffer.forward_char
              break
            end

            s = escape(c)
            char_width = Buffer.display_width(s)

            if col + char_width > @columns
              break
            end

            # Apply face attributes to all characters
            if face_attrs != 0
              @window.attron(face_attrs)
            end
            @window.addstr(s)
            if face_attrs != 0
              @window.attroff(face_attrs)
            end

            col += char_width
            @buffer.forward_char
          end

          # Fill remaining space on the line with the face background
          if face_attrs != 0 && col < @columns
            @window.attron(face_attrs)
            @window.addstr(" " * (@columns - col))
            @window.attroff(face_attrs)
          end

          # Track cursor position
          if @buffer.point_at_mark?(point)
            @cursor.y = line_num
            @cursor.x = col
          end

          line_num += 1
        end

        # Fill remaining lines with the face background
        if face_attrs != 0
          while line_num < @lines
            @window.setpos(line_num, 0)
            @window.attron(face_attrs)
            @window.addstr(" " * @columns)
            @window.attroff(face_attrs)
            line_num += 1
          end
        end

        # Don't set cursor position - FloatingWindow should not affect screen cursor
        # The cursor stays in the original window that had focus

        # Refresh pad to screen
        # noutrefresh(pad_min_y, pad_min_x, screen_min_y, screen_min_x, screen_max_y, screen_max_x)
        @window.noutrefresh(
          0, 0,  # Start of pad
          @y, @x,  # Screen position
          @y + @lines - 1, @x + @columns - 1  # Screen extent
        )
      end
    end

    private

    # Override to create Curses::Pad instead of Curses::Window
    def initialize_window(num_lines, num_columns, y, x)
      @window = Curses::Pad.new(num_lines, num_columns)
      # Note: Pad position is set during refresh, not at creation
      # No mode_line for floating windows
      @mode_line = nil
    end

    def self.calculate_cursor_position(lines, columns, window)
      # Get cursor screen coordinates
      cursor_y = window.y + window.cursor.y
      cursor_x = window.x + window.cursor.x

      # Prefer below cursor
      space_below = Curses.lines - cursor_y - 2  # -2 for echo area
      space_above = cursor_y - window.y

      if space_below >= lines
        y = cursor_y + 1
      elsif space_above >= lines
        y = cursor_y - lines
      else
        # Not enough space, show below and clip
        y = [cursor_y + 1, Curses.lines - lines - 1].max
        y = [y, 0].max
      end

      # Adjust x to prevent overflow
      x = cursor_x
      if x + columns > Curses.cols
        x = [Curses.cols - columns, 0].max
      end

      [y, x]
    end
  end
end
