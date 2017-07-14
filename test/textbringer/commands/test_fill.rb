require_relative "../../test_helper"

class TestBuffers < Textbringer::TestCase
  def test_fill_region
    buffer.insert(<<EOF)
## WARNING

Textbringer is beta software, and you may lose your text.  Unsaved buffers will be dumped in ~/.textbringer/buffer_dump on crash.
APIs are undocumented and unstable.  There is no compatibility even in the same minor versions.

## Installation
EOF
    buffer.beginning_of_buffer
    buffer.forward_line(2)
    set_mark_command
    buffer.end_of_line
    fill_region
    assert_equal(<<EOF, buffer.to_s)
## WARNING

Textbringer is beta software, and you may lose your text.  Unsaved
buffers will be dumped in ~/.textbringer/buffer_dump on crash.
APIs are undocumented and unstable.  There is no compatibility even in the same minor versions.

## Installation
EOF
  end

  def test_fill_region_insert_space
    set_mark_command
    buffer.insert(<<EOF)
foo bar
baz
EOF
    fill_region
    assert_equal(<<EOF, buffer.to_s)
foo bar baz
EOF
  end

  def test_fill_region_japanese
    set_mark_command
    buffer.insert("あ" * 105)
    fill_region
    assert_equal(3.times.map { "あ" * 35 }.join("\n"), buffer.to_s)
  end

  def test_fill_region_join_japanese
    set_mark_command
    6.times do
      buffer.insert("あ" * 10 + "\n")
    end
    fill_region
    assert_equal(<<EOF, buffer.to_s)
あああああああああああああああああああああああああああああああああああ
あああああああああああああああああああああああああ
EOF
  end

  def test_fill_region_join_comma
    set_mark_command
    buffer.insert(<<EOF)
foo bar,
baz quux.
EOF
    fill_region
    assert_equal(<<EOF, buffer.to_s)
foo bar, baz quux.
EOF
  end

  def test_fill_region_join_period
    set_mark_command
    buffer.insert(<<EOF)
foo bar.
baz quux.
EOF
    fill_region
#    assert_equal(<<EOF, buffer.to_s)
#foo bar.  baz quux.
#EOF
    assert_equal(<<EOF, buffer.to_s)
foo bar. baz quux.
EOF
  end

  def test_fill_region_join_comma_and_japanese
    set_mark_command
    buffer.insert(<<EOF)
foo bar,
ふがふが。
EOF
    fill_region
    assert_equal(<<EOF, buffer.to_s)
foo bar,ふがふが。
EOF
  end

  def test_fill_region_join_period_and_japanese
    set_mark_command
    buffer.insert(<<EOF)
foo bar.
ふがふが。
EOF
    fill_region
    assert_equal(<<EOF, buffer.to_s)
foo bar.ふがふが。
EOF
  end

  def test_fill_paragraph
    buffer.insert(<<EOF)
## WARNING

Textbringer is beta software, and you may lose your text.  Unsaved buffers will be dumped in ~/.textbringer/buffer_dump on crash.
APIs are undocumented and unstable.  There is no compatibility even in the same minor versions.

## Installation
EOF
    buffer.beginning_of_buffer
    buffer.forward_line(2)
    fill_paragraph
    assert_equal(<<EOF, buffer.to_s)
## WARNING

Textbringer is beta software, and you may lose your text.  Unsaved
buffers will be dumped in ~/.textbringer/buffer_dump on crash. APIs
are undocumented and unstable.  There is no compatibility even in the
same minor versions.

## Installation
EOF
  end
end
