require_relative "../../test_helper"

class TestTerminalInput < Test::Unit::TestCase
  def setup
    @read_io, @write_io = IO.pipe
    @reader = Textbringer::Terminal::Input::Reader.new(@read_io)
    @reader.escape_timeout = 0.01
  end

  def teardown
    @read_io.close unless @read_io.closed?
    @write_io.close unless @write_io.closed?
  end

  def test_read_ascii
    @write_io.write("a")
    assert_equal("a", @reader.get_char)
  end

  def test_read_control_char
    @write_io.write("\C-a")
    assert_equal("\C-a", @reader.get_char)
  end

  def test_read_standalone_escape
    @write_io.write("\e")
    assert_equal("\e", @reader.get_char)
  end

  def test_read_csi_arrow_keys
    key_codes = Textbringer::Terminal::Input::KEY_CODES

    @write_io.write("\e[A")
    assert_equal(key_codes[:up], @reader.get_char)

    @write_io.write("\e[B")
    assert_equal(key_codes[:down], @reader.get_char)

    @write_io.write("\e[C")
    assert_equal(key_codes[:right], @reader.get_char)

    @write_io.write("\e[D")
    assert_equal(key_codes[:left], @reader.get_char)
  end

  def test_read_csi_home_end
    key_codes = Textbringer::Terminal::Input::KEY_CODES

    @write_io.write("\e[H")
    assert_equal(key_codes[:home], @reader.get_char)

    @write_io.write("\e[F")
    assert_equal(key_codes[:end], @reader.get_char)
  end

  def test_read_csi_tilde_keys
    key_codes = Textbringer::Terminal::Input::KEY_CODES

    @write_io.write("\e[2~")
    assert_equal(key_codes[:ic], @reader.get_char)

    @write_io.write("\e[3~")
    assert_equal(key_codes[:dc], @reader.get_char)

    @write_io.write("\e[5~")
    assert_equal(key_codes[:ppage], @reader.get_char)

    @write_io.write("\e[6~")
    assert_equal(key_codes[:npage], @reader.get_char)
  end

  def test_read_function_keys_via_csi
    key_codes = Textbringer::Terminal::Input::KEY_CODES

    @write_io.write("\e[11~")
    assert_equal(key_codes[:f1], @reader.get_char)

    @write_io.write("\e[15~")
    assert_equal(key_codes[:f5], @reader.get_char)

    @write_io.write("\e[24~")
    assert_equal(key_codes[:f12], @reader.get_char)
  end

  def test_read_ss3_keys
    key_codes = Textbringer::Terminal::Input::KEY_CODES

    @write_io.write("\eOP")
    assert_equal(key_codes[:f1], @reader.get_char)

    @write_io.write("\eOQ")
    assert_equal(key_codes[:f2], @reader.get_char)

    @write_io.write("\eOH")
    assert_equal(key_codes[:home], @reader.get_char)

    @write_io.write("\eOF")
    assert_equal(key_codes[:end], @reader.get_char)
  end

  def test_read_alt_key
    # Alt+a sends ESC followed by 'a'
    @write_io.write("\ea")
    result = @reader.get_char
    # Should return ESC (the 'a' is buffered for next read)
    assert_equal("\e", result)
    assert_equal("a", @reader.get_char)
  end

  def test_read_utf8
    @write_io.write("あ")
    assert_equal("あ", @reader.get_char)

    @write_io.write("漢")
    assert_equal("漢", @reader.get_char)
  end

  def test_read_nonblocking
    result = @reader.get_char(blocking: false)
    assert_nil(result)

    @write_io.write("x")
    result = @reader.get_char(blocking: false)
    assert_equal("x", result)
  end

  def test_read_with_timeout
    result = @reader.get_char(timeout_ms: 10)
    assert_nil(result)

    @write_io.write("y")
    result = @reader.get_char(timeout_ms: 100)
    assert_equal("y", result)
  end

  def test_read_shift_tab
    key_codes = Textbringer::Terminal::Input::KEY_CODES
    @write_io.write("\e[Z")
    assert_equal(key_codes[:btab], @reader.get_char)
  end

  def test_key_names_mapping
    key_names = Textbringer::Terminal::Input::KEY_NAMES
    key_codes = Textbringer::Terminal::Input::KEY_CODES

    assert_equal(:up, key_names[key_codes[:up]])
    assert_equal(:down, key_names[key_codes[:down]])
    assert_equal(:left, key_names[key_codes[:left]])
    assert_equal(:right, key_names[key_codes[:right]])
    assert_equal(:home, key_names[key_codes[:home]])
    assert_equal(:end, key_names[key_codes[:end]])
    assert_equal(:dc, key_names[key_codes[:dc]])
    assert_equal(:ppage, key_names[key_codes[:ppage]])
    assert_equal(:npage, key_names[key_codes[:npage]])
    assert_equal(:f1, key_names[key_codes[:f1]])
    assert_equal(:f12, key_names[key_codes[:f12]])
  end
end
