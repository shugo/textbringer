require_relative "../../test_helper"

class TestUcsNormalize < Textbringer::TestCase
  def test_ucs_normalize_nfc_region
    insert("café\n")
    set_mark_command
    insert("schön\n")
    insert("①㌶\n")
    insert("アパート\n")
    previous_line
    ucs_normalize_nfc_region
    assert_equal(<<~EOF, Buffer.current.to_s)
      café
      schön
      ①㌶
      アパート
    EOF
  end

  def test_ucs_normalize_nfd_region
    insert("café\n")
    set_mark_command
    insert("schön\n")
    insert("①㌶\n")
    insert("アパート\n")
    previous_line
    ucs_normalize_nfd_region
    assert_equal(<<~EOF, Buffer.current.to_s)
      café
      schön
      ①㌶
      アパート
    EOF
  end

  def test_ucs_normalize_nfkc_region
    insert("café\n")
    set_mark_command
    insert("schön\n")
    insert("①㌶\n")
    insert("アパート\n")
    previous_line
    ucs_normalize_nfkc_region
    assert_equal(<<~EOF, Buffer.current.to_s)
      café
      schön
      1ヘクタール
      アパート
    EOF
  end

  def test_ucs_normalize_nfkd_region
    insert("café\n")
    set_mark_command
    insert("schön\n")
    insert("①㌶\n")
    insert("アパート\n")
    previous_line
    ucs_normalize_nfkd_region
    assert_equal(<<~EOF, Buffer.current.to_s)
      café
      schön
      1ヘクタール
      アパート
    EOF
  end
end
