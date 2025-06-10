----------------------------------------------------------------------------
--  ENGS 128 Final Project
----------------------------------------------------------------------------
--  Testbench for beat detection block
--  Author: Natalie Schreder
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_beat_detect is
end tb_beat_detect;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture testbench of tb_beat_detect is
----------------------------------------------------------------------------
-- Define Constants and Signals

    -- Constants
    constant DATA_WIDTH    : integer := 32;
    constant AMP_WIDTH     : integer := 4;
    constant CLOCK_PERIOD  : time := 10 ns;

    -- DUT input signals
    signal clk              : std_logic := '0';
    signal reset            : std_logic := '0';
    signal tvalid           : std_logic := '0';
    signal data_in          : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal sample_mode      : std_logic := '1'; -- start in sample mode
    signal threshold_factor : std_logic_vector(1 downto 0) := "00"; -- 100%

    -- DUT output signals
    signal beat_detected        : std_logic;
    signal detected_amplitude   : std_logic_vector(23 downto 0);
    
    signal mute_en_sw           : std_logic := '0';

----------------------------------------------------------------------------   
-- Component declarations
----------------------------------------------------------------------------  
component beat_detection is
    generic (
        DATA_WIDTH : integer := 32;
        AMP_WIDTH  : integer := 4 );
    port (
        s00_axis_clock        : in std_logic;
        m00_axis_tvalid       : in std_logic;
        data_in               : in std_logic_vector(DATA_WIDTH-1 downto 0);
        threshold_factor_i      : in std_logic_vector(1 downto 0);
        sample_mode_i           : in std_logic;
        reset_n_i               : in std_logic;
        beat_detected_o         : out std_logic;
        detected_amplitude_o    : out std_logic_vector(23 downto 0)
    );
end component;


begin

----------------------------------------------------------------------------   
-- Clock Generation Processes
----------------------------------------------------------------------------  
-- Generate 100 MHz ADC clock      
adc_clock_gen_process : process
begin
	clk <= '0';				-- start low
	wait for CLOCK_PERIOD;	    -- wait for one CLOCK_PERIOD
	
	loop							-- toggle, wait half a clock period, and loop
	  clk <= not(clk);
	  wait for CLOCK_PERIOD/2;
	end loop;
end process adc_clock_gen_process;
-- Disable mute
mute_en_sw <= '0';

--------------------------------------------------------------------------------
    -- DUT Instantiation
    dut: beat_detection
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            AMP_WIDTH  => AMP_WIDTH
        )
        port map (
            s00_axis_clock     => clk,
            m00_axis_tvalid    => tvalid,
            data_in            => data_in,
            threshold_factor_i   => threshold_factor,
            sample_mode_i        => sample_mode,
            reset_n_i            => reset,
            beat_detected_o      => beat_detected,
            detected_amplitude_o => detected_amplitude
        );

---------------------------------------------------------------------------------
    -- Stimulus Process
    stim_proc : process
    begin
        -- Reset
        reset <= '1'; wait for CLOCK_PERIOD * 2;
        reset <= '0'; wait for CLOCK_PERIOD * 2;

        -- Sample Phase (Collect samples to find max amplitude)
        sample_mode <= '1';
        for i in 0 to 300 loop
            tvalid <= '1';
            -- simulate audio values increasing linearly
            data_in <= std_logic_vector(to_unsigned(i * 1000, 32));
            wait for CLOCK_PERIOD;
        end loop;

        wait for CLOCK_PERIOD;
        sample_mode <= '0'; -- done sampling

        -- Wait for FindThreshold ? DetectBeat transition
        wait for CLOCK_PERIOD * 3;

        -- Inject a value that exceeds the threshold
        tvalid <= '1';
        data_in <= std_logic_vector(to_unsigned(260000, 32)); -- simulate beat
        wait for CLOCK_PERIOD;

        -- Drop below threshold
        data_in <= std_logic_vector(to_unsigned(100000, 32));
        wait for CLOCK_PERIOD * 300;

        tvalid <= '0';

        -- Finish
        wait for CLOCK_PERIOD * 10;
    end process;

end testbench;
