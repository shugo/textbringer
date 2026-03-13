module Textbringer
  module Terminal
    # A single character cell on screen
    Cell = Struct.new(:char, :attrs, :fg, :bg, :wide_padding) do
      def ==(other)
        other.is_a?(Cell) &&
          char == other.char &&
          attrs == other.attrs &&
          fg == other.fg &&
          bg == other.bg &&
          wide_padding == other.wide_padding
      end
    end

    class ScreenBuffer
      attr_reader :lines, :cols

      def initialize(lines, cols, dirty: false)
        @lines = lines
        @cols = cols
        # Use a NUL sentinel when dirty so flush_diff re-renders every cell,
        # including spaces, ensuring correct SGR across the whole screen.
        sentinel = dirty ? "\x00" : " "
        @cells = Array.new(lines) { Array.new(cols) { Cell.new(sentinel, 0, -1, -1, false) } }
      end

      def resize(lines, cols)
        @cells = Array.new(lines) { |y|
          Array.new(cols) { |x|
            if y < @lines && x < @cols
              @cells[y][x]
            else
              Cell.new(" ", 0, -1, -1, false)
            end
          }
        }
        @lines = lines
        @cols = cols
      end

      def [](y, x)
        @cells[y][x]
      end

      def []=(y, x, cell)
        @cells[y][x] = cell
      end

      def clear
        @lines.times do |y|
          @cols.times do |x|
            @cells[y][x] = Cell.new(" ", 0, -1, -1, false)
          end
        end
      end

      def clear_row(y)
        @cols.times do |x|
          @cells[y][x] = Cell.new(" ", 0, -1, -1, false)
        end
      end

      # Copy cells from src buffer region into this buffer at dest position
      def copy_from(src, src_y, src_x, dst_y, dst_x, height, width)
        height.times do |dy|
          sy = src_y + dy
          dy_dst = dst_y + dy
          next if sy >= src.lines || dy_dst >= @lines
          width.times do |dx|
            sx = src_x + dx
            dx_dst = dst_x + dx
            next if sx >= src.cols || dx_dst >= @cols
            @cells[dy_dst][dx_dst] = src[sy, sx].dup
          end
        end
      end

      # Compute diff and generate output to transform physical into this (virtual)
      def flush_diff(physical)
        output = +""
        cur_attrs = -1
        cur_fg = -2
        cur_bg = -2
        last_y = -1
        last_x = -1

        @lines.times do |y|
          x = 0
          while x < @cols
            vc = @cells[y][x]
            pc = physical[y, x]
            if vc != pc
              # Move cursor if not contiguous
              if y != last_y || x != last_x
                output << "\e[#{y + 1};#{x + 1}H"
              end
              # Set attributes if changed
              if vc.attrs != cur_attrs || vc.fg != cur_fg || vc.bg != cur_bg
                output << Terminal.sgr(vc.attrs, vc.fg, vc.bg)
                cur_attrs = vc.attrs
                cur_fg = vc.fg
                cur_bg = vc.bg
              end
              if vc.wide_padding
                # Skip padding cells (they follow a wide char)
                last_y = y
                last_x = x + 1
              else
                output << vc.char
                char_width = Buffer.display_width(vc.char)
                last_y = y
                last_x = x + char_width
              end
              # Update physical
              physical[y, x] = vc.dup
            end
            x += 1
          end
        end

        output
      end
    end
  end
end
