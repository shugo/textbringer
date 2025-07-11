require_relative "../../test_helper"

using Textbringer::Buffer::RectangleMethods

class TestBuffers < Textbringer::TestCase
  def test_rectangle_boundaries
    buffer = Buffer.current
    insert("Hello World\nThis is line 2\nAnd line 3 here\nFinal line")
    
    # Set mark at position 5 (column 6, line 1) and point at position 37 (column 11, line 3)
    buffer.goto_char(5)
    set_mark_command
    buffer.goto_char(37)
    
    start_line, start_col, end_line, end_col = buffer.rectangle_boundaries
    assert_equal(1, start_line)
    assert_equal(5, start_col)
    assert_equal(3, end_line)
    assert_equal(10, end_col)
  end

  def test_extract_rectangle
    buffer = Buffer.current
    insert("Hello World\nThis is line 2\nAnd line 3 here\nFinal line")
    
    # Set up rectangle from column 6 to 11, lines 1 to 3
    buffer.goto_char(5)  # Column 6, line 1
    set_mark_command
    buffer.goto_char(37) # Column 11, line 3
    
    lines = buffer.extract_rectangle
    assert_equal([" Worl", "is li", "ine 3"], lines)
  end

  def test_copy_rectangle_as_kill
    buffer = Buffer.current
    insert("Hello World\nThis is line 2\nAnd line 3 here\nFinal line")
    
    # Set up rectangle from column 6 to 11, lines 1 to 3
    buffer.goto_char(5)  # Column 6, line 1
    set_mark_command
    buffer.goto_char(37) # Column 11, line 3
    
    copy_rectangle_as_kill
    
    # Check that the rectangle was copied to rectangle kill ring
    lines = Textbringer::Buffer::RectangleMethods::SHARED_VALUES[:killed_rectangle]
    assert_equal([" Worl", "is li", "ine 3"], lines)
    
    # Verify original text is unchanged
    assert_equal("Hello World\nThis is line 2\nAnd line 3 here\nFinal line", buffer.to_s)
  end

  def test_kill_rectangle
    buffer = Buffer.current
    initial = "Hello World\nThis is line 2\nAnd line 3 here\nFinal line"
    insert(initial)
    
    # Set up rectangle from column 6 to 11, lines 1 to 3
    buffer.goto_char(5)  # Column 6, line 1
    set_mark_command
    buffer.goto_char(37) # Column 11, line 3
    
    kill_rectangle
    
    # Check that the rectangle was copied to rectangle kill ring
    lines = Textbringer::Buffer::RectangleMethods::SHARED_VALUES[:killed_rectangle]
    assert_equal([" Worl", "is li", "ine 3"], lines)
    
    # Verify rectangle was deleted from buffer
    expected = "Hellod\nThis ne 2\nAnd l here\nFinal line"
    assert_equal(expected, buffer.to_s)

    undo

    assert_equal(initial, buffer.to_s)
  end

  def test_delete_rectangle
    buffer = Buffer.current
    initial = "Hello World\nThis is line 2\nAnd line 3 here\nFinal line"
    insert(initial)
    
    # Set up rectangle from column 6 to 11, lines 1 to 3
    buffer.goto_char(5)  # Column 6, line 1
    set_mark_command
    buffer.goto_char(37) # Column 11, line 3
    
    delete_rectangle
    
    # Verify rectangle was deleted from buffer
    expected = "Hellod\nThis ne 2\nAnd l here\nFinal line"
    assert_equal(expected, buffer.to_s)

    undo

    assert_equal(initial, buffer.to_s)
  end

  def test_yank_rectangle
    buffer = Buffer.current
    insert("Hello World\nThis is line 2\nAnd line 3 here\nFinal line")
    
    # Set up and copy a rectangle
    buffer.goto_char(5)  # Column 6, line 1
    set_mark_command
    buffer.goto_char(37) # Column 11, line 3
    copy_rectangle_as_kill
    
    # Clear buffer and test yank
    buffer.clear
    before_yank = "AAAAA\nBBBBB\nCCCCC\nDDDDD"
    insert(before_yank)
    
    # Yank rectangle at column 2, line 2
    buffer.goto_char(7)  # Column 2, line 2
    yank_rectangle
    
    expected = "AAAAA\nB WorlBBBB\nCis liCCCC\nDine 3DDDD"
    assert_equal(expected, buffer.to_s)
    assert_equal(34, buffer.point) # Column 7, line 4

    undo

    assert_equal(before_yank, buffer.to_s)
    assert_equal(7, buffer.point) # Column 2, line 2
  end

  def test_open_rectangle
    buffer = Buffer.current
    initial = "Hello World\nThis is line 2\nAnd line 3 here\nFinal line"
    insert(initial)
    
    # Set up rectangle from column 6 to 11, lines 1 to 3
    buffer.goto_char(5)  # Column 6, line 1
    set_mark_command
    buffer.goto_char(37) # Column 11, line 3
    
    open_rectangle
    
    # Verify spaces were inserted
    expected = "Hello      World\nThis      is line 2\nAnd l     ine 3 here\nFinal line"
    assert_equal(expected, buffer.to_s)
    assert_equal(5, buffer.point) # Column 6, line 1

    undo

    assert_equal(initial, buffer.to_s)
    assert_equal(37, buffer.point) # Column 11, line 3
  end

  def test_rectangle_edge_cases
    buffer = Buffer.current
    # Test rectangle extending beyond short lines
    insert("AB\nABCDEF\nABC\nABCDEFGHIJ")
    
    # Set up rectangle from column 4 to 7, covering lines with different lengths
    buffer.goto_char(6)  # Column 4, line 2 (in "ABCDEF")
    set_mark_command
    buffer.goto_char(buffer.to_s.length - 4)  # Column 7, line 4
    
    lines = buffer.extract_rectangle
    assert_equal(["DEF", "   ", "DEF"], lines)
    
    # Test copy and yank with edge case
    copy_rectangle_as_kill
    buffer.clear
    insert("XXXXX\nYYYYY\nZZZZZ")
    buffer.goto_char(2)  # Column 3, line 1
    yank_rectangle
    
    expected = "XXDEFXXX\nYY   YYY\nZZDEFZZZ"
    assert_equal(expected, buffer.to_s)
  end

  def test_rectangle_multibyte
    buffer = Buffer.current
    insert(<<~EOF)
      あいうえお
      かきくけこ
    EOF
    beginning_of_buffer
    forward_char
    set_mark_command
    next_line
    forward_char(3)
    lines = buffer.extract_rectangle
    assert_equal(["いうえ", "きくけ"], lines)
  end

  def test_clear_rectangle
    buffer = Buffer.current
    initial = "Hello World\nThis is line 2\nAnd line 3 here\nFinal line"
    insert(initial)
    
    # Set up rectangle from column 6 to 11, lines 1 to 3
    buffer.goto_char(5)  # Column 6, line 1
    set_mark_command
    buffer.goto_char(37) # Column 11, line 3
    
    clear_rectangle
    
    # Verify rectangle was replaced with spaces
    expected = "Hello     d\nThis      ne 2\nAnd l      here\nFinal line"
    assert_equal(expected, buffer.to_s)

    undo

    assert_equal(initial, buffer.to_s)
  end

  def test_clear_rectangle_with_short_lines
    buffer = Buffer.current
    initial = "L1\nL2-long\nL3\nL4-very-long"
    insert(initial)
    
    # Rectangle from line 2, col 4 to line 4, col 7
    buffer.goto_line(2)
    buffer.forward_char(3) # col 4
    set_mark_command
    buffer.goto_line(4)
    buffer.forward_char(6) # col 7

    clear_rectangle

    expected = "L1\nL2-   g\nL3   \nL4-   y-long"
    assert_equal(expected, buffer.to_s)

    undo
    assert_equal(initial, buffer.to_s)
  end

  def test_string_rectangle
    insert(<<-EOF)
