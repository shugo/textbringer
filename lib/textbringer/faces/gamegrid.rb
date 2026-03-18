module Textbringer
  # Foreground color faces for gamegrid
  Face.define :gamegrid_red, foreground: "red"
  Face.define :gamegrid_green, foreground: "green"
  Face.define :gamegrid_blue, foreground: "blue"
  Face.define :gamegrid_yellow, foreground: "yellow"
  Face.define :gamegrid_cyan, foreground: "cyan"
  Face.define :gamegrid_magenta, foreground: "magenta"
  Face.define :gamegrid_white, foreground: "white"

  # Block faces (solid background) for Tetris-style solid blocks
  Face.define :gamegrid_block_red, background: "red", foreground: "red"
  Face.define :gamegrid_block_green, background: "green", foreground: "green"
  Face.define :gamegrid_block_blue, background: "blue", foreground: "blue"
  Face.define :gamegrid_block_yellow, background: "yellow", foreground: "yellow"
  Face.define :gamegrid_block_cyan, background: "cyan", foreground: "cyan"
  Face.define :gamegrid_block_magenta, background: "magenta", foreground: "magenta"
  Face.define :gamegrid_block_white, background: "white", foreground: "white"

  # Utility faces
  Face.define :gamegrid_border, foreground: "white", bold: true
  Face.define :gamegrid_score, foreground: "yellow", bold: true
end
