require_relative "../test_helper"

class TestIsearch < Textbringer::TestCase
  def test_isearch_forward
    buffer = Buffer.current
    buffer.insert(<<EOF)
　劉備は、船の商人らしい男を見かけてあわててそばへ寄って行った。
「茶を売って下さい、茶が欲しいんですが」
「え、茶だって？」
　洛陽《らくよう》の商人は、鷹揚《おうよう》に彼を振向いた。
「あいにくと、お前さんに頒《わ》けてやるような安茶は持たないよ。一葉《ひとは》いくらというような佳品しか船にはないよ」
「結構です。たくさんは要《い》りませんが」
「おまえ茶をのんだことがあるのかね。地方の衆が何か葉を煮てのんでいるが、あれは茶ではないよ」
「はい。その、ほんとの茶を頒《わ》けていただきたいのです」
　彼の声は、懸命だった。
　茶がいかに貴重か、高価か、また地方にもまだない物かは、彼もよくわきまえていた。
EOF
    buffer.beginning_of_buffer
    push_keys("茶\n")
    isearch_forward(recursive_edit: true)
    assert_equal(2, buffer.current_line)
    assert_equal(3, buffer.current_column)

    buffer.beginning_of_buffer
    push_keys("茶\C-s\n")
    isearch_forward(recursive_edit: true)
    assert_equal(2, buffer.current_line)
    assert_equal(12, buffer.current_column)

    buffer.beginning_of_buffer
    push_keys("茶が\n")
    isearch_forward(recursive_edit: true)
    assert_equal(2, buffer.current_line)
    assert_equal(13, buffer.current_column)

    buffer.beginning_of_buffer
    push_keys("茶を\C-s\C-s\n")
    isearch_forward(recursive_edit: true)
    assert_equal(8, buffer.current_line)
    assert_equal(14, buffer.current_column)

    buffer.beginning_of_buffer
    push_keys("茶を\C-g")
    isearch_forward(recursive_edit: true)
    assert_equal(true, buffer.beginning_of_buffer?)
  end
end
