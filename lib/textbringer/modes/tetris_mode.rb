module Textbringer
  class TetrisMode < GamegridMode
    BOARD_WIDTH  = 10
    BOARD_HEIGHT = 20

    PIECE_COLORS = {
      1 => :gamegrid_block_cyan,
      2 => :gamegrid_block_yellow,
      3 => :gamegrid_block_magenta,
      4 => :gamegrid_block_green,
      5 => :gamegrid_block_red,
      6 => :gamegrid_block_blue,
      7 => :gamegrid_block_white,
    }.freeze

    PIECE_NAMES = ["", "I", "O", "T", "S", "Z", "J", "L"].freeze

    # Pieces[type][rotation][row][col] — 4×4 bounding box, 1-indexed types
    PIECES = [
      nil,
      # 1: I (cyan)
      [
        [[0,0,0,0],[1,1,1,1],[0,0,0,0],[0,0,0,0]],
        [[0,0,1,0],[0,0,1,0],[0,0,1,0],[0,0,1,0]],
        [[0,0,0,0],[0,0,0,0],[1,1,1,1],[0,0,0,0]],
        [[0,1,0,0],[0,1,0,0],[0,1,0,0],[0,1,0,0]],
      ],
      # 2: O (yellow)
      [
        [[0,1,1,0],[0,1,1,0],[0,0,0,0],[0,0,0,0]],
        [[0,1,1,0],[0,1,1,0],[0,0,0,0],[0,0,0,0]],
        [[0,1,1,0],[0,1,1,0],[0,0,0,0],[0,0,0,0]],
        [[0,1,1,0],[0,1,1,0],[0,0,0,0],[0,0,0,0]],
      ],
      # 3: T (magenta)
      [
        [[0,1,0,0],[1,1,1,0],[0,0,0,0],[0,0,0,0]],
        [[0,1,0,0],[0,1,1,0],[0,1,0,0],[0,0,0,0]],
        [[0,0,0,0],[1,1,1,0],[0,1,0,0],[0,0,0,0]],
        [[0,1,0,0],[1,1,0,0],[0,1,0,0],[0,0,0,0]],
      ],
      # 4: S (green)
      [
        [[0,1,1,0],[1,1,0,0],[0,0,0,0],[0,0,0,0]],
        [[1,0,0,0],[1,1,0,0],[0,1,0,0],[0,0,0,0]],
        [[0,1,1,0],[1,1,0,0],[0,0,0,0],[0,0,0,0]],
        [[1,0,0,0],[1,1,0,0],[0,1,0,0],[0,0,0,0]],
      ],
      # 5: Z (red)
      [
        [[1,1,0,0],[0,1,1,0],[0,0,0,0],[0,0,0,0]],
        [[0,0,1,0],[0,1,1,0],[0,1,0,0],[0,0,0,0]],
        [[1,1,0,0],[0,1,1,0],[0,0,0,0],[0,0,0,0]],
        [[0,0,1,0],[0,1,1,0],[0,1,0,0],[0,0,0,0]],
      ],
      # 6: J (blue)
      [
        [[1,0,0,0],[1,1,1,0],[0,0,0,0],[0,0,0,0]],
        [[0,1,1,0],[0,1,0,0],[0,1,0,0],[0,0,0,0]],
        [[0,0,0,0],[1,1,1,0],[0,0,1,0],[0,0,0,0]],
        [[0,1,0,0],[0,1,0,0],[1,1,0,0],[0,0,0,0]],
      ],
      # 7: L (white)
      [
        [[0,0,1,0],[1,1,1,0],[0,0,0,0],[0,0,0,0]],
        [[0,1,0,0],[0,1,0,0],[0,1,1,0],[0,0,0,0]],
        [[0,0,0,0],[1,1,1,0],[1,0,0,0],[0,0,0,0]],
        [[1,1,0,0],[0,1,0,0],[0,1,0,0],[0,0,0,0]],
      ],
    ].freeze

    define_keymap :TETRIS_MODE_MAP
    TETRIS_MODE_MAP.define_key("q",    :gamegrid_quit_command)
    TETRIS_MODE_MAP.define_key("n",    :tetris_new_game_command)
    TETRIS_MODE_MAP.define_key(:left,  :tetris_move_left_command)
    TETRIS_MODE_MAP.define_key("h",    :tetris_move_left_command)
    TETRIS_MODE_MAP.define_key(:right, :tetris_move_right_command)
    TETRIS_MODE_MAP.define_key("l",    :tetris_move_right_command)
    TETRIS_MODE_MAP.define_key(:down,  :tetris_move_down_command)
    TETRIS_MODE_MAP.define_key("j",    :tetris_move_down_command)
    TETRIS_MODE_MAP.define_key(:up,    :tetris_rotate_command)
    TETRIS_MODE_MAP.define_key("k",    :tetris_rotate_command)
    TETRIS_MODE_MAP.define_key(" ",    :tetris_drop_command)
    TETRIS_MODE_MAP.define_key("p",    :tetris_pause_command)

    attr_reader :score, :level, :lines_cleared,
                :piece_type, :piece_rot, :piece_x, :piece_y,
                :next_type, :game_over, :paused

    def initialize(buffer)
      super
      buffer.keymap = TETRIS_MODE_MAP
      @game_over = true
      @paused    = false
      @grid      = nil
    end

    define_local_command(:tetris_new_game, doc: "Start a new Tetris game.") do
      @grid&.stop_timer
      @grid = gamegrid_init(BOARD_WIDTH, BOARD_HEIGHT)
      @grid.set_display_option(0, char: "  ")
      PIECE_COLORS.each { |v, f| @grid.set_display_option(v, char: "[]", face: f) }

      @board         = Array.new(BOARD_HEIGHT) { Array.new(BOARD_WIDTH, 0) }
      @score         = 0
      @level         = 1
      @lines_cleared = 0
      @game_over     = false
      @paused        = false
      @next_type     = random_piece_type

      spawn_piece
      start_game_timer unless @game_over
      render_board
    end

    define_local_command(:tetris_move_left, doc: "Move piece left.") do
      return unless active?
      if valid_position?(@piece_x - 1, @piece_y, @piece_type, @piece_rot)
        @piece_x -= 1
        render_board
      end
    end

    define_local_command(:tetris_move_right, doc: "Move piece right.") do
      return unless active?
      if valid_position?(@piece_x + 1, @piece_y, @piece_type, @piece_rot)
        @piece_x += 1
        render_board
      end
    end

    define_local_command(:tetris_move_down, doc: "Soft-drop current piece.") do
      return unless active?
      step_down
    end

    define_local_command(:tetris_rotate, doc: "Rotate current piece clockwise.") do
      return unless active?
      new_rot = (@piece_rot + 1) % 4
      # Try basic rotation then simple wall-kicks (±1, ±2 columns)
      [0, -1, 1, -2, 2].each do |kick|
        if valid_position?(@piece_x + kick, @piece_y, @piece_type, new_rot)
          @piece_x  += kick
          @piece_rot = new_rot
          break
        end
      end
      render_board
    end

    define_local_command(:tetris_drop, doc: "Hard-drop current piece.") do
      return unless active?
      while valid_position?(@piece_x, @piece_y + 1, @piece_type, @piece_rot)
        @piece_y += 1
        @score   += 2
      end
      lock_and_continue
      render_board
    end

    define_local_command(:tetris_pause, doc: "Toggle game pause.") do
      return if @game_over || !@grid
      @paused = !@paused
      if @paused
        @grid.stop_timer
      else
        start_game_timer
      end
      render_board
    end

    private

    def active?
      !@game_over && !@paused && @grid
    end

    def random_piece_type
      rand(1..7)
    end

    def spawn_piece
      @piece_type = @next_type
      @next_type  = random_piece_type
      @piece_rot  = 0
      @piece_x    = BOARD_WIDTH / 2 - 2
      @piece_y    = 0
      @game_over  = !valid_position?(@piece_x, @piece_y, @piece_type, @piece_rot)
    end

    def valid_position?(x, y, type, rot)
      PIECES[type][rot].each_with_index do |row, row_i|
        row.each_with_index do |cell, col_i|
          next if cell == 0
          bx = x + col_i
          by = y + row_i
          return false if bx < 0 || bx >= BOARD_WIDTH
          return false if by >= BOARD_HEIGHT
          next if by < 0  # piece can start partially above the board
          return false if @board[by][bx] != 0
        end
      end
      true
    end

    def lock_piece
      PIECES[@piece_type][@piece_rot].each_with_index do |row, row_i|
        row.each_with_index do |cell, col_i|
          next if cell == 0
          by = @piece_y + row_i
          bx = @piece_x + col_i
          next if by < 0 || by >= BOARD_HEIGHT || bx < 0 || bx >= BOARD_WIDTH
          @board[by][bx] = @piece_type
        end
      end
    end

    def clear_lines
      full = (0...BOARD_HEIGHT).select { |y| @board[y].all? { |c| c != 0 } }
      return 0 if full.empty?
      full.reverse_each { |y| @board.delete_at(y) }
      full.size.times { @board.unshift(Array.new(BOARD_WIDTH, 0)) }
      n = full.size
      @score         += [0, 100, 300, 500, 800][n].to_i * @level
      @lines_cleared += n
      @level          = @lines_cleared / 10 + 1
      n
    end

    def step_down
      if valid_position?(@piece_x, @piece_y + 1, @piece_type, @piece_rot)
        @piece_y += 1
      else
        lock_and_continue
      end
      render_board
    end

    def lock_and_continue
      lock_piece
      clear_lines
      spawn_piece
      if @game_over
        @grid.stop_timer
      else
        start_game_timer
      end
    end

    def start_game_timer
      @grid.start_timer(timer_interval) { step_down }
    end

    def timer_interval
      # Level 1 = 1.0 s, each level adds 0.1 s speed, floor at 0.1 s
      [1.0 - (@level - 1) * 0.1, 0.1].max
    end

    def update_grid
      BOARD_HEIGHT.times do |y|
        BOARD_WIDTH.times do |x|
          @grid.set_cell(x, y, @board[y][x])
        end
      end
      return if @game_over
      PIECES[@piece_type][@piece_rot].each_with_index do |row, row_i|
        row.each_with_index do |cell, col_i|
          next if cell == 0
          bx = @piece_x + col_i
          by = @piece_y + row_i
          next if bx < 0 || bx >= BOARD_WIDTH || by < 0 || by >= BOARD_HEIGHT
          @grid.set_cell(bx, by, @piece_type)
        end
      end
    end

    def render_board
      update_grid
      @buffer.read_only_edit do
        @buffer.clear
        @buffer.insert(@grid.render)
        @buffer.insert("\n")
        @buffer.insert(status_text)
        @buffer.beginning_of_buffer
      end
    end

    def status_text
      if @game_over
        "GAME OVER  Score: #{@score}  Level: #{@level}  Lines: #{@lines_cleared}" \
          "  [n]ew game  [q]uit\n"
      elsif @paused
        "PAUSED  Score: #{@score}  Level: #{@level}  Lines: #{@lines_cleared}" \
          "  [p] resume\n"
      else
        "Score: #{@score}  Level: #{@level}  Lines: #{@lines_cleared}" \
          "  Next: #{PIECE_NAMES[@next_type]}\n"
      end
    end
  end
end
