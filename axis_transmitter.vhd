----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Mateo Oyola
----------------------------------------------------------------------------
--	Description: i2s->axi->fifo transmitter
----------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity axis_transmitter is
generic (
		DATA_WIDTH	: integer	:= 32;
		FIFO_DEPTH	: integer	:= 1024;
		AC_DATA_WIDTH : integer := 24
	);
  Port (
        --i2s clk
        lrclk_i               : in std_logic; --for controls
        --i2s from rx
        left_audio_data_i     : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_i    : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		--fifo in
        m00_axis_aclk     : in std_logic; --for clocking
		m00_axis_aresetn  : in std_logic;


		m00_axis_tready   : in std_logic;
		--fifo out
		m00_axis_tdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
		m00_axis_tvalid   : out std_logic;
		--optional
		m00_axis_tstrb    : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic
   );
end axis_transmitter;
----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of axis_transmitter is
----------------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------------  
signal axis_tvalid  : std_logic  := '0';
signal data_left_sync, data_right_sync, data_lr_sync, data_tx: std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
signal lr_mux_sel, data_reg_enable : std_logic  := '0';
constant LR_BIT_INDEX : integer := DATA_WIDTH-1;

type state_type is (IdleHigh, LatchInputsRight, SetRightValid, IdleLow, LatchInputsLeft, SetLeftValid);
signal curr_state, next_state : state_type := IdleHigh;
----------------------------------------------------------------------------
-- Component Declarations
---------------------------------------------------------------------------- 
begin

----------------------------------------------------------------------------
-- Logic
----------------------------------------------------------------------------  
latch_audio_inputs : process(m00_axis_aclk, data_reg_enable)
begin
    if rising_edge(m00_axis_aclk) then 
        if data_reg_enable = '1' then
        
            -- left data register
            data_left_sync <= (others => '0');
            data_left_sync(AC_DATA_WIDTH-1 downto 0) <= left_audio_data_i ;
            
            -- right data register
            data_right_sync <= (others => '0');
            data_right_sync(LR_BIT_INDEX) <= '1';
            data_right_sync(AC_DATA_WIDTH-1 downto 0) <= right_audio_data_i ;
        end if;
    end if;
end process latch_audio_inputs; 
            
axi_stream_logic : process(lr_mux_sel, data_left_sync, data_right_sync)
begin
    if lr_mux_sel = '1' then 
        data_tx <= data_left_sync;
    else
        data_tx <= data_right_sync;
    end if;
end process axi_stream_logic;

state_update: process(m00_axis_aclk )
begin
    if (falling_edge(m00_axis_aclk )) then
        curr_state <= next_state;
    end if;
end process state_update;


-- State machine: next state logic
next_state_logic : process(curr_state, m00_axis_aclk, lrclk_i, m00_axis_tready)
begin
    -- Default
    next_state <= curr_state;
    
    case curr_state is
        when IdleHigh =>
            if lrclk_i = '0' then
                next_state <= LatchInputsRight;
            end if;
        when LatchInputsRight =>
            next_state <= SetRightValid ;
        when SetRightValid =>
            if m00_axis_tready = '1' then
                next_state <= IdleLow;
            end if;
        when IdleLow =>
            if lrclk_i = '1' then
                next_state <= LatchInputsLeft;
            end if;
        when LatchInputsLeft =>
            next_state <= SetLeftValid;
        when SetLeftValid =>   
             if m00_axis_tready = '1' then
                next_state <= IdleHigh;
             end if;
        when others =>
            next_state <= IdleHigh;           
     end case;
end process next_state_logic;


-- State machine: output logic
output_logic: process(curr_state, m00_axis_aclk)    -- clocked this process to try to fix latching issues
begin
if rising_edge(m00_axis_aclk) then
    case curr_state is
        when IdleHigh =>
            lr_mux_sel <= '1';
            data_reg_enable <= '0';
            m00_axis_tvalid <= '0';
            axis_tvalid <= '0';
        
        when LatchInputsRight =>
            lr_mux_sel <= '0';
            data_reg_enable <= '1';
            m00_axis_tvalid <= '0';
            axis_tvalid <= '0';

        when SetRightValid =>
            lr_mux_sel <= '0';
            data_reg_enable <= '0';
            m00_axis_tvalid <= '1';
            axis_tvalid <= '1';

        when IdleLow =>
            lr_mux_sel <= '0';
            data_reg_enable <= '0';
            m00_axis_tvalid <= '0';
            axis_tvalid <= '0';
            
        when LatchInputsLeft =>
            lr_mux_sel <= '0';
            data_reg_enable <= '1';
            m00_axis_tvalid <= '0';
            axis_tvalid <= '0';
        
        when SetLeftValid =>
            lr_mux_sel <= '1';
            data_reg_enable <= '0';
            m00_axis_tvalid <= '1';
            axis_tvalid <= '1';
    end case;
 end if;  
end process output_logic;

m00_axis_tdata <= data_tx;
m00_axis_tstrb <= (others =>'1');
m00_axis_tlast <= '1';
end Behavioral;