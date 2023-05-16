# ![Textbringer](logo/logo.png)

[![Gem Version](https://badge.fury.io/rb/textbringer.svg)](https://badge.fury.io/rb/textbringer)
[![ubuntu](https://github.com/shugo/textbringer/workflows/ubuntu/badge.svg)](https://github.com/shugo/textbringer/actions?query=workflow%3Aubuntu)
[![windows](https://github.com/shugo/textbringer/workflows/windows/badge.svg)](https://github.com/shugo/textbringer/actions?query=workflow%3Awindows)
[![macos](https://github.com/shugo/textbringer/workflows/macos/badge.svg)](https://github.com/shugo/textbringer/actions?query=workflow%3Amacos)

TextbringerはRubyで実装されたEmacsライクなテキストエディタです。
Lispの代りにRubyで拡張することができます。

## スクリーンショット

![Screenshot](screenshot.png)

## デモ

* FizzBuzz: https://asciinema.org/a/103357
* Rubyプログラミング: https://asciinema.org/a/100156
* 日本語テキストの編集: https://asciinema.org/a/100166

## インストール

    $ gem install textbringer

マルチバイト文字を使用するためにはncurseswが必要です。
Textbringerが依存するcurses.gemをインストールする前に、ncurseswをインストールしておいてください。

    $ sudo apt-get install libncursesw5-dev
    $ gem install curses

## 使い方

    $ txtb

`Ctrl-x Ctrl-c` で終了できます。　

多くのコマンドとキーバインディングは[Emacs](https://www.gnu.org/software/emacs/)に似ています。

キーバインディングを確認するには、 `F1 b` または `Alt+x describe_bindings RET` とタイプしてください。

## 設定

### メタキー

端末エミュレータでメタキーを使用するためには、以下のような設定が必要です。

#### xterm

~/.Xresourcesに以下の行を追加してください。

    XTerm*metaSendsEscape: true

#### mlterm

~/.mlterm/mainに以下の行を追加してください。

    mod_meta_key = alt
    mod_meta_mode = esc

### 東アジアの曖昧な文字幅

[曖昧な文字](http://unicode.org/reports/tr11/#Ambiguous)を全角扱いするには、以下の設定を~/.textbringer.rbに記述してください。

    CONFIG[:east_asian_ambiguous_width] = 2

ncurseswはwcwidth(3)を使用するため、LD_PRELOADハックやlocale charmapの修正が必要かもしれません。

* https://github.com/fumiyas/wcwidth-cjk
* https://github.com/hamano/locale-eaw

xterm、 mlterm、screenにはそれぞれ独自の設定項目があります。

#### xterm

~/.Xresourcesに以下の設定を追加してください。

    xterm*utf8: 1
    xterm*locale: true
    xterm*cjkWidth: true

#### mlterm

~/.mlterm/mainに以下の設定を追加してください。

    col_size_of_width_a = 2

#### screen

~/.screenrcに以下の設定を追加してください。

    cjkwidth on

## プラグイン

* [Mournmail](https://github.com/shugo/mournmail): 電子メールクライアント
* [MedicineShield](https://github.com/shugo/medicine_shield): Mastodonクライアント
* [textbringer-presentation](https://github.com/shugo/textbringer-presentation): プレゼンテーションツール
* [textbringer-ghost_text](https://github.com/shugo/textbringer-ghost_text): [GhostText](https://github.com/fregante/GhostText)プラグイン

## ライセンス

[MIT License](http://opensource.org/licenses/MIT)の下でオープンソースとして利用可能です。

