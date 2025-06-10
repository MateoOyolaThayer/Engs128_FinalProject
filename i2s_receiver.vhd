----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: I2S receiver for SSM2603 audio codec
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
----------------------------------------------------------------------------
-- Entity definition
entity i2s_receiver is
    Generic (AC_DATA_WIDTH : integer := 24);
    Port (

        -- Timing
		mclk_i    : in std_logic;	
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic;
		
		-- Data
		left_audio_data_o     : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_o    : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		adc_serial_data_i     : in std_logic);  
end i2s_receiver;
----------------------------------------------------------------------------
architecture Behavioral of i2s_receiver is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
-- FSM states
type state_type is (IdleRight, ShiftLeft, LoadLeft, IdleLeft, ShiftRight, LoadRight);
signal curr_state, next_state : state_type := IdleRight;

-- Control Signals
signal load_left_enable	: std_logic := '0';
signal load_right_enable : std_logic := '0';
signal shift_enable	: std_logic := '0';

-- Shift register
signal shift_count_tc : std_logic := '0';
signal shift_count : unsigned(4 downto 0)  := (others => '0');
signal audio_shift_register	: std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Shift counter
shift_counter: process(bclk_i)
begin
    if rising_edge(bclk_i) then
        if shift_enable = '1' then 
            shift_count <= shift_count + 1;
        else 
            shift_count <= (others => '0');
        end if;
    end if;

end process shift_counter;
----------------------------------------------------------------------------
shift_count_tc <= '1' when shift_count = AC_DATA_WIDTH-1 else '0';
----------------------------------------------------------------------------
-- Shift register
left_shift_register: process(bclk_i) 
begin
	if rising_edge(bclk_i) then
		if shift_enable = '1' then
			audio_shift_register <= audio_shift_register(AC_DATA_WIDTH-2 downto 0) & adc_serial_data_i;
	    else
	        audio_shift_register <= (others => '0');
	    end if;
	    
	    -- set outputs
		if load_left_enable = '1' then
			left_audio_data_o <= audio_shift_register;
		elsif load_right_enable = '1' then
			right_audio_data_o <= audio_shift_register;
		end if;
    end if;
end process left_shift_register;
----------------------------------------------------------------------------
-- State machine
----------------------------------------------------------------------------
-- FSM Next State Logic (asynchronous, no clock)
-- Include all state change triggering signals in the sensitivity list
-- The only signal getting assigned in this process should be next_state
next_state_logic : process(curr_state, lrclk_i, shift_count_tc) 
begin

	-- Default conditions
	next_state <= curr_state; 	-- default is to stay in the same state

	case curr_state is
		when IdleRight =>
			if (lrclk_i = '0') then
				next_state <= ShiftLeft;
			end if;
			
		when ShiftLeft =>
			if (shift_count_tc = '1') then
				next_state <= LoadLeft;
			end if;
			
		when LoadLeft =>
			next_state <= IdleLeft;
			
		when IdleLeft =>
			if (lrclk_i = '1') then
				next_state <= ShiftRight;
			end if;
			
		when ShiftRight =>
			if (shift_count_tc = '1') then
				next_state <= LoadRight;
			end if;
			
		when LoadRight  =>
			next_state <= IdleRight;	

	end case;
end process next_state_logic;

----------------------------------------------------------------------------
-- FSM Output Logic Process (asynchronous, no clock)
-- Only the current state signal (curr_state) should be in the sensitivity list
-- FSM "outputs" are simply signals or ports that are assigned by the FSM state logic
fsm_output_logic : process(curr_state) 
begin
    -- Defaults
	shift_enable		<= '0';
	load_left_enable	<= '0';	
	load_right_enable	<= '0';
	
	case curr_state is
		when IdleRight =>
			
		when ShiftLeft =>
			shift_enable <= '1';
			
		when LoadLeft =>
			load_left_enable <= '1';
			
		when IdleLeft =>
			
		when ShiftRight =>
			shift_enable <= '1';
			
		when LoadRight  =>
			load_right_enable <= '1';	
	end case;
end process fsm_output_logic;

----------------------------------------------------------------------------
-- FSM State Update Process (synchronous, clocked)
state_update : process (bclk_i)
begin
	if (rising_edge(bclk_i)) then
		curr_state <= next_state; 		-- update current state on rising edge of the clock
	end if;
end process state_update;


---------------------------------------------------------------------------- 
end Behavioral;