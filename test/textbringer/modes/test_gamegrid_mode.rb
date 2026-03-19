require_relative "../../test_helper"

class TestGamegridMode < Textbringer::TestCase
  setup do
    @buffer = Buffer.new_buffer("*TestGame*")
    switch_to_buffer(@buffer)
    @buffer.apply_mode(GamegridMode)
    @mode = @buffer.mode
  end

  def test_gamegrid_init
    grid = @mode.gamegrid_init(10, 5)
    assert_instance_of(Gamegrid, grid)
    assert_equal(10, grid.width)
    assert_equal(5, grid.height)
    assert_equal(grid, @buffer[:gamegrid])
    assert(@buffer.read_only?)
    assert_not_nil(@buffer[:highlight_override])
  end

  def test_gamegrid_refresh
    grid = @mode.gamegrid_init(3, 2)
    grid.set_display_option(0, char: ".")
    grid.set_cell(1, 0, 1)
    grid.set_display_option(1, char: "#")
    @mode.gamegrid_refresh
    assert_equal(".#.\n...", @buffer.to_s)
  end

  def test_gamegrid_quit
    grid = @mode.gamegrid_init(3, 2)
    grid.start_timer(1.0) {}
    assert(grid.timer_active?)
    @mode.gamegrid_quit
    assert(!grid.timer_active?)
  end

  def test_syntax_table_is_empty
    assert_equal({}, @mode.syntax_table)
  end

  def test_highlight_override
    grid = @mode.gamegrid_init(2, 1)
    grid.set_display_option(1, char: "#", face: :gamegrid_red)
    grid.set_cell(0, 0, 1)
    @mode.gamegrid_refresh

    override = @buffer[:highlight_override]
    highlight_on, highlight_off = override.call(Window.current)
    assert_equal(Face[:gamegrid_red], highlight_on[0])
    assert_equal(true, highlight_off[1])
  end

  def test_keymap_has_quit
    cmd = GamegridMode::GAMEGRID_MODE_MAP.lookup(["q"])
    assert_equal(:gamegrid_quit_command, cmd)
  end
end
