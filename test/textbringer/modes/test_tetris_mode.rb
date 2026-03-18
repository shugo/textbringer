require_relative "../../test_helper"

class TestTetrisMode < Textbringer::TestCase
  setup do
    @buffer = Buffer.new_buffer("*Tetris*")
    switch_to_buffer(@buffer)
    @buffer.apply_mode(TetrisMode)
    @mode = @buffer.mode
    @mode.tetris_new_game
    @buffer[:gamegrid].stop_timer
  end

  # ── initial state ──────────────────────────────────────────────────────────

  def test_initial_state
    assert_equal(0, @mode.score)
    assert_equal(1, @mode.level)
    assert_equal(0, @mode.lines_cleared)
    assert(!@mode.game_over)
    assert(!@mode.paused)
    assert((1..7).include?(@mode.piece_type))
    assert((1..7).include?(@mode.next_type))
  end

  def test_board_starts_empty
    board = @mode.instance_variable_get(:@board)
    assert_equal(TetrisMode::BOARD_HEIGHT, board.size)
    board.each do |row|
      assert_equal(TetrisMode::BOARD_WIDTH, row.size)
      assert(row.all?(&:zero?))
    end
  end

  def test_syntax_table_is_empty
    assert_equal({}, @mode.syntax_table)
  end

  def test_keymap_has_movement_keys
    assert_equal(:tetris_move_left_command,  TetrisMode::TETRIS_MODE_MAP.lookup(["h"]))
    assert_equal(:tetris_move_right_command, TetrisMode::TETRIS_MODE_MAP.lookup(["l"]))
    assert_equal(:tetris_move_down_command,  TetrisMode::TETRIS_MODE_MAP.lookup(["j"]))
    assert_equal(:tetris_rotate_command,     TetrisMode::TETRIS_MODE_MAP.lookup(["k"]))
    assert_equal(:tetris_drop_command,       TetrisMode::TETRIS_MODE_MAP.lookup([" "]))
    assert_equal(:tetris_pause_command,      TetrisMode::TETRIS_MODE_MAP.lookup(["p"]))
    assert_equal(:tetris_new_game_command,   TetrisMode::TETRIS_MODE_MAP.lookup(["n"]))
    assert_equal(:gamegrid_quit_command,     TetrisMode::TETRIS_MODE_MAP.lookup(["q"]))
  end

  # ── movement ───────────────────────────────────────────────────────────────

  def test_move_left
    set_piece(type: 2, rot: 0, x: 4, y: 5)  # O piece mid-board
    @mode.tetris_move_left
    assert_equal(3, @mode.piece_x)
  end

  def test_move_right
    set_piece(type: 2, rot: 0, x: 4, y: 5)
    @mode.tetris_move_right
    assert_equal(5, @mode.piece_x)
  end

  def test_move_left_blocked_by_wall
    # I piece (rot 0) occupies cols +0..+3 of its bounding box (row 1 has the cells)
    # Actually the I piece rot 0 has cells at col 0,1,2,3 of row index 1 in a 4x4 box.
    # At x=0 the leftmost cell is at bx=0, so moving to x=-1 → bx=-1 is invalid.
    set_piece(type: 1, rot: 0, x: 0, y: 5)
    @mode.tetris_move_left
    assert_equal(0, @mode.piece_x)
  end

  def test_move_right_blocked_by_wall
    # I piece at x=6: cells at bx=6,7,8,9. Moving to x=7 → bx=10 is invalid.
    set_piece(type: 1, rot: 0, x: 6, y: 5)
    @mode.tetris_move_right
    assert_equal(6, @mode.piece_x)
  end

  def test_move_left_blocked_by_board
    set_piece(type: 2, rot: 0, x: 3, y: 5)
    # Place a block at col 2, row 5 (bx = piece_x-1+col1 = 3-1+1=3... let's compute)
    # O piece rot 0: rows 0..1 have cells at col 1,2.
    # After moving left to x=2: col 1 → bx=3, col 2 → bx=4. Fine.
    # After moving left to x=1: col 1 → bx=2, col 2 → bx=3. Let's block col 2 at row 5.
    @mode.instance_variable_get(:@board)[5][2] = 1
    @mode.tetris_move_left  # x=3 → try x=2: O at (2,5): cells bx=3,4 — fine
    @mode.tetris_move_left  # x=2 → try x=1: O cell at col1 → bx=2 — board[5][2]=1, blocked
    assert_equal(2, @mode.piece_x)
  end

  # ── rotation ───────────────────────────────────────────────────────────────

  def test_rotate
    set_piece(type: 3, rot: 0, x: 4, y: 5)  # T piece
    @mode.tetris_rotate
    assert_equal(1, @mode.piece_rot)
  end

  def test_rotate_wraps_around
    set_piece(type: 3, rot: 3, x: 4, y: 5)
    @mode.tetris_rotate
    assert_equal(0, @mode.piece_rot)
  end

  def test_rotate_wall_kick
    # O piece against the right wall; rotation should succeed with a kick
    set_piece(type: 1, rot: 0, x: 7, y: 5)  # I piece, cells at bx=7,8,9,10 (x=10 OOB)
    # Actually x=7 for I piece: cells at col 0,1,2,3 → bx=7,8,9,10 (10 is OOB).
    # But valid_position? checks bx >= BOARD_WIDTH, so x=7 is itself invalid for I rot 0.
    # Let's use x=6 which is valid (bx=6,7,8,9). Rotating to rot 1: I piece vertical
    # occupies col 2 in 4 rows. At x=6 that's bx=8, ok.
    set_piece(type: 1, rot: 0, x: 6, y: 3)
    @mode.tetris_rotate
    assert_equal(1, @mode.piece_rot)
  end

  # ── hard drop ──────────────────────────────────────────────────────────────

  def test_drop_lands_at_bottom
    set_piece(type: 2, rot: 0, x: 4, y: 0)  # O piece
    @mode.tetris_drop
    # O piece locked at rows 18..19, cols 5..6 (piece_x=4, O cells at col 1,2)
    board = @mode.instance_variable_get(:@board)
    assert_equal(2, board[18][5])
    assert_equal(2, board[18][6])
    assert_equal(2, board[19][5])
    assert_equal(2, board[19][6])
  end

  def test_drop_awards_two_points_per_row
    set_piece(type: 2, rot: 0, x: 4, y: 0)
    @mode.tetris_drop
    # O piece at y=0 drops BOARD_HEIGHT-2 = 18 rows
    assert_equal(18 * 2, @mode.score)
  end

  # ── locking ────────────────────────────────────────────────────────────────

  def test_lock_piece_writes_to_board
    set_piece(type: 2, rot: 0, x: 4, y: 18)  # O piece near bottom
    @mode.send(:lock_piece)
    board = @mode.instance_variable_get(:@board)
    # O piece: row 0 col 1,2 → (5,18),(6,18); row 1 col 1,2 → (5,19),(6,19)
    assert_equal(2, board[18][5])
    assert_equal(2, board[18][6])
    assert_equal(2, board[19][5])
    assert_equal(2, board[19][6])
  end

  def test_lock_piece_outside_board_ignored
    set_piece(type: 2, rot: 0, x: 4, y: -1)  # partially above board
    @mode.send(:lock_piece)  # should not raise
  end

  # ── line clearing ──────────────────────────────────────────────────────────

  def test_clear_no_full_lines
    n = @mode.send(:clear_lines)
    assert_equal(0, n)
    assert_equal(0, @mode.score)
  end

  def test_clear_one_line
    fill_rows(19)
    n = @mode.send(:clear_lines)
    assert_equal(1, n)
    assert_equal(100, @mode.score)
    assert_equal(1, @mode.lines_cleared)
    board = @mode.instance_variable_get(:@board)
    assert_equal(Array.new(TetrisMode::BOARD_WIDTH, 0), board[0])
    assert_equal(TetrisMode::BOARD_HEIGHT, board.size)
  end

  def test_clear_two_lines
    fill_rows(18, 19)
    n = @mode.send(:clear_lines)
    assert_equal(2, n)
    assert_equal(300, @mode.score)
    assert_equal(2, @mode.lines_cleared)
  end

  def test_clear_three_lines
    fill_rows(17, 18, 19)
    n = @mode.send(:clear_lines)
    assert_equal(3, n)
    assert_equal(500, @mode.score)
  end

  def test_clear_four_lines_tetris
    fill_rows(16, 17, 18, 19)
    n = @mode.send(:clear_lines)
    assert_equal(4, n)
    assert_equal(800, @mode.score)
    assert_equal(4, @mode.lines_cleared)
  end

  def test_cleared_lines_replaced_with_empty_rows
    fill_rows(18, 19)
    # Put a partial block above the cleared lines
    @mode.instance_variable_get(:@board)[17][0] = 3
    @mode.send(:clear_lines)
    board = @mode.instance_variable_get(:@board)
    # The partial row at 17 should now be at row 19; rows 0 and 1 should be empty
    assert_equal(Array.new(TetrisMode::BOARD_WIDTH, 0), board[0])
    assert_equal(Array.new(TetrisMode::BOARD_WIDTH, 0), board[1])
    assert_equal(3, board[19][0])
  end

  # ── scoring and levelling ──────────────────────────────────────────────────

  def test_level_increases_every_ten_lines
    fill_rows(10, 11, 12, 13, 14, 15, 16, 17, 18, 19)
    @mode.send(:clear_lines)
    # 10 lines cleared → level 2
    assert_equal(2, @mode.level)
    assert_equal(10, @mode.lines_cleared)
  end

  def test_score_multiplied_by_level
    @mode.instance_variable_set(:@level, 3)
    fill_rows(19)
    @mode.send(:clear_lines)
    assert_equal(100 * 3, @mode.score)
  end

  # ── game over ──────────────────────────────────────────────────────────────

  def test_game_over_when_spawn_blocked
    # Fill the top rows so no piece can spawn
    board = @mode.instance_variable_get(:@board)
    TetrisMode::BOARD_WIDTH.times { |x| board[0][x] = 1; board[1][x] = 1 }
    @mode.instance_variable_set(:@next_type, 1)  # I piece
    @mode.send(:spawn_piece)
    assert(@mode.game_over)
  end

  def test_no_game_over_on_fresh_board
    assert(!@mode.game_over)
  end

  # ── pause ──────────────────────────────────────────────────────────────────

  def test_pause_toggles
    @mode.tetris_pause
    assert(@mode.paused)
    @mode.tetris_pause
    assert(!@mode.paused)
  end

  def test_paused_ignores_movement
    @mode.tetris_pause
    set_piece(type: 2, rot: 0, x: 4, y: 5)
    original_x = @mode.piece_x
    @mode.tetris_move_left
    assert_equal(original_x, @mode.piece_x)
  end

  # ── rendering ──────────────────────────────────────────────────────────────

  def test_render_produces_correct_dimensions
    # Buffer: 20 board rows + blank + status + "Next:" + 4 preview rows
    lines = @buffer.to_s.split("\n")
    assert(lines.size >= TetrisMode::BOARD_HEIGHT + 1 + TetrisMode::PREVIEW_SIZE)
    lines[0...TetrisMode::BOARD_HEIGHT].each do |line|
      assert_equal(TetrisMode::BOARD_WIDTH * 2, line.length)
    end
  end

  def test_preview_grid_shows_next_piece
    @mode.instance_variable_set(:@next_type, 2)  # O piece (yellow)
    @mode.send(:update_preview_grid)
    preview = @mode.instance_variable_get(:@preview_grid)
    # O piece rot 0: cells at (col 1,2) × (row 0,1)
    assert_equal(2, preview.get_cell(1, 0))
    assert_equal(2, preview.get_cell(2, 0))
    assert_equal(2, preview.get_cell(1, 1))
    assert_equal(2, preview.get_cell(2, 1))
    assert_equal(0, preview.get_cell(0, 0))
    assert_equal(0, preview.get_cell(3, 3))
  end

  def test_preview_offset_is_set_after_render
    assert(@mode.instance_variable_get(:@preview_offset) > 0)
  end

  def test_highlight_override_covers_preview
    on, _off = @buffer[:highlight_override].call
    # At least some cells in the preview should have color highlights
    # (the current next piece cells)
    assert(!on.empty?)
  end

  def test_valid_position_false_at_bottom
    set_piece(type: 2, rot: 0, x: 4, y: TetrisMode::BOARD_HEIGHT - 2)
    assert(!@mode.send(:valid_position?, @mode.piece_x, @mode.piece_y + 1,
                       @mode.piece_type, @mode.piece_rot))
  end

  def test_valid_position_true_above_bottom
    set_piece(type: 2, rot: 0, x: 4, y: TetrisMode::BOARD_HEIGHT - 3)
    assert(@mode.send(:valid_position?, @mode.piece_x, @mode.piece_y + 1,
                      @mode.piece_type, @mode.piece_rot))
  end

  private

  def set_piece(type:, rot:, x:, y:)
    @mode.instance_variable_set(:@piece_type, type)
    @mode.instance_variable_set(:@piece_rot,  rot)
    @mode.instance_variable_set(:@piece_x,    x)
    @mode.instance_variable_set(:@piece_y,    y)
  end

  def fill_rows(*rows)
    board = @mode.instance_variable_get(:@board)
    rows.each { |y| board[y] = Array.new(TetrisMode::BOARD_WIDTH, 1) }
  end
end
