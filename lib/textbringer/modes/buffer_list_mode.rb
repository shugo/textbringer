module Textbringer
  class BufferListMode < Mode
    BUFFER_LIST_MODE_MAP = Keymap.new
    BUFFER_LIST_MODE_MAP.define_key("\C-m", :this_window_command)

    def initialize(buffer)
      super(buffer)
      buffer.keymap = BUFFER_LIST_MODE_MAP
    end

    define_local_command(:this_window,
                         doc: "Change the current account.") do
      name = @buffer.save_excursion {
        @buffer.beginning_of_line
        @buffer.looking_at?(/.*/)
        @buffer.match_string(0)
      }
      switch_to_buffer(name)
    end
  end
end
