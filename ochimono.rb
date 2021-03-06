require 'io/console'

class Drop
  attr_accessor :x, :y, :emoji
  SUSHI = "\u{1F363}"
  BEER = "\u{1F37A}"
  PIZZA = "\u{1F355}"
  ONIGIRI = "\u{1F359}"
  EMOJIS = [SUSHI, BEER, PIZZA, ONIGIRI]

  def initialize(x)
    @x = x
    @y = 0
    @emoji = EMOJIS.sample
  end
end

class Ochimono
  ROWS = 12
  COLS = 6

  Y_VELOCITY = 0.1

  def initialize
    @drops = [Drop.new(2), Drop.new(3)]
    @fixed_drops = []
    @commands = []
    @y_velocity = Y_VELOCITY
    @score = 0
  end

  def clear_screen
    puts "\e[H\e[2J"
  end

  def draw_boarders
    print "\e[0;0H#{'*' * ((COLS + 1)* 2)}\e[0;0H"
    print "\e[#{ROWS + 3};0H#{'*' * ((COLS + 1) * 2)}\e[0;0H"

    (ROWS + 3).times do |r|
      print "\e[#{r};0H*\e[0;0H"
      print "\e[#{r};#{(COLS + 1) * 2}H*\e[0;0H"
    end
  end

  def draw_score
    print "\e[0;#{(COLS + 1) * 2 + 2}Hscore:#{@score}\e[0;0H"
  end

  def can_fall?(drop)
    @fixed_drops.each do |fixed_drop|
      next if drop == fixed_drop
      return false if drop.x == fixed_drop.x && (drop.y + 1 == fixed_drop.y || drop.y.ceil == fixed_drop.y)
    end

    drop.y < ROWS
  end

  def fall_drops
    if landing?
      @fixed_drops.concat(@drops)
      @drops = []
      @y_velocity = Y_VELOCITY
    end

    (@drops + @fixed_drops).each do |drop|
      drop.y += @y_velocity if can_fall?(drop)
      drop.y = drop.y.floor unless can_fall?(drop)
    end
  end

  def remove_connected_drops
    drops_to_remove = []

    @fixed_drops.each do |drop|
      connected_drops = find_connected_drops(drop, [])
      if connected_drops.size >= 4
        drops_to_remove += connected_drops
      end
    end

    drops_to_remove.each do |drop|
      @fixed_drops.delete(drop)
    end
  end

  def find_connected_drops(origin_drop, connected_drops)
    connected_drops << origin_drop
    x = origin_drop.x
    y = origin_drop.y

    [[0, -1], [1, 0], [0, 1], [-1, 0]].each do |dx, dy|
      if next_drop = @fixed_drops.find { |drop| drop.x == x + dx && drop.y == y + dy && drop.emoji == origin_drop.emoji }
        next if connected_drops.include?(next_drop)
        connected_drops = find_connected_drops(next_drop, connected_drops)
      end
    end

    connected_drops
  end

  def landing?
    @drops.any? { |drop| !can_fall?(drop) }
  end

  def fixed?
    @fixed_drops.none? { |drop| can_fall?(drop) }
  end

  def valid_position?(x,y)
    x >= 0 && x < COLS && y >= 0 && y < ROWS
  end

  def rotate_drops(direction)
    return if landing? || @drops.empty?

    center = @drops[0]
    rotating = @drops[1]

    dx = center.x - rotating.x
    dy = center.y - rotating.y

    relative_positions = [[0, -1], [1, 0], [0, 1], [-1, 0]]

    if relative_position_index = relative_positions.index { |pos| (pos[0] - dx).abs < 0.1 && (pos[1] - dy).abs < 0.1 }
      index_offset = direction == :left ? -1 : 1
      rotated_position = relative_positions[(relative_position_index + index_offset) % relative_positions.size]

      new_rotating_x = center.x + rotated_position[0]
      new_rotating_y = center.y + rotated_position[1]
      obstacle = @fixed_drops.find { |fixed_drop| fixed_drop.x == new_rotating_x && fixed_drop.y == new_rotating_y.ceil }
      return if obstacle || !valid_position?(new_rotating_x, new_rotating_y)

      rotating.x = new_rotating_x
      rotating.y = new_rotating_y
    end
  end

  def acceralate_drops
    @y_velocity = Y_VELOCITY * 10
  end

  def get_command
    @commands.shift
  end

  def main_loop
    loop do
      clear_screen

      while command = get_command
        case command
        when :left
          left_drop = @drops.sort_by(&:x)[0]
          if left_drop && left_drop.x - 1 >= 0
            @drops.each { |drop| drop.x -= 1}
          end
        when :right
          right_drop = @drops.sort_by(&:x).reverse[0]
          if right_drop && right_drop.x + 1 < COLS
            @drops.each { |drop| drop.x += 1}
          end
        when :rotate_left 
          rotate_drops(:left)
        when :rotate_right
          rotate_drops(:right)
        when :down
          acceralate_drops
        end
      end

      fall_drops
      remove_connected_drops if fixed?

      if @drops.empty? && fixed?
        @drops = [Drop.new(2), Drop.new(3)]
      end

      draw_boarders
      draw_score

      (@drops + @fixed_drops).each do |drop|
        x = drop.x
        y = drop.y.floor
        print "\e[#{y + 2};#{(x + 1)* 2}H#{drop.emoji} \e[0;0H"
      end

      sleep 0.05
    end
  end

  def start
    Thread.new do
      begin
        main_loop
      rescue => e
        puts e
        puts e.backtrace
        exit
      end
    end

    loop do
      command = STDIN.getch.chr
      case command
      when 'l'
        @commands << :right
      when 'h'
        @commands << :left
      when 'j'
        @commands << :rotate_left
      when 'k'
        @commands << :rotate_right
      when ' '
        @commands << :down
      when 'q'
        exit
      end
    end
  end
end

Ochimono.new.start
