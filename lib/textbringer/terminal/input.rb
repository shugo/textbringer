module Textbringer
  module Terminal
    module Input
      # Timeout in seconds for distinguishing ESC from escape sequences
      DEFAULT_ESCAPE_TIMEOUT = 0.025

      # CSI sequence final bytes to key symbol mapping
      CSI_KEYS = {
        "A" => :up,
        "B" => :down,
        "C" => :right,
        "D" => :left,
        "F" => :end,
        "H" => :home,
        "Z" => :btab,  # Shift-Tab
      }

      # CSI sequences with numeric parameters: ESC [ <number> ~
      CSI_TILDE_KEYS = {
        1 => :home,
        2 => :ic,      # Insert
        3 => :dc,      # Delete
        4 => :end,
        5 => :ppage,   # Page Up
        6 => :npage,   # Page Down
        7 => :home,
        8 => :end,
        11 => :f1,
        12 => :f2,
        13 => :f3,
        14 => :f4,
        15 => :f5,
        17 => :f6,
        18 => :f7,
        19 => :f8,
        20 => :f9,
        21 => :f10,
        23 => :f11,
        24 => :f12,
      }

      # SS3 sequences: ESC O <letter>
      SS3_KEYS = {
        "A" => :up,
        "B" => :down,
        "C" => :right,
        "D" => :left,
        "F" => :end,
        "H" => :home,
        "P" => :f1,
        "Q" => :f2,
        "R" => :f3,
        "S" => :f4,
      }

      # KEY_NAMES maps integer key codes to symbols (for compatibility)
      # In our implementation, we return symbols directly, but maintain
      # this for the Window::KEY_NAMES lookup
      KEY_NAMES = {}

      # Map key symbols to integer codes for backward compatibility
      KEY_CODE_BASE = 0x100
      KEY_CODES = {}
      [:up, :down, :right, :left, :home, :end, :dc, :ic,
       :ppage, :npage, :btab, :resize,
       :f1, :f2, :f3, :f4, :f5, :f6, :f7, :f8, :f9, :f10, :f11, :f12,
      ].each_with_index do |sym, i|
        code = KEY_CODE_BASE + i
        KEY_CODES[sym] = code
        KEY_NAMES[code] = sym
      end

      KEY_RESIZE = KEY_CODES[:resize]

      class Reader
        def initialize(input = STDIN)
          @input = input
          @escape_timeout = DEFAULT_ESCAPE_TIMEOUT
          @buf = []
        end

        attr_accessor :escape_timeout

        # Read a single key event. Returns:
        # - String for regular characters (including UTF-8)
        # - Integer key code for special keys (looked up via KEY_NAMES)
        # - nil if no input available (nonblocking mode)
        def get_char(blocking: true, timeout_ms: -1)
          c = read_byte(blocking: blocking, timeout_ms: timeout_ms)
          return nil if c.nil?

          if c == 0x1b  # ESC
            return parse_escape_sequence
          elsif c < 0x80
            c.chr
          else
            read_utf8(c)
          end
        end

        private

        def read_byte(blocking: true, timeout_ms: -1)
          unless @buf.empty?
            return @buf.shift
          end

          if !blocking
            byte = @input.read_nonblock(1, exception: false)
            return nil if byte.nil? || byte == :wait_readable
            return byte.ord
          end

          if timeout_ms >= 0
            timeout_sec = timeout_ms / 1000.0
            if IO.select([@input], nil, nil, timeout_sec)
              byte = @input.read_nonblock(1, exception: false)
              return nil if byte.nil? || byte == :wait_readable
              return byte.ord
            end
            return nil
          end

          # Blocking read
          byte = @input.getbyte
          byte
        end

        def peek_byte(timeout)
          unless @buf.empty?
            return @buf.first
          end
          if IO.select([@input], nil, nil, timeout)
            byte = @input.read_nonblock(1, exception: false)
            if byte.nil? || byte == :wait_readable
              return nil
            end
            @buf.push(byte.ord)
            return byte.ord
          end
          nil
        end

        def parse_escape_sequence
          # Check if there's more input coming quickly (escape sequence)
          next_byte = peek_byte(@escape_timeout)
          if next_byte.nil?
            # Standalone ESC
            return "\e"
          end

          @buf.shift
          case next_byte
          when 0x5b  # [  -> CSI
            parse_csi
          when 0x4f  # O  -> SS3
            parse_ss3
          else
            # Alt + character
            if next_byte < 0x80
              ch = next_byte.chr
              # Return ESC, push the char back for next read
              @buf.unshift(next_byte)
              return "\e"
            else
              @buf.unshift(next_byte)
              return "\e"
            end
          end
        end

        def parse_csi
          params = +""
          loop do
            b = peek_byte(0.1)
            if b.nil?
              # Incomplete sequence, return what we have
              return "\e"
            end
            @buf.shift
            ch = b.chr
            if ch.match?(/[0-9;]/)
              params << ch
            else
              # Final byte
              return resolve_csi(params, ch)
            end
          end
        end

        def resolve_csi(params, final)
          if final == "~"
            num = params.to_i
            sym = CSI_TILDE_KEYS[num]
            if sym
              KEY_CODES[sym]
            else
              nil  # Unknown sequence
            end
          elsif CSI_KEYS[final]
            KEY_CODES[CSI_KEYS[final]]
          else
            nil  # Unknown CSI sequence
          end
        end

        def parse_ss3
          b = peek_byte(0.1)
          if b.nil?
            return "\e"
          end
          @buf.shift
          ch = b.chr
          sym = SS3_KEYS[ch]
          if sym
            KEY_CODES[sym]
          else
            nil
          end
        end

        def read_utf8(first_byte)
          # Determine how many continuation bytes to expect
          if first_byte & 0xE0 == 0xC0
            len = 1
          elsif first_byte & 0xF0 == 0xE0
            len = 2
          elsif first_byte & 0xF8 == 0xF0
            len = 3
          else
            # Invalid UTF-8 start byte
            return first_byte.chr(Encoding::BINARY)
          end

          bytes = [first_byte]
          len.times do
            b = read_byte(blocking: true, timeout_ms: 100)
            if b.nil? || (b & 0xC0) != 0x80
              @buf.unshift(b) if b
              return bytes.pack("C*").force_encoding(Encoding::BINARY)
            end
            bytes << b
          end

          bytes.pack("C*").force_encoding(Encoding::UTF_8)
        end
      end
    end
  end
end
