require "fileutils"
require "time"

module Textbringer
  class Gamegrid
    attr_reader :width, :height
    attr_accessor :score

    def initialize(width, height)
      @width = width
      @height = height
      @grid = Array.new(height) { Array.new(width, 0) }
      @faces = Array.new(height) { Array.new(width, nil) }
      @display_options = {}
      @score = 0
      @timer_thread = nil
    end

    # Cell API

    def set_cell(x, y, value)
      check_bounds(x, y)
      @grid[y][x] = value
    end

    def get_cell(x, y)
      check_bounds(x, y)
      @grid[y][x]
    end

    def set_face(x, y, face_name)
      check_bounds(x, y)
      @faces[y][x] = face_name
    end

    def get_face(x, y)
      check_bounds(x, y)
      @faces[y][x]
    end

    def set_display_option(value, char:, face: nil)
      @display_options[value] = { char: char, face: face }
    end

    def fill(value)
      @height.times do |y|
        @width.times do |x|
          @grid[y][x] = value
          @faces[y][x] = nil
        end
      end
    end

    # Rendering

    def render
      @height.times.map { |y|
        @width.times.map { |x|
          cell_char(@grid[y][x])
        }.join
      }.join("\n")
    end

    def face_map
      highlight_on = {}
      highlight_off = {}
      offset = 0
      @height.times do |y|
        @width.times do |x|
          value = @grid[y][x]
          # Priority: explicit set_face > display_option face > nil
          face_name = @faces[y][x]
          if face_name.nil?
            opt = @display_options[value]
            face_name = opt[:face] if opt
          end
          if face_name
            face = Face[face_name]
            if face
              highlight_on[offset] = face
              char_len = cell_char(value).bytesize
              highlight_off[offset + char_len] = true
            end
          end
          offset += cell_char(value).bytesize
        end
        offset += 1  # newline
      end
      [highlight_on, highlight_off]
    end

    # Timer

    def start_timer(interval, &callback)
      stop_timer
      @timer_thread = Thread.new do
        loop do
          sleep(interval)
          Controller.current.next_tick(&callback)
        rescue ThreadError
          break
        end
      end
    end

    def stop_timer
      if @timer_thread
        @timer_thread.kill
        @timer_thread = nil
      end
    end

    def timer_active?
      !@timer_thread.nil? && @timer_thread.alive?
    end

    # Score persistence

    def self.score_file_path(game_name)
      safe_name = File.basename(game_name).gsub(/[^A-Za-z0-9_\-]/, "_")
      File.expand_path("~/.textbringer/scores/#{safe_name}.scores")
    end

    def self.add_score(game_name, score, player_name: "anonymous")
      path = score_file_path(game_name)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "a") do |f|
        f.puts("#{score}\t#{player_name}\t#{Time.now.iso8601}")
      end
    end

    def self.load_scores(game_name, limit: 10)
      path = score_file_path(game_name)
      return [] unless File.exist?(path)
      lines = File.readlines(path, chomp: true)
      lines.map { |line|
        parts = line.split("\t")
        { score: parts[0].to_i, player: parts[1], time: parts[2] }
      }.sort_by { |h| -h[:score] }.first(limit)
    end

    private

    def check_bounds(x, y)
      if x < 0 || x >= @width || y < 0 || y >= @height
        raise ArgumentError, "coordinates (#{x}, #{y}) out of bounds"
      end
    end

    def cell_char(value)
      opt = @display_options[value]
      if opt
        opt[:char]
      elsif value.is_a?(String)
        value
      else
        " "
      end
    end
  end
end
