module Textbringer
  module Elisp
    Location = Data.define(:filename, :line, :column)

    IntegerLit = Data.define(:value, :location)
    FloatLit = Data.define(:value, :location)
    StringLit = Data.define(:value, :location)
    CharLit = Data.define(:value, :location)
    Symbol = Data.define(:name, :location)
    List = Data.define(:elements, :dotted, :location)
    Vector = Data.define(:elements, :location)
    Quoted = Data.define(:kind, :form, :location)
    Unquote = Data.define(:splicing, :form, :location)
  end
end
