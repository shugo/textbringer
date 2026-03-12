module Textbringer
  module Elisp
    class Compiler
      class CompileError < StandardError; end

      KNOWN_PRIMITIVES = {
        "+" => "el_plus",
        "-" => "el_minus",
        "*" => "el_multiply",
        "/" => "el_divide",
        "%" => "el_mod",
        "1+" => "el_one_plus",
        "1-" => "el_one_minus",
        "car" => "car",
        "cdr" => "cdr",
        "cons" => "cons",
        "list" => "list",
        "length" => "el_length",
        "not" => "el_not",
        "null" => "el_not",
        "eq" => "el_eq",
        "eql" => "el_eql",
        "equal" => "el_equal",
        "=" => "el_num_eq",
        "/=" => nil,  # handled specially
        "<" => "el_lt",
        ">" => "el_gt",
        "<=" => "el_le",
        ">=" => "el_ge",
      }.freeze

      def compile(forms, filename: "(elisp)")
        lines = []
        lines << "R ||= Textbringer::Elisp::Runtime"
        lines << ""
        forms.each do |form|
          lines << compile_form(form)
        end
        lines.join("\n")
      end

      private

      def compile_form(node)
        case node
        when IntegerLit
          node.value.to_s
        when FloatLit
          node.value.to_s
        when StringLit
          node.value.inspect
        when CharLit
          node.value.to_s
        when Symbol
          compile_symbol(node)
        when List
          compile_list(node)
        when Vector
          "[#{node.elements.map { |e| compile_form(e) }.join(", ")}]"
        when Quoted
          if node.kind == :quote
            compile_quote_form(node.form)
          elsif node.kind == :function
            compile_function([node.form])
          elsif node.kind == :backquote
            compile_backquote(node.form)
          else
            compile_form(node.form)
          end
        when Unquote
          raise CompileError, "unquote outside of backquote"
        else
          raise CompileError, "unknown node type: #{node.class}"
        end
      end

      def compile_symbol(node)
        case node.name
        when "nil"
          "nil"
        when "t"
          "true"
        else
          "R.get_var(:\"#{escape_sym(node.name)}\")"
        end
      end

      def compile_list(node)
        return "nil" if node.elements.empty?

        head = node.elements[0]
        return compile_funcall(node) unless head.is_a?(Symbol)

        args = node.elements[1..]
        case head.name
        when "defun"
          compile_defun(args)
        when "defvar", "defcustom"
          compile_defvar(args)
        when "defmacro"
          compile_defmacro(args)
        when "let"
          compile_let(args)
        when "let*"
          compile_let_star(args)
        when "if"
          compile_if(args)
        when "when"
          compile_when(args)
        when "unless"
          compile_unless(args)
        when "cond"
          compile_cond(args)
        when "progn"
          compile_progn(args)
        when "prog1"
          compile_prog1(args)
        when "prog2"
          compile_prog2(args)
        when "while"
          compile_while(args)
        when "setq"
          compile_setq(args)
        when "quote"
          compile_quote_form(args[0])
        when "function"
          compile_function(args)
        when "lambda"
          compile_lambda(args)
        when "and"
          compile_and(args)
        when "or"
          compile_or(args)
        when "not"
          "R.el_not(#{compile_form(args[0])})"
        when "save-excursion"
          compile_save_excursion(args)
        when "unwind-protect"
          compile_unwind_protect(args)
        when "condition-case"
          compile_condition_case(args)
        when "catch"
          compile_catch(args)
        when "throw"
          compile_throw(args)
        when "interactive"
          # Standalone interactive declaration — ignored at top level
          "nil"
        when "provide"
          "R.provide(:\"#{escape_sym(args[0].is_a?(Quoted) ? args[0].form.name : args[0].name)}\")"
        when "require"
          name = args[0].is_a?(Quoted) ? args[0].form.name : args[0].name
          "Textbringer::Elisp.load_feature(:\"#{escape_sym(name)}\")"
        when "message"
          compile_message(args)
        when "error"
          "raise(Textbringer::Elisp::Runtime::ElispError, #{compile_form(args[0])})"
        when "apply"
          compile_apply(args)
        when "funcall"
          fname = args[0]
          fargs = args[1..]
          "R.funcall(#{compile_form(fname)}, #{fargs.map { |a| compile_form(a) }.join(", ")})"
        when "eval"
          "Textbringer::Elisp.eval_string(#{compile_form(args[0])})"
        else
          compile_funcall(node)
        end
      end

      def compile_defun(args)
        name = args[0].name
        params = args[1]
        body = args[2..]

        # Check for docstring
        doc = nil
        if body.length > 1 && body[0].is_a?(StringLit)
          doc = body[0].value
          body = body[1..]
        end

        # Check for interactive declaration
        interactive_spec = nil
        if body.length > 0 && body[0].is_a?(List) &&
           body[0].elements.length > 0 &&
           body[0].elements[0].is_a?(Symbol) &&
           body[0].elements[0].name == "interactive"
          interactive_form = body[0]
          body = body[1..]
          if interactive_form.elements.length > 1
            interactive_spec = interactive_form.elements[1]
          else
            interactive_spec = List.new(elements: [], dotted: nil, location: nil)
          end
        end

        param_info = extract_params(params)
        param_str = compile_params_str(param_info)
        binding_str = compile_param_bindings(param_info)
        body_str = body.map { |f| compile_form(f) }.join("; ")
        body_str = "nil" if body_str.empty?
        wrapped_body = binding_str.empty? ? body_str : "#{binding_str} { #{body_str} }"

        if interactive_spec
          spec_str = compile_form(interactive_spec)
          doc_str = doc ? doc.inspect : "nil"
          "R.defun_interactive(:\"#{escape_sym(name)}\", #{spec_str}, #{doc_str}) { |#{param_str}| #{wrapped_body} }"
        else
          "R.defun(:\"#{escape_sym(name)}\") { |#{param_str}| #{wrapped_body} }"
        end
      end

      # Returns [{name: "x", elisp_name: "x", kind: :required|:optional|:rest}, ...]
      def extract_params(params_node)
        return [] unless params_node.is_a?(List)
        result = []
        kind = :required
        params_node.elements.each do |p|
          raise CompileError, "param must be a symbol" unless p.is_a?(Symbol)
          case p.name
          when "&optional"
            kind = :optional
            next
          when "&rest"
            kind = :rest
            next
          end
          result << { name: ruby_var(p.name), elisp_name: p.name, kind: kind }
        end
        result
      end

      def compile_params_str(param_info)
        param_info.map do |p|
          case p[:kind]
          when :rest then "*#{p[:name]}"
          when :optional then "#{p[:name]}=nil"
          else p[:name]
          end
        end.join(", ")
      end

      def compile_param_bindings(param_info)
        return "" if param_info.empty?
        pairs = param_info.map do |p|
          if p[:kind] == :rest
            # Convert Ruby array to Cons list
            ":\"#{escape_sym(p[:elisp_name])}\" => R.list(*#{p[:name]})"
          else
            ":\"#{escape_sym(p[:elisp_name])}\" => #{p[:name]}"
          end
        end
        "R.with_dynamic_bindings({#{pairs.join(", ")}})"
      end

      def compile_defvar(args)
        name = args[0].name
        value = args.length > 1 ? compile_form(args[1]) : "nil"
        "R.defvar(:\"#{escape_sym(name)}\", #{value})"
      end

      def compile_defmacro(args)
        # Macros stored for compile-time expansion — simplified as functions
        name = args[0].name
        params = args[1]
        body = args[2..]
        param_info = extract_params(params)
        param_str = compile_params_str(param_info)
        binding_str = compile_param_bindings(param_info)
        body_str = body.map { |f| compile_form(f) }.join("; ")
        body_str = "nil" if body_str.empty?
        wrapped_body = binding_str.empty? ? body_str : "#{binding_str} { #{body_str} }"
        "R.defun(:\"#{escape_sym(name)}\") { |#{param_str}| #{wrapped_body} }"
      end

      def compile_let(args)
        bindings_node = args[0]
        body = args[1..]
        bindings = compile_let_bindings(bindings_node)
        body_str = body.map { |f| compile_form(f) }.join("; ")
        body_str = "nil" if body_str.empty?
        "R.with_dynamic_bindings({#{bindings}}) { #{body_str} }"
      end

      def compile_let_star(args)
        bindings_node = args[0]
        body = args[1..]
        body_str = body.map { |f| compile_form(f) }.join("; ")
        body_str = "nil" if body_str.empty?

        return body_str unless bindings_node.is_a?(List)

        # Nest bindings sequentially
        result = body_str
        bindings_node.elements.reverse_each do |b|
          if b.is_a?(List) && b.elements.length >= 2
            name = b.elements[0].name
            val = compile_form(b.elements[1])
            result = "R.with_dynamic_binding(:\"#{escape_sym(name)}\", #{val}) { #{result} }"
          elsif b.is_a?(List) && b.elements.length == 1
            name = b.elements[0].name
            result = "R.with_dynamic_binding(:\"#{escape_sym(name)}\", nil) { #{result} }"
          elsif b.is_a?(Symbol)
            result = "R.with_dynamic_binding(:\"#{escape_sym(b.name)}\", nil) { #{result} }"
          end
        end
        result
      end

      def compile_let_bindings(bindings_node)
        return "" unless bindings_node.is_a?(List)
        pairs = bindings_node.elements.map do |b|
          if b.is_a?(List) && b.elements.length >= 2
            ":\"#{escape_sym(b.elements[0].name)}\" => #{compile_form(b.elements[1])}"
          elsif b.is_a?(List) && b.elements.length == 1
            ":\"#{escape_sym(b.elements[0].name)}\" => nil"
          elsif b.is_a?(Symbol)
            ":\"#{escape_sym(b.name)}\" => nil"
          end
        end
        pairs.compact.join(", ")
      end

      def compile_if(args)
        cond = compile_form(args[0])
        then_branch = compile_form(args[1])
        if args.length > 2
          else_body = args[2..].map { |f| compile_form(f) }.join("; ")
          "(R.truthy?(#{cond}) ? (#{then_branch}) : (begin; #{else_body}; end))"
        else
          "(R.truthy?(#{cond}) ? (#{then_branch}) : nil)"
        end
      end

      def compile_when(args)
        cond = compile_form(args[0])
        body = args[1..].map { |f| compile_form(f) }.join("; ")
        "(R.truthy?(#{cond}) ? (begin; #{body}; end) : nil)"
      end

      def compile_unless(args)
        cond = compile_form(args[0])
        body = args[1..].map { |f| compile_form(f) }.join("; ")
        "(!R.truthy?(#{cond}) ? (begin; #{body}; end) : nil)"
      end

      def compile_cond(args)
        clauses = args.map do |clause|
          raise CompileError, "cond clause must be a list" unless clause.is_a?(List)
          elements = clause.elements
          if elements[0].is_a?(Symbol) && elements[0].name == "t"
            body = elements[1..].map { |f| compile_form(f) }.join("; ")
            body = "true" if body.empty?
            { cond: nil, body: body }
          else
            cond = compile_form(elements[0])
            body = elements[1..].map { |f| compile_form(f) }.join("; ")
            body = cond if body.empty?
            { cond: cond, body: body }
          end
        end

        parts = []
        clauses.each_with_index do |c, i|
          if c[:cond].nil?
            parts << c[:body]
            break
          elsif i == 0
            parts << "if R.truthy?(#{c[:cond]}); #{c[:body]}"
          else
            parts << "elsif R.truthy?(#{c[:cond]}); #{c[:body]}"
          end
        end
        if clauses.last[:cond]
          parts << "end"
        else
          parts[-1] = "else; #{parts[-1]}; end" if parts.length > 1
        end
        "(#{parts.join("; ")})"
      end

      def compile_progn(args)
        return "nil" if args.empty?
        body = args.map { |f| compile_form(f) }.join("; ")
        "(begin; #{body}; end)"
      end

      def compile_prog1(args)
        return "nil" if args.empty?
        first = compile_form(args[0])
        rest = args[1..].map { |f| compile_form(f) }.join("; ")
        "(__prog1_val__ = #{first}; #{rest}; __prog1_val__)"
      end

      def compile_prog2(args)
        return "nil" if args.length < 2
        first = compile_form(args[0])
        second = compile_form(args[1])
        rest = args[2..].map { |f| compile_form(f) }.join("; ")
        "(#{first}; __prog2_val__ = #{second}; #{rest}; __prog2_val__)"
      end

      def compile_while(args)
        cond = compile_form(args[0])
        body = args[1..].map { |f| compile_form(f) }.join("; ")
        "(while R.truthy?(#{cond}); #{body}; end; nil)"
      end

      def compile_setq(args)
        pairs = args.each_slice(2).map do |name, value|
          raise CompileError, "setq: variable name must be a symbol" unless name.is_a?(Symbol)
          "R.set_var(:\"#{escape_sym(name.name)}\", #{compile_form(value)})"
        end
        pairs.length == 1 ? pairs[0] : "(#{pairs.join("; ")})"
      end

      def compile_quote_form(node)
        case node
        when Symbol
          ":\"#{escape_sym(node.name)}\""
        when IntegerLit
          node.value.to_s
        when FloatLit
          node.value.to_s
        when StringLit
          node.value.inspect
        when List
          if node.elements.empty? && node.dotted.nil?
            "nil"
          else
            elements = node.elements.map { |e| compile_quote_form(e) }.join(", ")
            if node.dotted
              # Build dotted list with cons
              result = compile_quote_form(node.dotted)
              node.elements.reverse_each do |e|
                result = "R.cons(#{compile_quote_form(e)}, #{result})"
              end
              result
            else
              "R.list(#{elements})"
            end
          end
        when Vector
          "[#{node.elements.map { |e| compile_quote_form(e) }.join(", ")}]"
        when Quoted
          if node.kind == :quote
            compile_quote_form(node.form)
          else
            compile_form(node)
          end
        else
          "nil"
        end
      end

      def compile_function(args)
        form = args[0]
        if form.is_a?(Symbol)
          "R.function_ref(:\"#{escape_sym(form.name)}\")"
        elsif form.is_a?(List) && form.elements[0].is_a?(Symbol) && form.elements[0].name == "lambda"
          compile_lambda(form.elements[1..])
        else
          compile_form(form)
        end
      end

      def compile_lambda(args)
        params = args[0]
        body = args[1..]
        # skip docstring
        if body.length > 1 && body[0].is_a?(StringLit)
          body = body[1..]
        end
        # skip interactive
        if body.length > 0 && body[0].is_a?(List) &&
           body[0].elements.length > 0 &&
           body[0].elements[0].is_a?(Symbol) &&
           body[0].elements[0].name == "interactive"
          body = body[1..]
        end
        param_info = extract_params(params)
        param_str = compile_params_str(param_info)
        binding_str = compile_param_bindings(param_info)
        body_str = body.map { |f| compile_form(f) }.join("; ")
        body_str = "nil" if body_str.empty?
        wrapped_body = binding_str.empty? ? body_str : "#{binding_str} { #{body_str} }"
        "R.make_lambda { |#{param_str}| #{wrapped_body} }"
      end

      def compile_and(args)
        return "true" if args.empty?
        lambdas = args.map { |a| "->{ #{compile_form(a)} }" }.join(", ")
        "R.el_and(#{lambdas})"
      end

      def compile_or(args)
        return "nil" if args.empty?
        lambdas = args.map { |a| "->{ #{compile_form(a)} }" }.join(", ")
        "R.el_or(#{lambdas})"
      end

      def compile_save_excursion(args)
        body = args.map { |f| compile_form(f) }.join("; ")
        "Textbringer::Buffer.current.save_excursion { #{body} }"
      end

      def compile_unwind_protect(args)
        body = compile_form(args[0])
        cleanup = args[1..].map { |f| compile_form(f) }.join("; ")
        "(begin; #{body}; ensure; #{cleanup}; end)"
      end

      def compile_condition_case(args)
        var = args[0]
        body = compile_form(args[1])
        handlers = args[2..]

        rescue_clauses = handlers.map do |h|
          raise CompileError, "condition-case handler must be a list" unless h.is_a?(List)
          handler_body = h.elements[1..].map { |f| compile_form(f) }.join("; ")
          handler_body = "nil" if handler_body.empty?
          if var.is_a?(Symbol) && var.name != "nil"
            "rescue => #{ruby_var(var.name)}; #{handler_body}"
          else
            "rescue => _el_err; #{handler_body}"
          end
        end

        "(begin; #{body}; #{rescue_clauses.join("; ")}; end)"
      end

      def compile_catch(args)
        tag = args[0]
        body = args[1..].map { |f| compile_form(f) }.join("; ")
        tag_str = if tag.is_a?(Quoted)
                    ":\"#{escape_sym(tag.form.name)}\""
                  else
                    compile_form(tag)
                  end
        "catch(R.catch_tag(#{tag_str})) { #{body} }"
      end

      def compile_throw(args)
        tag = args[0]
        value = args.length > 1 ? compile_form(args[1]) : "nil"
        tag_str = if tag.is_a?(Quoted)
                    ":\"#{escape_sym(tag.form.name)}\""
                  else
                    compile_form(tag)
                  end
        "throw(R.catch_tag(#{tag_str}), #{value})"
      end

      def compile_message(args)
        if args.length == 1
          "R.funcall(:\"message\", #{compile_form(args[0])})"
        else
          compiled = args.map { |a| compile_form(a) }
          "R.funcall(:\"message\", #{compiled.join(", ")})"
        end
      end

      def compile_apply(args)
        func = args[0]
        rest = args[1..]
        func_str = if func.is_a?(Quoted) && func.kind == :function
                     ":\"#{escape_sym(func.form.name)}\""
                   else
                     compile_form(func)
                   end
        "R.funcall(:\"apply\", #{func_str}, #{rest.map { |a| compile_form(a) }.join(", ")})"
      end

      def compile_funcall(node)
        head = node.elements[0]
        args = node.elements[1..]
        compiled_args = args.map { |a| compile_form(a) }

        if head.is_a?(Symbol) && KNOWN_PRIMITIVES.key?(head.name)
          method = KNOWN_PRIMITIVES[head.name]
          if method
            return "R.#{method}(#{compiled_args.join(", ")})"
          elsif head.name == "/="
            return "R.el_not(R.el_num_eq(#{compiled_args.join(", ")}))"
          end
        end

        func_name = if head.is_a?(Symbol)
                      ":\"#{escape_sym(head.name)}\""
                    else
                      compile_form(head)
                    end
        "R.funcall(#{func_name}, #{compiled_args.join(", ")})"
      end

      def compile_backquote(node)
        case node
        when List
          elements = node.elements.map do |e|
            if e.is_a?(Unquote) && e.splicing
              # splice: handled separately
              nil
            elsif e.is_a?(Unquote)
              compile_form(e.form)
            else
              compile_backquote(e)
            end
          end
          # For now, simplified: no splicing support
          "R.list(#{elements.compact.join(", ")})"
        when Symbol
          ":\"#{escape_sym(node.name)}\""
        when Unquote
          compile_form(node.form)
        else
          compile_quote_form(node)
        end
      end

      def escape_sym(name)
        name.gsub("\\", "\\\\\\\\").gsub('"', '\\"')
      end

      def ruby_var(elisp_name)
        elisp_name.tr("-", "_").gsub(/[^a-zA-Z0-9_]/, "_")
      end
    end
  end
end
