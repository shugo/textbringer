module Textbringer
  module Commands
    define_command(:eval_elisp_expression,
                   doc: "Read an Emacs Lisp expression from the minibuffer, evaluate it, and display the result.") do
      |s = read_from_minibuffer("Eval Elisp: ")|
      result = Elisp.eval_string(s)
      message(result.inspect)
    end

    define_command(:eval_elisp_buffer,
                   doc: "Evaluate the current buffer as Emacs Lisp.") do
      source = Buffer.current.to_s
      result = Elisp.eval_string(source, filename: Buffer.current.name)
      message(result.inspect)
    end

    define_command(:eval_elisp_region,
                   doc: "Evaluate the selected region as Emacs Lisp.") do
      b = Buffer.current
      s = b.substring(b.point, b.mark).dup
      result = Elisp.eval_string(s)
      message(result.inspect)
    end

    define_command(:load_elisp_file,
                   doc: "Load an Emacs Lisp file.") do
      |path = read_file_name("Load Elisp file: ")|
      Elisp.load_file(path)
      message("Loaded #{path}")
    end
  end
end
