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
buffers will be dumped in ~/.textbringer/buffer_dump on crash.APIs are
undocumented and unstable.  There is no compatibility even in the same
minor versions.

## Installation
EOF
  end
end
