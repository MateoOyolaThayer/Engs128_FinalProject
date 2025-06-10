----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Mateo Oyola
----------------------------------------------------------------------------
--	Description: i2s->axi->fifo receiver
----------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity axis_receiver is
generic (
		DATA_WIDTH	: integer	:= 32;
		FIFO_DEPTH	: integer	:= 256;
		AC_DATA_WIDTH : integer := 24
	);
  Port (
        --i2s clk
        lrclk_i               : in std_logic; --for controls
        --i2s to tx
        left_audio_data_o     : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_o    : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		--fifo in
        s00_axis_aclk     : in std_logic; --for clocking
		s00_axis_aresetn  : in std_logic;
		s00_axis_tdata    : in std_logic_vector(DATA_WIDTH-1 downto 0);
		s00_axis_tvalid   : in std_logic;
		--fifo out
		s00_axis_tready   : out std_logic;


		--optional
		s00_axis_tstrb    : in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic
   );
end axis_receiver;
----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of axis_receiver is
----------------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------------  
signal s_axis_tready, data_reg_enable  : std_logic  := '0';
signal axis_data_0, axis_data_1: std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
signal data_rx: std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

type state_type is (IdleHigh, LatchOutputsRight, SetRightReady, IdleLow, LatchOutputsLeft, SetLeftReady);
signal curr_state, next_state : state_type := IdleHigh;
----------------------------------------------------------------------------
-- Component Declarations
---------------------------------------------------------------------------- 
----------------------------------------------------------------------------
-- Component Instantiations
------------------------------------------------------------------------------   
begin
----------------------------------------------------------------------------
-- Logic
----------------------------------------------------------------------------  
latch_audio_data : process(s00_axis_aclk) --latch data in when valid and ready
begin
    if rising_edge(s00_axis_aclk) then
        if (s00_axis_tvalid='1' and s_axis_tready ='1') then
            axis_data_0 <= s00_axis_tdata;
            axis_data_1 <= axis_data_0;
        end if;
    end if;
end process latch_audio_data;

latch_audio_outputs : process(s00_axis_aclk)
    variable lr_data_bit: std_logic;
begin
    if rising_edge(s00_axis_aclk) then
        if (data_reg_enable ='1') then
            lr_data_bit := axis_data_1(31); --select bit padded to front, 0 L and 1 R
            if (lr_data_bit = '0') then
                left_audio_data_o <= axis_data_1(AC_DATA_WIDTH -1 downto 0);
                --right_audio_data_o <= axis_data_0(AC_DATA_WIDTH -1 downto 0);
            else
                --left_audio_data_o <= axis_data_0(AC_DATA_WIDTH -1 downto 0);
                right_audio_data_o <= axis_data_1(AC_DATA_WIDTH -1 downto 0);
            end if;
        end if;
    end if;
end process latch_audio_outputs;

state_update: process(s00_axis_aclk)
begin
    if (falling_edge(s00_axis_aclk)) then
        curr_state <= next_state;
    end if;
end process state_update;

-- State machine: next state logic
next_state_logic : process(curr_state, s00_axis_aclk, lrclk_i, s00_axis_tvalid)
begin
    -- Default
    next_state <= curr_state;
    
    case curr_state is
        when IdleHigh =>
            if lrclk_i='0' then
                next_state <= LatchOutputsRight;
            end if;
        when LatchOutputsRight =>
                next_state <= SetRightReady;
        when SetRightReady =>
            if s00_axis_tvalid='1' then
                next_state <= IdleLow;
            end if;
        when IdleLow =>
            if lrclk_i='1' then
                next_state <= LatchOutputsLeft;
            end if;
        when LatchOutputsLeft =>
                next_state <= SetLeftReady;
        when SetLeftReady =>
            if s00_axis_tvalid='1' then
                next_state <= IdleHigh;
            end if;
        when others =>
            next_state <= IdleHigh;           
     end case;
end process next_state_logic;


-- State machine: output logic
output_logic: process(curr_state, s00_axis_aclk )   -- clocked this process to try to fix latching issues
begin
    if rising_edge(s00_axis_aclk) then
        case curr_state is
            when IdleHigh =>
                s_axis_tready <= '0';
                data_reg_enable <= '0';
            when LatchOutputsRight =>
                s_axis_tready <= '0';
                data_reg_enable <= '1';
            when SetRightReady =>
                s_axis_tready <= '1';
                data_reg_enable <= '0';
            when IdleLow =>
                s_axis_tready <= '0';
                data_reg_enable <= '0';
            when LatchOutputsLeft =>
                s_axis_tready <= '0';
                data_reg_enable <= '1';
            when SetLeftReady =>
                s_axis_tready <= '1';
                data_reg_enable <= '0';
            when others =>    
        end case;
    end if;
end process output_logic;

s00_axis_tready <= s_axis_tready;

end Behavioral;
