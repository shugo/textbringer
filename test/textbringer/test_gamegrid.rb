require_relative "../test_helper"

class GamegridTest < Textbringer::TestCase
  def test_initialize
    grid = Gamegrid.new(10, 5)
    assert_equal(10, grid.width)
    assert_equal(5, grid.height)
    assert_equal(0, grid.score)
  end

  def test_set_get_cell
    grid = Gamegrid.new(3, 3)
    grid.set_cell(1, 2, 5)
    assert_equal(5, grid.get_cell(1, 2))
    assert_equal(0, grid.get_cell(0, 0))
  end

  def test_cell_bounds_check
    grid = Gamegrid.new(3, 3)
    assert_raise(ArgumentError) { grid.set_cell(3, 0, 1) }
    assert_raise(ArgumentError) { grid.get_cell(0, 3) }
    assert_raise(ArgumentError) { grid.set_cell(-1, 0, 1) }
  end

  def test_set_get_face
    grid = Gamegrid.new(3, 3)
    grid.set_face(0, 0, :gamegrid_red)
    assert_equal(:gamegrid_red, grid.get_face(0, 0))
    assert_nil(grid.get_face(1, 1))
  end

  def test_fill
    grid = Gamegrid.new(2, 2)
    grid.set_cell(0, 0, 1)
    grid.set_face(0, 0, :gamegrid_red)
    grid.fill(0)
    assert_equal(0, grid.get_cell(0, 0))
    assert_nil(grid.get_face(0, 0))
  end

  def test_display_options_and_render
    grid = Gamegrid.new(3, 2)
    grid.set_display_option(0, char: ".")
    grid.set_display_option(1, char: "#", face: :gamegrid_red)
    grid.set_cell(1, 0, 1)
    grid.set_cell(2, 1, 1)
    assert_equal(".#.\n..#", grid.render)
  end

  def test_render_string_values
    grid = Gamegrid.new(2, 1)
    grid.set_cell(0, 0, "X")
    grid.set_cell(1, 0, "O")
    assert_equal("XO", grid.render)
  end

  def test_render_default_space
    grid = Gamegrid.new(2, 1)
    assert_equal("  ", grid.render)
  end

  def test_face_map_with_display_option_face
    grid = Gamegrid.new(2, 1)
    grid.set_display_option(1, char: "#", face: :gamegrid_red)
    grid.set_cell(0, 0, 1)
    highlight_on, highlight_off = grid.face_map
    assert_equal(Face[:gamegrid_red], highlight_on[0])
    assert_equal(true, highlight_off[1])
  end

  def test_face_map_explicit_face_overrides_display_option
    grid = Gamegrid.new(2, 1)
    grid.set_display_option(1, char: "#", face: :gamegrid_red)
    grid.set_cell(0, 0, 1)
    grid.set_face(0, 0, :gamegrid_blue)
    highlight_on, _highlight_off = grid.face_map
    assert_equal(Face[:gamegrid_blue], highlight_on[0])
  end

  def test_face_map_no_face
    grid = Gamegrid.new(2, 1)
    grid.set_display_option(0, char: ".")
    highlight_on, highlight_off = grid.face_map
    assert(highlight_on.empty?)
    assert(highlight_off.empty?)
  end

  def test_timer
    grid = Gamegrid.new(1, 1)
    grid.start_timer(0.01) { }
    assert(grid.timer_active?)
    sleep(0.05)
    grid.stop_timer
    assert(!grid.timer_active?)
  end

  def test_stop_timer_when_no_timer
    grid = Gamegrid.new(1, 1)
    grid.stop_timer  # should not raise
    assert(!grid.timer_active?)
  end

  def test_score_persistence
    Dir.mktmpdir do |dir|
      original_home = ENV["HOME"]
      ENV["HOME"] = dir
      begin
        Gamegrid.add_score("testgame", 100, player_name: "alice")
        Gamegrid.add_score("testgame", 200, player_name: "bob")
        Gamegrid.add_score("testgame", 150, player_name: "carol")

        scores = Gamegrid.load_scores("testgame")
        assert_equal(3, scores.length)
        assert_equal(200, scores[0][:score])
        assert_equal("bob", scores[0][:player])
        assert_equal(150, scores[1][:score])
        assert_equal(100, scores[2][:score])
      ensure
        ENV["HOME"] = original_home
      end
    end
  end

  def test_load_scores_no_file
    Dir.mktmpdir do |dir|
      original_home = ENV["HOME"]
      ENV["HOME"] = dir
      begin
        scores = Gamegrid.load_scores("nonexistent")
        assert_equal([], scores)
      ensure
        ENV["HOME"] = original_home
      end
    end
  end

  def test_load_scores_with_limit
    Dir.mktmpdir do |dir|
      original_home = ENV["HOME"]
      ENV["HOME"] = dir
      begin
        15.times do |i|
          Gamegrid.add_score("testgame", i * 10, player_name: "p#{i}")
        end
        scores = Gamegrid.load_scores("testgame", limit: 5)
        assert_equal(5, scores.length)
        assert_equal(140, scores[0][:score])
      ensure
        ENV["HOME"] = original_home
      end
    end
  end
end