foo
bar
baz
quux
    EOF
    beginning_of_buffer
    forward_char
    set_mark_command
    next_line(2)
    forward_char
    push_keys("inserted\n")
    string_rectangle
    assert_equal(<<-EOF, Buffer.current.to_s)
finsertedo
binsertedr
binsertedz
quux
    EOF

    Buffer.current.clear
    insert(<<-EOF)
foo

bar
baz
    EOF

    beginning_of_buffer
    forward_char
    set_mark_command
    next_line(2)
    forward_char
    push_keys("X\n")
    string_rectangle
    assert_equal(<<-EOF, Buffer.current.to_s)
fXo
 X
bXr
baz
    EOF
  end

  def test_string_insert_rectangle
    insert(<<-EOF)
foo
bar
baz
quux
    EOF
    beginning_of_buffer
    forward_char
    set_mark_command
    next_line(2)
    forward_char
    push_keys("inserted\n")
    string_insert_rectangle
    assert_equal(<<-EOF, Buffer.current.to_s)
finsertedoo
binsertedar
binsertedaz
quux
    EOF

    Buffer.current.clear
    insert(<<-EOF)
foo

bar
baz
    EOF

    beginning_of_buffer
    forward_char
    set_mark_command
    next_line(2)
    forward_char
    push_keys("X\n")
    string_insert_rectangle
    assert_equal(<<-EOF, Buffer.current.to_s)
fXoo
 X
bXar
baz
    EOF
  end

  def test_rectangle_number_lines
    insert(<<-EOF)
 foo
 bar
 baz
 quux
 quuux
    EOF
    beginning_of_buffer
    next_line
    forward_char
    set_mark_command
    next_line(2)
    forward_char
    rectangle_number_lines
    assert_equal(<<-EOF, Buffer.current.to_s)
 foo
 1 bar
 2 baz
 3 quux
 quuux
    EOF

    Buffer.current.clear
    insert(<<-EOF)
foo
bar
baz
quux
quuux
quuux
quuuux
quuuuux
quuuuuux
    EOF
    beginning_of_buffer
    set_mark_command
    next_line(8)
    rectangle_number_lines
    assert_equal(<<-EOF, Buffer.current.to_s)
1 foo
2 bar
3 baz
4 quux
5 quuux
6 quuux
7 quuuux
8 quuuuux
9 quuuuuux
    EOF

    Buffer.current.clear
    insert(<<-EOF)
foo
bar
baz
quux
quuux
quuux
quuuux
quuuuux
quuuuuux
quuuuuuux
    EOF
    beginning_of_buffer
    set_mark_command
    next_line(9)
    rectangle_number_lines
    assert_equal(<<-EOF, Buffer.current.to_s)
 1 foo
 2 bar
 3 baz
 4 quux
 5 quuux
 6 quuux
 7 quuuux
 8 quuuuux
 9 quuuuuux
10 quuuuuuux
    EOF
  end
end
