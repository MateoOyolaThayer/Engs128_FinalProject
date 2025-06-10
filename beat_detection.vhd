----------------------------------------------------------------------------------
-- ENGS 128 Final Project
-- Beat Detection block
-- Author: Natalie Schreder
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;


entity beat_detection is
    generic (
        DATA_WIDTH : integer := 32;
        AMP_WIDTH  : integer := 4 );
    port (
        s00_axis_clock          : in std_logic;
        m00_axis_tvalid         : in std_logic;     -- should come from output of lowpass filter
        data_in                 : in std_logic_vector(DATA_WIDTH-1 downto 0);
        threshold_factor_i        : in std_logic_vector(1 downto 0);
        sample_mode_i             : in std_logic;     -- 1 if in sample mode, 0 if not
        reset_i                 : in std_logic;
        fsync_i                    : in std_logic_vector(0 downto 0); 
        max_amplitude_o         : out std_logic_vector(23 downto 0);
        
        beat_detected_o           : out std_logic;
        detected_amplitude_o      : out std_logic_vector(23 downto 0);      
        
        dbg_max_amplitude_o       : out std_logic_vector(23 downto 0);
        dbg_beat_detected_o       : out std_logic;
        dbg_detected_amplitude_o  : out std_logic_vector(23 downto 0)
    );
end beat_detection;


----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of beat_detection is
----------------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------------  
signal data_in_s        : signed(23 downto 0) := (others => '0');

-- FSM states
type state_type is (Idle, Sample, FindThreshold, DetectBeat);
signal curr_state, next_state : state_type := Idle;

-- Internal signals
signal sample_index       : integer range 0 to 255 := 0;
signal max_amplitude      : std_logic_vector(23 downto 0) := (others => '0');
signal threshold_value    : std_logic_vector(23 downto 0);
signal sample_complete    : std_logic := '0';
signal shift_en_s         : std_logic := '0';
signal detect_en_s        : std_logic := '0';
signal beat_detected_s    : std_logic := '0';
signal detected_amplitude_s     : std_logic_vector(23 downto 0) := (others => '0');

begin
----------------------------------------------------------------------------
-- State machine
----------------------------------------------------------------------------
-- FSM Next State Logic (asynchronous, no clock)
-- Include all state change triggering signals in the sensitivity list
-- The only signal getting assigned in this process should be next_state
next_state_logic : process(curr_state, m00_axis_tvalid, sample_mode_i, reset_i, sample_complete, beat_detected_s) 
begin

	-- Default conditions
	next_state <= curr_state; 	-- default is to stay in the same state

	case curr_state is
	   when Idle =>
	       if (m00_axis_tvalid = '1') and (sample_mode_i = '1') then
	           next_state <= Sample;
	       end if;
	       
	   when Sample =>
	       if sample_complete = '1' then
                next_state <= FindThreshold;
	       end if;
	   
	   when FindThreshold =>
	       next_state <= DetectBeat;
	   
	   when DetectBeat =>
	       if (reset_i = '1') then
	           next_state <= Idle;
	       end if;
	   
	   end case;
	   
end process next_state_logic;

----------------------------------------------------------------------------
-- FSM Output Logic Process (asynchronous, no clock)
-- Only the current state signal (curr_state) should be in the sensitivity list
-- FSM "outputs" are simply signals or ports that are assigned by the FSM state logic
fsm_output_logic : process(curr_state, threshold_factor_i, m00_axis_tvalid) 
begin
    -- Defaults
    shift_en_s <= '0';
    detect_en_s <= '0';

	case curr_state is
		when Idle =>
            detect_en_s <= '0';
		
		when Sample =>
            shift_en_s <= '1';
            
            
       when FindThreshold =>
            shift_en_s <= '0';

            case threshold_factor_i is
                    when "00" =>  -- 100%
                        threshold_value <= max_amplitude;
                    when "01" =>  -- 75% ? max_amplitude * 3 / 4
                        threshold_value <= std_logic_vector(resize((abs(signed(max_amplitude)) * 3) / 4, 24));
                    when "10" =>  -- 50%
                        threshold_value <= std_logic_vector(resize(abs(signed(max_amplitude)) / 2, 24));
                    when "11" =>  -- 25%
                        threshold_value <= std_logic_vector(resize(abs(signed(max_amplitude)) / 4, 24));
                    when others =>
                        threshold_value <= (others => '0');
                end case;
        
        
        when DetectBeat =>
            if m00_axis_tvalid = '1' then
                detect_en_s <= '1';
            else
                detect_en_s <= '0';    
            end if;	

	end case;
end process fsm_output_logic;

----------------------------------------------------------------------------
-- FSM State Update Process (synchronous, clocked)
state_update : process (s00_axis_clock)
begin
	if (rising_edge(s00_axis_clock)) then
		curr_state <= next_state; 		-- update current state on rising edge of the clock
	end if;
end process state_update;

-----------------------------------------------------------------------------
trim_logic : process(s00_axis_clock)
begin
    if rising_edge(s00_axis_clock) then
        if m00_axis_tvalid = '1' then
            data_in_s <= (abs(signed(data_in(23 downto 0))));
        end if;
    end if;
end process;

-- Sample logic
sample_logic : process(s00_axis_clock)
begin
    if rising_edge(s00_axis_clock) then
        if shift_en_s = '1' then

            -- Update max amplitude
            if abs(signed(data_in(23 downto 0))) > abs(signed(max_amplitude)) then
                max_amplitude <= data_in(23 downto 0);
            end if;

            -- Increment sample index
            if sample_index <= 255 then
                sample_index <= sample_index + 1;
                sample_complete <= '0';
            else
                sample_complete <= '1';
            end if;
        else
            sample_index <= 0;
        end if;

    end if;
end process;


-- Beat detection logic
beat_detect_logic : process(s00_axis_clock)
begin
    if rising_edge(s00_axis_clock) then
        if detect_en_s = '1' then

            if abs(signed(data_in_s)) >= abs(signed(threshold_value)) then
                beat_detected_s <= '1';
                detected_amplitude_s <= std_logic_vector(data_in_s);
            else
                beat_detected_s <= '0';
                detected_amplitude_s <= (others => '0');
            end if;
        else
            beat_detected_s <= '0';
            detected_amplitude_s <= (others => '0');
        end if;
     end if;
     
     if fsync_i(0) = '1' then
        max_amplitude_o <= (others => '0');
        beat_detected_o <= '0';
        detected_amplitude_o <= (others => '0');
        
        dbg_max_amplitude_o <= (others => '0');
        dbg_beat_detected_o <= '0';
        dbg_detected_amplitude_o <= (others => '0');
        
     elsif beat_detected_s = '1' then
        max_amplitude_o <= max_amplitude;
        beat_detected_o <= beat_detected_s;
        detected_amplitude_o <= detected_amplitude_s;   
        
        dbg_max_amplitude_o <= max_amplitude;
        dbg_beat_detected_o <= beat_detected_s;
        dbg_detected_amplitude_o <= detected_amplitude_s; 
        
     end if;
 end process;

end Behavioral;
