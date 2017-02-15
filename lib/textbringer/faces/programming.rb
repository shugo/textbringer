# frozen_string_literal: true

module Textbringer
  Face.define :comment, foreground: "yellow"
  Face.define :preprocessing_directive, foreground: "green"
  Face.define :keyword, foreground: "magenta", bold: true
  Face.define :string, foreground: "blue", bold: true
end
