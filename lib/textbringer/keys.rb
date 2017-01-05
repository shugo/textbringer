# frozen_string_literal: true

require "curses"

module Textbringer
  module Keys
    Curses.constants.grep(/\AKEY_/) do |name|
      const_set(name, Curses.const_get(name))
    end

    def key_name(key)
      Curses.keyname(key)
    end
  end
end
