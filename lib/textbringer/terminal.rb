require_relative "terminal/attributes"
require_relative "terminal/screen_buffer"
require_relative "terminal/input"
require_relative "terminal/window"
require_relative "terminal/pad"

module Textbringer
  module Terminal
    module Termios
      # TIOCGWINSZ: get terminal window size
      TIOCGWINSZ = case RUBY_PLATFORM
                   when /linux/  then 0x5413
                   when /darwin/ then 0x40087468
                   else               0x5413
                   end
    end
    @color_pairs = {}  # pair_number => [fg, bg]
    @virtual_screen = nil
    @physical_screen = nil
    @input_reader = nil
    @lines = 24
    @cols = 80
    @old_tio = nil
    @colors = 256
    @cursor_y = 0
    @cursor_x = 0

    class << self
      attr_reader :virtual_screen, :physical_screen, :input_reader

      def init_screen
        # Query terminal size
        update_size
        # Set up raw mode
        @old_stty = `stty -g`.chomp
        system("stty raw -echo -icanon -isig")
        # Enable alternate screen buffer
        STDOUT.write("\e[?1049h")
        # Enable mouse tracking could go here
        # Hide cursor during updates
        STDOUT.write("\e[?25l")
        # Clear screen
        STDOUT.write("\e[2J\e[H")
        STDOUT.flush

        # Set up screen buffers
        @virtual_screen = ScreenBuffer.new(@lines, @cols)
        @physical_screen = ScreenBuffer.new(@lines, @cols)

        # Set up input reader
        @input_reader = Input::Reader.new(STDIN)

        # Handle SIGWINCH
        install_sigwinch_handler

        # Enable keypad sequences
        STDOUT.write("\e[?1h")  # Application cursor keys
        STDOUT.flush
      end

      def close_screen
        return unless @old_stty
        # Show cursor
        STDOUT.write("\e[?25h")
        # Reset attributes
        STDOUT.write("\e[0m")
        # Disable alternate screen buffer
        STDOUT.write("\e[?1049l")
        # Reset cursor keys to normal mode
        STDOUT.write("\e[?1l")
        STDOUT.flush
        # Restore terminal settings
        system("stty #{@old_stty}")
        @old_stty = nil
        @virtual_screen = nil
        @physical_screen = nil
        @input_reader = nil
      end

      def reinit_screen
        # Re-initialize after suspend/resume
        update_size
        @old_stty = `stty -g`.chomp
        system("stty raw -echo -icanon -isig")
        STDOUT.write("\e[?1049h")
        STDOUT.write("\e[?25l")
        STDOUT.write("\e[0m\e[2J\e[H")
        STDOUT.write("\e[?1h")
        STDOUT.flush

        @virtual_screen = ScreenBuffer.new(@lines, @cols)
        @physical_screen = ScreenBuffer.new(@lines, @cols, dirty: true)
        @input_reader = Input::Reader.new(STDIN)
      end

      def echo
        # No-op for our implementation
      end

      def noecho
        # Already handled in raw mode
      end

      def raw
        # Already handled in init_screen
      end

      def noraw
        # No-op; restored in close_screen
      end

      def nl
        # No-op
      end

      def nonl
        # No-op
      end

      def has_colors?
        # Check if terminal supports colors via TERM
        term = ENV["TERM"] || ""
        !term.empty? && term != "dumb"
      end

      def start_color
        # Already available via ANSI sequences
      end

      def use_default_colors
        # Already supported
      end

      def colors
        @colors
      end

      def assume_default_colors(fg, bg)
        # Store and apply default colors
        @default_fg = fg
        @default_bg = bg
      end

      def init_pair(pair_num, fg, bg)
        @color_pairs[pair_num] = [fg, bg]
      end

      def color_pair(pair_num)
        pair_num << COLOR_PAIR_SHIFT
      end

      def pair_info(pair_num)
        @color_pairs[pair_num]
      end

      def lines
        @lines
      end

      def cols
        @cols
      end

      def beep
        STDOUT.write("\a")
        STDOUT.flush
      end

      def doupdate
        return unless @virtual_screen && @physical_screen

        output = @virtual_screen.flush_diff(@physical_screen)
        unless output.empty?
          STDOUT.write(output)
        end
        # Move cursor to the position set by the last noutrefresh
        STDOUT.write("\e[#{@cursor_y + 1};#{@cursor_x + 1}H")
        # Always reset SGR so the terminal is never left in a face's state
        STDOUT.write("\e[0m")
        STDOUT.write("\e[?25h")
        STDOUT.flush
      end

      def set_cursor(y, x)
        @cursor_y = y
        @cursor_x = x
      end

      def unget_char(ch)
        # Not commonly used, but support it via input reader
      end

      def save_key_modifiers(flag)
        # Not applicable for ANSI terminals
      end

      private

      def update_size
        # TIOCGWINSZ ioctl fills a winsize struct: rows, cols, xpixel, ypixel (each uint16)
        buf = "\x00" * 8
        if STDOUT.respond_to?(:ioctl) &&
            STDOUT.ioctl(Termios::TIOCGWINSZ, buf) >= 0
          rows, cols = buf.unpack("S!S!")
          if rows > 0 && cols > 0
            @lines = rows
            @cols = cols
            return
          end
        end
        @lines = (ENV["LINES"] || 24).to_i
        @cols = (ENV["COLUMNS"] || 80).to_i
      rescue Errno::ENOTTY, NotImplementedError
        @lines = (ENV["LINES"] || 24).to_i
        @cols = (ENV["COLUMNS"] || 80).to_i
      end

      def install_sigwinch_handler
        Signal.trap(:WINCH) do
          old_lines = @lines
          old_cols = @cols
          update_size
          if @lines != old_lines || @cols != old_cols
            @virtual_screen = ScreenBuffer.new(@lines, @cols)
            # Dirty physical forces flush_diff to re-render every cell,
            # ensuring correct SGR even for spaces and line endings.
            @physical_screen = ScreenBuffer.new(@lines, @cols, dirty: true)
            # Reset SGR before clearing so \e[2J uses default background.
            STDOUT.write("\e[0m\e[2J")
            STDOUT.flush
            # Push a resize event
            @input_reader&.instance_variable_get(:@buf)&.push(
              Input::KEY_RESIZE
            )
          end
        end
      end
    end
  end
end
