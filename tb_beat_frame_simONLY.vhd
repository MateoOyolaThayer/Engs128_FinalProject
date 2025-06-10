----------------------------------------------------------------------------
--  Final proj beat detect, VTC, frame gen wrapper beat_frame_SsimONLY TESTBENCH
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Mateo Oyola
----------------------------------------------------------------------------
--  Final proj beat detect, VTC, frame gen wrapper beat_frame_SsimONLY TESTBENCH
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Mateo Oyola
----------------------------------------------------------------------------
--	Description: beat detect, VTC, frame gen wrapper beat_frame_SsimONLY TESTBENCH
----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;          

--library xil_defaultlib;
--use xil_defaultlib.fir_compiler_1_new;                          
----------------------------------------------------------------------------

entity tb_beat_frame_simONLY is
end tb_beat_frame_simONLY;

architecture behavior of tb_beat_frame_simONLY is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
  -- Testbench Signals
  signal s00_axis_clock : std_logic := '0';
  signal m00_axis_tvalid : std_logic := '1';  -- Assuming continuous data input
  signal data_in : std_logic_vector(31 downto 0);  -- Assuming 32-bit data for simplicity
  signal sw0_i, sw1_i : std_logic := '0';  -- 75% threshold setting (01)
  signal sample_mode_i : std_logic := '0';  -- Set to '0' for non-sample mode
  signal reset_i : std_logic := '1';  -- Active high reset
  
  signal pclk_i : std_logic := '0';
  
  signal video_pdata_o, dbg_max_amplitude_o, dbg_detected_amplitude_o : std_logic_vector(23 downto 0);
  signal dbg_beat_detected_o : std_logic :='0';

  -- Clock Generation (100 MHz for simulation)
  constant clk_period : time := 10 ns;
  ----------------------------------------------------------------------------
-- Component Declarations
----------------------------------------------------------------------------  
component beat_frame_simONLY is
      generic (
        DATA_WIDTH : integer := 32;
        AMP_WIDTH  : integer := 4 );
    port (
        s00_axis_clock          : in std_logic;
        m00_axis_tvalid         : in std_logic;     -- should come from output of lowpass filter
        data_in                 : in std_logic_vector(DATA_WIDTH-1 downto 0);
        sw0_i                   : in std_logic;
        sw1_i                   : in std_logic;
        sample_mode_i             : in std_logic;     -- 1 if in sample mode, 0 if not
        reset_i                 : in std_logic;
        
        pclk_i                  : in std_logic;
        
        video_pdata_o    : out std_logic_vector(23 downto 0);
        
        dbg_max_amplitude_o       : out std_logic_vector(23 downto 0);
        dbg_beat_detected_o       : out std_logic;
        dbg_detected_amplitude_o  : out std_logic_vector(23 downto 0)
        );
end component;

----------------------------------------------------------------------------

begin
----------------------------------------------------------------------------
-- Component Instantiations
----------------------------------------------------------------------------   
dut : beat_frame_simONLY
    port map(
        s00_axis_clock         => s00_axis_clock,
        m00_axis_tvalid        => m00_axis_tvalid,
        data_in          => data_in,
        sw0_i            => sw0_i,
        sw1_i            => sw1_i,
        sample_mode_i    => sample_mode_i,
        reset_i        => reset_i,
        
        pclk_i           => pclk_i,
        
        video_pdata_o    => video_pdata_o,
        
        dbg_max_amplitude_o      => dbg_max_amplitude_o,
        dbg_beat_detected_o      => dbg_beat_detected_o,
        dbg_detected_amplitude_o  => dbg_detected_amplitude_o
        
    );

  -- Clock generation process
  clk_process : process
  begin
    s00_axis_clock <= not s00_axis_clock after clk_period / 2;
    pclk_i <= not pclk_i after 54.3 ns / 2;
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

  -- Testbench stimulus
  stimulus_process : process
  begin
    -- Set the switches to 75% threshold (01)
    sw1_i <= '0';
    sw0_i <= '1';  -- MSB (highest bit of threshold)

    -- Reset signal
    reset_i <= '1';
    wait for 1 us;
    reset_i <= '0';
    sample_mode_i  <= '1';
    wait for clk_period *2;
    
    wait for 50 ns;
    
    -- Run for a few periods of the triangle wave
    wait for 40 ms;  -- Simulate for 40ms, enough for a few periods of the triangle wave

    wait;
  end process;

end behavior;
