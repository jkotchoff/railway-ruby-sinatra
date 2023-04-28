#!/usr/bin/env ruby

class String
  def trim_whitespace!
    gsub!(/ /m, '')
  end

  def blank?
    self == ''
  end
end

class WorldState
  attr_accessor :cells

  def initialize
    self.cells = []
  end

  def cell_in_position(position)
    cells.each do |cell|
      return cell if cell.position == position
    end
    nil
  end

  def cell_matching(other_cell)
    cell_in_position(other_cell.position)
  end

  def deep_clone
    Marshal.load(Marshal.dump(self))
  end
end

class Cell
  attr_accessor :position, :state, :neighbours

  def initialize(opts = {})
    opts.each_pair do |key, value|
      send("#{key}=", value)
    end
  end

  def add_neighbour(other_cell)
    self.neighbours ||= []
    return unless other_cell && !neighbours.index(other_cell)

    self.neighbours << other_cell
    other_cell.neighbours ||= []
    return if other_cell.neighbours.index(self)

    other_cell.neighbours << self
  end

  def alive?
    !!state
  end

  def evolved_state
    if alive? && live_neighbour_count < 2 || live_neighbour_count > 3
      false
    elsif !alive? && live_neighbour_count == 3
      true
    else
      state
    end
  end

  def live_neighbour_count
    neighbours.select(&:alive?).length
  end

  def to_s
    alive? ? 'x' : '.'
  end
end

class World
  attr_accessor :current_state

  def cells
    current_state.cells
  end

  def evolve!
    new_state = current_state.deep_clone.tap do |evolved_state|
      evolved_state.cells.each do |new_cell|
        new_cell.state = current_state.cell_matching(new_cell).evolved_state
      end
    end
    self.current_state = new_state
    self
  end
end

class TwoDimensionalRectangularWorld < World
  ALIVE = 'x' # used to parse input strings
  attr_accessor :height, :width # used for visualizing to_s    # used for neighbour checking bounds

  def initialize(initial_state)
    rows_of_dots_and_crosses = initial_state.split("\n").each(&:trim_whitespace!).reject(&:blank?)
    self.height = rows_of_dots_and_crosses.length
    self.width = rows_of_dots_and_crosses.first.length
    self.current_state = WorldState.new
    parse_tokenized_string_input(rows_of_dots_and_crosses)
  end

  def parse_tokenized_string_input(rows)
    rows.each_with_index do |row, row_index|
      row.each_char.each_with_index do |char, cell_index|
        current_state.cells << Cell.new(
          state: (char == ALIVE),
          position: {
            row: row_index,
            column: cell_index
          }
        ).tap do |new_cell|
          # populate any neighbours
          new_cell.add_neighbour(current_state.cell_in_position({ row: row_index - 1, column: cell_index - 1 })) # up-left
          new_cell.add_neighbour(current_state.cell_in_position({ row: row_index - 1, column: cell_index }))     # up
          new_cell.add_neighbour(current_state.cell_in_position({ row: row_index - 1, column: cell_index + 1 })) # up-right
          new_cell.add_neighbour(current_state.cell_in_position({ row: row_index,     column: cell_index + 1 })) # right
          new_cell.add_neighbour(current_state.cell_in_position({ row: row_index + 1, column: cell_index + 1 })) # down-right
          new_cell.add_neighbour(current_state.cell_in_position({ row: row_index + 1, column: cell_index }))     # down
          new_cell.add_neighbour(current_state.cell_in_position({ row: row_index + 1, column: cell_index - 1 })) # down-left
          new_cell.add_neighbour(current_state.cell_in_position({ row: row_index,     column: cell_index - 1 })) # left
        end
      end
    end
  end

  def to_s
    world_state_to_s
  end

  def world_state_to_s(world_state = current_state)
    str = ''
    world_state.cells.each_with_index do |cell, i|
      str += "\n" if i % width == 0
      str += cell.to_s + ' '
    end
    str + "\n"
  end
end

class WorldSimulator
  require 'curses'

  def self.run(world_origin_state_file_path, sleep_time = 0.4)
    original_state = File.read(world_origin_state_file_path)
    world = TwoDimensionalRectangularWorld.new(original_state)

    loop do
      Curses.clear
      Curses.setpos(1, 0)
      Curses.addstr("Running Game of Life simulation on #{world_origin_state_file_path} - press <ctrl> + c to stop")
      Curses.setpos(2, 0)
      Curses.addstr(world.to_s)
      Curses.refresh
      world.evolve!
      sleep sleep_time.to_f
    end
  end
end

unless @library_call
  if ARGV.length == 2 || ARGV.length == 4 && ARGV[0] == '--simulate'
    if ARGV[2] == '--sleep' && ARGV[3]
      WorldSimulator.run(ARGV[1], ARGV[3])
    else
      WorldSimulator.run(ARGV[1])
    end
  else
    puts "\n"
    puts " usage syntax: ./world.rb --simulate [file_path_to_worlds_original_state] --sleep [seconds]\n\n"
    puts "           eg: ./world.rb --simulate sample_worlds/oscillator-blinking.gol --sleep 0.4\n\n"
  end
end
