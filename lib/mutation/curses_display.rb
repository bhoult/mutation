require 'curses'

module Mutation
  class CursesDisplay
    attr_reader :running, :camera_x, :camera_y
    
    def initialize(world, simulator = nil)
      @world = world
      @simulator = simulator
      @running = false
      @camera_x = 0
      @camera_y = 0
      @last_key = nil
      @paused = false
      @last_step_time = Time.now
      
      # Initialize curses
      Curses.init_screen
      Curses.start_color
      Curses.cbreak
      Curses.noecho
      Curses.curs_set(0)             # Hide cursor
      
      # Try to enable non-blocking input
      STDIN.sync = true
      
      # Get screen dimensions
      @screen_height = Curses.lines - 2  # Leave room for status bar
      @screen_width = Curses.cols
      
      # Initialize color pairs
      init_colors
      
      # Calculate viewport
      update_viewport
    end
    
    def init_colors
      # Define color pairs for different energy levels
      Curses.init_pair(1, Curses::COLOR_GREEN, Curses::COLOR_BLACK)   # High energy (8-10)
      Curses.init_pair(2, Curses::COLOR_YELLOW, Curses::COLOR_BLACK)  # Medium energy (4-7)
      Curses.init_pair(3, Curses::COLOR_RED, Curses::COLOR_BLACK)     # Low energy (1-3)
      Curses.init_pair(4, Curses::COLOR_WHITE, Curses::COLOR_BLACK)   # Empty space
      Curses.init_pair(5, Curses::COLOR_CYAN, Curses::COLOR_BLACK)    # Status bar
      Curses.init_pair(6, Curses::COLOR_MAGENTA, Curses::COLOR_BLACK) # UI elements
    end
    
    def update_viewport
      world_width = @world.instance_variable_get(:@width)
      world_height = @world.instance_variable_get(:@height)
      
      @viewport_width = [@screen_width, world_width].min
      @viewport_height = [@screen_height, world_height].min
      
      # Calculate if scrolling is needed
      @needs_scrolling_x = world_width > @screen_width
      @needs_scrolling_y = world_height > @screen_height
      
      # Clamp camera position to valid ranges
      max_camera_x = [world_width - @viewport_width, 0].max
      max_camera_y = [world_height - @viewport_height, 0].max
      
      @camera_x = [[@camera_x, 0].max, max_camera_x].min
      @camera_y = [[@camera_y, 0].max, max_camera_y].min
    end
    
    def start
      @running = true
      
      begin
        display_loop
      ensure
        cleanup
      end
    end
    
    def stop
      @running = false
    end
    
    def cleanup
      Curses.close_screen
    end
    
    private
    
    def display_loop
      @last_display_update = Time.now
      @last_input_check = Time.now
      
      while @running
        begin
          current_time = Time.now
          
          # Always check for input frequently (every 10ms)
          if current_time - @last_input_check >= 0.01
            input_received = handle_input
            @last_input_check = current_time
            break unless @running
            
            # If input was received, update display immediately
            if input_received
              draw_world
              draw_status_bar  
              draw_help
              Curses.refresh
              @last_display_update = current_time
            end
          end
          
          # Step the simulation at its own pace (don't block input)
          step_simulation
          
          # Check for terminal resize
          check_terminal_resize
          
          # Update display at regular intervals (30 FPS = ~33ms)
          if current_time - @last_display_update >= 0.033
            draw_world
            draw_status_bar
            draw_help
            Curses.refresh
            @last_display_update = current_time
          end
          
          # Very short sleep to prevent busy waiting
          sleep(0.001)
        rescue => e
          # Log error but continue running
          Mutation.logger.debug("Display error: #{e.message}")
          sleep(0.01)
        end
      end
    end
    
    def step_simulation
      return if @paused
      return unless @simulator
      
      current_time = Time.now
      simulation_delay = Mutation.configuration.simulation_delay
      
      if current_time - @last_step_time >= simulation_delay
        @simulator.step
        @last_step_time = current_time
      end
    end
    
    def handle_input
      # Use curses timeout for non-blocking input
      Curses.stdscr.timeout = 0  # Non-blocking
      key = Curses.getch
      input_received = false
      
      if key && key != -1
        input_received = true
        @last_key = key.chr rescue key.to_s
        
        case key
        when 'q'.ord, 'Q'.ord
          @running = false
          @last_key = "QUIT"
          # Force immediate display update to show quit
          draw_world
          draw_status_bar
          draw_help
          Curses.refresh
        when ' '.ord  # Space for pause/resume
          @paused = !@paused
          @last_key = @paused ? "PAUSED" : "RESUMED"
          # Force immediate display update to show pause state
          draw_world
          draw_status_bar
          draw_help
          Curses.refresh
        when 'w'.ord, 'W'.ord
          move_camera(0, -1)
          @last_key = "UP"
          # Force immediate display update to show camera movement
          draw_world
          draw_status_bar
          draw_help
          Curses.refresh
        when 's'.ord, 'S'.ord
          move_camera(0, 1)
          @last_key = "DOWN"
          # Force immediate display update to show camera movement
          draw_world
          draw_status_bar
          draw_help
          Curses.refresh
        when 'a'.ord, 'A'.ord
          move_camera(-1, 0)
          @last_key = "LEFT"
          # Force immediate display update to show camera movement
          draw_world
          draw_status_bar
          draw_help
          Curses.refresh
        when 'd'.ord, 'D'.ord
          move_camera(1, 0)
          @last_key = "RIGHT"
          # Force immediate display update to show camera movement
          draw_world
          draw_status_bar
          draw_help
          Curses.refresh
        when 'r'.ord, 'R'.ord
          @camera_x = 0
          @camera_y = 0
          @last_key = "RESET VIEW"
          # Force immediate display update to show camera reset
          draw_world
          draw_status_bar
          draw_help
          Curses.refresh
        end
      end
      
      # Auto-quit after the population dies down to very few agents
      if @world.agent_count <= 2
        @auto_quit_counter ||= 0
        @auto_quit_counter += 1
        
        # Give it some time to potentially recover
        if @auto_quit_counter > 20  # About 4 seconds at 0.2s per step
          @running = false
          @last_key = "AUTO-QUIT"
          input_received = true
        end
      else
        @auto_quit_counter = 0
      end
      
      input_received
    end
    
    def move_camera(dx, dy)
      world_width = @world.instance_variable_get(:@width)
      world_height = @world.instance_variable_get(:@height)
      
      new_x = @camera_x + dx
      new_y = @camera_y + dy
      
      # Clamp to valid range
      max_camera_x = [world_width - @viewport_width, 0].max
      max_camera_y = [world_height - @viewport_height, 0].max
      
      @camera_x = [[new_x, 0].max, max_camera_x].min
      @camera_y = [[new_y, 0].max, max_camera_y].min
    end
    
    def draw_world
      grid = @world.instance_variable_get(:@grid)
      return unless grid
      
      # Clear screen first
      Curses.clear
      
      # Draw the world similar to the working debug test
      (0...@viewport_height).each do |screen_y|
        (0...@viewport_width).each do |screen_x|
          world_x = @camera_x + screen_x
          world_y = @camera_y + screen_y
          
          # Bounds checking
          next if world_y >= grid.size || world_x >= (grid[world_y]&.size || 0)
          
          # Get agent at this position
          agent = grid[world_y] && grid[world_y][world_x]
          
          # Determine character and color based on energy level
          if agent&.alive?
            char, color = agent_display(agent)
          else
            char = '.'
            color = 4  # White for empty
          end
          
          # Draw character
          Curses.attron(Curses.color_pair(color))
          Curses.setpos(screen_y, screen_x)
          Curses.addch(char)
          Curses.attroff(Curses.color_pair(color))
        end
      end
    end
    
    def agent_display(agent)
      energy = agent.energy
      
      # Choose character based on energy level
      char = case energy
             when 15..Float::INFINITY then '@'  # Very high energy
             when 10..14 then '#'               # High energy
             when 5..9 then 'o'                 # Medium energy
             when 1..4 then '·'                 # Low energy
             else '.'                           # Dead/empty
             end
      
      # Choose color based on energy level
      color = case energy
              when 8..Float::INFINITY then 1  # Green for high energy
              when 4..7 then 2                # Yellow for medium energy
              when 1..3 then 3                # Red for low energy
              else 4                          # White for empty
              end
      
      [char, color]
    end
    
    def draw_status_bar
      world_width = @world.instance_variable_get(:@width)
      world_height = @world.instance_variable_get(:@height)
      
      status_y = @screen_height
      
      # Bounds check for status bar
      return if status_y >= Curses.lines
      
      # Clear status line
      Curses.attron(Curses.color_pair(5))
      Curses.setpos(status_y, 0)
      Curses.clrtoeol  # Clear to end of line instead of adding spaces
      
      # Status information
      tick = @world.tick
      generation = @world.generation
      agents = @world.agent_count
      avg_energy = @world.average_energy.round(1)
      
      
      status_text = "T:#{tick} G:#{generation} Agents:#{agents} AvgE:#{avg_energy}"
      
      # Camera position if world is larger than screen
      if @needs_scrolling_x || @needs_scrolling_y
        max_camera_x = [world_width - @viewport_width, 0].max
        max_camera_y = [world_height - @viewport_height, 0].max
        camera_info = " | View:(#{@camera_x},#{@camera_y})/#{max_camera_x},#{max_camera_y} #{world_width}x#{world_height}"
        status_text += camera_info
      end
      
      # Paused indicator
      if @paused
        status_text += " [PAUSED]"
      end
      
      # Truncate to screen width
      max_width = [@screen_width, Curses.cols].min
      status_text = status_text[0, max_width - 1] if status_text.length >= max_width
      
      Curses.setpos(status_y, 0)
      Curses.addstr(status_text)
      Curses.attroff(Curses.color_pair(5))
    end
    
    def draw_help
      help_y = @screen_height + 1
      
      # Bounds check for help line
      return if help_y >= Curses.lines
      
      Curses.attron(Curses.color_pair(6))
      Curses.setpos(help_y, 0)
      Curses.clrtoeol  # Clear to end of line
      
      if @needs_scrolling_x || @needs_scrolling_y
        help_text = "WASD:Scroll | SPACE:Pause | R:Reset View | Q:Quit"
      else
        help_text = "SPACE:Pause | R:Reset View | Q:Quit"
      end
      
      if @last_key
        help_text += " | Last:#{@last_key}"
      end
      
      # Truncate to screen width
      max_width = [@screen_width, Curses.cols].min
      help_text = help_text[0, max_width - 1] if help_text.length >= max_width
      
      Curses.setpos(help_y, 0)
      Curses.addstr(help_text)
      Curses.attroff(Curses.color_pair(6))
    end
    
    def check_terminal_resize
      new_height = Curses.lines
      new_width = Curses.cols
      
      # Store current dimensions to compare
      @stored_height ||= new_height
      @stored_width ||= new_width
      
      if new_height != @stored_height || new_width != @stored_width
        # Terminal was resized, update dimensions
        @stored_height = new_height
        @stored_width = new_width
        @screen_height = new_height - 2
        @screen_width = new_width
        
        # Update viewport calculations
        update_viewport
        
        # Clear screen to prevent artifacts
        Curses.clear
        
        # Force a complete redraw
        Curses.refresh
      end
    end
    
    def paused?
      @paused
    end
  end
end