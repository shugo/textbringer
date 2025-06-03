module Textbringer
  using Module.new {
    refine Buffer do
      def merge_overwrite_action
        if @undoing || @undo_stack.size < 2 ||
            !@undo_stack[-1].is_a?(DeleteAction) ||
            !@undo_stack[-2].is_a?(InsertAction)
          return
        end
        delete_action = @undo_stack.pop
        insert_action = @undo_stack.pop
        action = @undo_stack.last
        if action.is_a?(OverwriteAction)
          action.merge(insert_action.string, delete_action.string)
          @redo_stack.clear
        else
          new_action = OverwriteAction.new(self, insert_action.location,
                                           insert_action.string, delete_action.string)
          push_undo(new_action)
        end
      end
    end
  }

  class OverwriteMode < MinorMode
    self.mode_name = "Ovwrt"

    POST_INSERT_HOOK = -> {
      buffer = Buffer.current
      s = Controller.current.last_key * number_prefix_arg
      begin
        buffer.delete_char(s.size)
      rescue RangeError
        buffer.save_excursion do
          pos = buffer.point
          buffer.end_of_buffer
          buffer.delete_region(pos, buffer.point)
        end
      end
      buffer.merge_overwrite_action
    }

    def enable
      add_hook(:post_self_insert_hook, POST_INSERT_HOOK, local: true)
    end

    def disable
      remove_hook(:post_self_insert_hook, POST_INSERT_HOOK, local: true)
    end
  end

  class OverwriteAction < UndoableAction
    def initialize(buffer, location, inserted_string, deleted_string)
      super(buffer, location)
      @inserted_string = inserted_string
      @deleted_string = deleted_string
      @copied = false
    end

    def undo
      @buffer.goto_char(@location)
      @buffer.delete_region(@location, @location + @inserted_string.bytesize)
      @buffer.insert(@deleted_string)
      @buffer.goto_char(@location)
    end

    def redo
      @buffer.goto_char(@location)
      @buffer.delete_region(@location, @location + @deleted_string.bytesize)
      @buffer.insert(@inserted_string)
    end

    def merge(inserted_string, deleted_string)
      unless @copied
        @inserted_string = @inserted_string.dup
        @deleted_string = @deleted_string.dup
        @copied = true
      end
      @inserted_string.concat(inserted_string)
      @deleted_string.concat(deleted_string)
    end
  end
end
