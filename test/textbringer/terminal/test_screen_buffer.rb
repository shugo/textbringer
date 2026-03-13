require_relative "../../test_helper"

class TestScreenBuffer < Test::Unit::TestCase
  def setup
    @buffer = Textbringer::Terminal::ScreenBuffer.new(3, 5)
  end

  def test_initialize
    assert_equal(3, @buffer.lines)
    assert_equal(5, @buffer.cols)
    cell = @buffer[0, 0]
    assert_equal(" ", cell.char)
    assert_equal(0, cell.attrs)
    assert_equal(-1, cell.fg)
    assert_equal(-1, cell.bg)
    assert_equal(false, cell.wide_padding)
  end

  def test_set_and_get_cell
    cell = Textbringer::Terminal::Cell.new("X", 0, 1, 2, false)
    @buffer[1, 3] = cell
    assert_equal("X", @buffer[1, 3].char)
    assert_equal(1, @buffer[1, 3].fg)
    assert_equal(2, @buffer[1, 3].bg)
  end

  def test_clear
    @buffer[0, 0] = Textbringer::Terminal::Cell.new("A", 0, 1, 2, false)
    @buffer.clear
    assert_equal(" ", @buffer[0, 0].char)
    assert_equal(-1, @buffer[0, 0].fg)
  end

  def test_clear_row
    @buffer[1, 0] = Textbringer::Terminal::Cell.new("B", 0, 3, 4, false)
    @buffer[1, 1] = Textbringer::Terminal::Cell.new("C", 0, 3, 4, false)
    @buffer.clear_row(1)
    assert_equal(" ", @buffer[1, 0].char)
    assert_equal(" ", @buffer[1, 1].char)
  end

  def test_resize
    @buffer[0, 0] = Textbringer::Terminal::Cell.new("Z", 0, 5, 6, false)
    @buffer.resize(4, 6)
    assert_equal(4, @buffer.lines)
    assert_equal(6, @buffer.cols)
    # Old content preserved
    assert_equal("Z", @buffer[0, 0].char)
    # New cells are blank
    assert_equal(" ", @buffer[3, 5].char)
  end

  def test_copy_from
    src = Textbringer::Terminal::ScreenBuffer.new(2, 3)
    src[0, 0] = Textbringer::Terminal::Cell.new("A", 0, -1, -1, false)
    src[0, 1] = Textbringer::Terminal::Cell.new("B", 0, -1, -1, false)
    src[1, 0] = Textbringer::Terminal::Cell.new("C", 0, -1, -1, false)

    @buffer.copy_from(src, 0, 0, 1, 1, 2, 2)
    assert_equal("A", @buffer[1, 1].char)
    assert_equal("B", @buffer[1, 2].char)
    assert_equal("C", @buffer[2, 1].char)
  end

  def test_flush_diff_no_changes
    physical = Textbringer::Terminal::ScreenBuffer.new(3, 5)
    output = @buffer.flush_diff(physical)
    assert_equal("", output)
  end

  def test_flush_diff_with_changes
    physical = Textbringer::Terminal::ScreenBuffer.new(3, 5)
    @buffer[0, 0] = Textbringer::Terminal::Cell.new("X", 0, -1, -1, false)
    output = @buffer.flush_diff(physical)
    assert_match(/X/, output)
    # Physical should now match virtual
    assert_equal("X", physical[0, 0].char)
  end

  def test_flush_diff_cursor_positioning
    physical = Textbringer::Terminal::ScreenBuffer.new(3, 5)
    @buffer[1, 2] = Textbringer::Terminal::Cell.new("Y", 0, -1, -1, false)
    output = @buffer.flush_diff(physical)
    # Should contain cursor positioning for row 2, col 3 (1-indexed)
    assert_match(/\e\[2;3H/, output)
  end

  def test_flush_diff_attributes
    physical = Textbringer::Terminal::ScreenBuffer.new(3, 5)
    @buffer[0, 0] = Textbringer::Terminal::Cell.new("B",
      Textbringer::Terminal::A_BOLD, 1, -1, false)
    output = @buffer.flush_diff(physical)
    # Should contain SGR sequence with bold
    assert_match(/\e\[/, output)
    assert_match(/B/, output)
  end

  def test_cell_equality
    cell1 = Textbringer::Terminal::Cell.new("A", 0, -1, -1, false)
    cell2 = Textbringer::Terminal::Cell.new("A", 0, -1, -1, false)
    cell3 = Textbringer::Terminal::Cell.new("B", 0, -1, -1, false)

    assert_equal(cell1, cell2)
    assert_not_equal(cell1, cell3)
  end
end
