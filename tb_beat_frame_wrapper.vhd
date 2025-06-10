----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/05/2025 08:29:25 PM
-- Natalie Schreder
-- Beat detect / frame gen wrapper test bench
-- ----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;          
-- ----------------------------------------------------------------------------

entity tb_beat_frame_wrapper is
--  Port ( );
end tb_beat_frame_wrapper;

architecture behavior of tb_beat_frame_wrapper is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
  -- Testbench Signals
  signal s00_axis_clock : std_logic := '0';
  signal m00_axis_tvalid : std_logic := '1';  -- Assuming continuous data input
  signal data_in : std_logic_vector(31 downto 0);  -- Assuming 32-bit data for simplicity
  signal sw0_i, sw1_i : std_logic := '0';  -- 75% threshold setting (01)
  signal sample_mode_i : std_logic := '0';  -- Set to '0' for non-sample mode
  signal reset_n_i : std_logic := '1';  -- Active high reset
  signal threshold_factor : std_logic_vector (1 downto 0);
  signal pclk_i : std_logic := '0';
  
  signal video_pdata_o : std_logic_vector(23 downto 0);
  signal hsync_i, vsync_i, active_video_i : std_logic;
  signal fsync_i :  std_logic_vector(0 downto 0);


  -- Clock Generation (100 MHz for simulation)
  constant clk_period : time := 10 ns;
  constant total_lines        : integer := 525;
constant total_pixels       : integer := 800;
constant visible_lines      : integer := 480;
constant visible_pixels     : integer := 640;

constant hsync_start_pixel  : integer := 656;
constant hsync_end_pixel    : integer := 752;

constant vsync_start_line   : integer := 490;
constant vsync_end_line     : integer := 492;

  ----------------------------------------------------------------------------
-- Component Declarations
----------------------------------------------------------------------------  
component beat_frame_wrapper is
      generic (
        DATA_WIDTH : integer := 32;
        AMP_WIDTH  : integer := 4 );
    port (
        s00_axis_clock          : in std_logic;
        m00_axis_tvalid         : in std_logic;     -- should come from output of lowpass filter
        data_in                 : in std_logic_vector(DATA_WIDTH-1 downto 0);
        sample_mode_i             : in std_logic;     -- 1 if in sample mode, 0 if not
        reset_n_i                 : in std_logic;
        threshold_factor           : in std_logic_vector (1 downto 0);
        pclk_i                  : in std_logic;
        active_video_i          : STD_LOGIC;   
        hsync_i                 : STD_LOGIC;
        vsync_i                 : STD_LOGIC;
        fsync_i                 : std_logic_vector(0 downto 0);
        video_pdata_o    : out std_logic_vector(23 downto 0)
        );
end component;

----------------------------------------------------------------------------

begin
----------------------------------------------------------------------------
-- Component Instantiations
----------------------------------------------------------------------------   
dut : beat_frame_wrapper
    port map(
        s00_axis_clock          => s00_axis_clock,
        m00_axis_tvalid         => m00_axis_tvalid,
        data_in                 => data_in,
        sample_mode_i           => sample_mode_i,
        reset_n_i               => reset_n_i,
        threshold_factor           => threshold_factor,
        pclk_i                  => pclk_i,
        active_video_i          => active_video_i,
        hsync_i                 => hsync_i,
        vsync_i                 => vsync_i,
        fsync_i                 => fsync_i,        
        video_pdata_o           => video_pdata_o
    );

  -- Clock generation process
  clk_process : process
  begin
    s00_axis_clock <= not s00_axis_clock after clk_period / 2;
    pclk_i <= not pclk_i after clk_period * 2;
    wait for clk_period;
  end process;

  -- Generate 100Hz Triangle wave input for data_in
  triangle_wave_process : process
    variable time_counter : integer := 0;
    variable triangle_value : integer := 0;
    variable direction_up : boolean := true;  -- Direction flag for the triangle wave
  begin
    -- 100 Hz Triangle wave with 50% duty cycle (5ms ramp-up, 5ms ramp-down)
    if direction_up then
        -- Ramp up
        if triangle_value < 1023 then
            triangle_value := triangle_value + 1;  -- Increase value
        else
            direction_up := false;  -- Change direction to ramp down
        end if;
    else
        -- Ramp down
        if triangle_value > 0 then
            triangle_value := triangle_value - 1;  -- Decrease value
        else
            direction_up := true;  -- Change direction to ramp up
        end if;
    end if;
    
    -- Assign the triangle value to data_in (scaled to fit your data width)
    data_in <= std_logic_vector(to_unsigned(triangle_value, 32));

    time_counter := time_counter + 1;
    wait for clk_period;  -- Wait for the next clock period
  end process;



  stimulus_process : process
    -- VGA 640x480 @ 60Hz ? 25 MHz pixel clock ? ~16.67 ms per frame
    constant frame_period : time := 16.67 ms;
    constant line_period  : time := 31.77 us;   -- approx. 1 line = 31.77 µs
    constant visible_lines : integer := 480;
    constant visible_pixels : integer := 640;
    
    variable line_counter : integer := 0;
    variable pixel_counter : integer := 0;
  begin
    -- Initial switch and reset setup
    threshold_factor <= "10"; --75% threshold setting

    reset_n_i <= '0';
    wait for 50 ns;
    reset_n_i <= '1';

    -- Enter sample mode briefly to gather max amplitude
    sample_mode_i <= '1';
    wait for clk_period * 2;
    sample_mode_i <= '0';
    wait for 50 ns;

    -- Simulate for 3 video frames
    -- One frame: 525 lines of 800 pixels each
    for frame in 0 to 2 loop
        fsync_i(0) <= '1';
        wait for clk_period * 4;
        fsync_i(0) <= '0';
    
        for line in 0 to 524 loop
            -- Set vsync low during lines 490-492
            if line >= 490 and line <= 492 then
                vsync_i <= '0';
            else
                vsync_i <= '1';
            end if;
    
            for pixel in 0 to 799 loop  -- Full 800-pixel line
                -- Set hsync low during pixels 656-752
                if pixel >= 656 and pixel <= 752 then
                    hsync_i <= '0';
                else
                    hsync_i <= '1';
                end if;
    
                -- Active video during visible area
                if line < 480 and pixel < 640 then
                    active_video_i <= '1';
                else
                    active_video_i <= '0';
                end if;
    
                wait for clk_period*4;  -- Wait one pixel clock
            end loop;
        end loop;
    end loop;




    wait;
  end process;
  
end behavior;
