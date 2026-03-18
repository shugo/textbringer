module Textbringer
  class GamegridMode < Mode
    @syntax_table = {}

    def self.inherited(child)
      super
      child.instance_variable_set(:@syntax_table, {})
    end

    define_keymap :GAMEGRID_MODE_MAP
    GAMEGRID_MODE_MAP.define_key("q", :gamegrid_quit_command)

    def initialize(buffer)
      super(buffer)
      buffer.keymap = GAMEGRID_MODE_MAP
    end


    define_local_command(:gamegrid_init,
                         doc: "Initialize a gamegrid in the current buffer.") do
      |width, height|
      grid = Gamegrid.new(width, height)
      @buffer[:gamegrid] = grid
      @buffer.read_only = true
      @buffer[:highlight_override] = -> { grid.face_map }
      grid
    end

    define_local_command(:gamegrid_refresh,
                         doc: "Refresh the gamegrid display.") do
      grid = @buffer[:gamegrid]
      return unless grid
      @buffer.read_only_edit do
        @buffer.clear
        @buffer.insert(grid.render)
        @buffer.beginning_of_buffer
      end
    end

    define_local_command(:gamegrid_quit,
                         doc: "Quit the current game.") do
      grid = @buffer[:gamegrid]
      grid&.stop_timer
      bury_buffer
    end
  end
end
