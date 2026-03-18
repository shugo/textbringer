module Textbringer
  module Commands
    define_command(:tetris, doc: "Play Tetris.") do
      buffer = Buffer.find_or_new("*Tetris*", undo_limit: 0)
      buffer.apply_mode(TetrisMode) unless buffer.mode.is_a?(TetrisMode)
      switch_to_buffer(buffer)
      buffer.mode.tetris_new_game
    end
  end
end
