----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Mateo Oyola
----------------------------------------------------------------------------
--	Description: i2s clock generator with oddr
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

library UNISIM;
use UNISIM.VComponents.all;     -- contains BUFG clock buffer

----------------------------------------------------------------------------
-- Entity definition
entity i2s_clock_gen is
    Port (
        -- System clock in
		sysclk_125MHz_i   : in  std_logic;	
		-- Forwarded clocks
		mclk_fwd_o		  : out std_logic;	
		bclk_fwd_o        : out std_logic;
		adc_lrclk_fwd_o   : out std_logic;
		dac_lrclk_fwd_o   : out std_logic;

        -- Clocks for I2S components
		mclk_o		      : out std_logic;	
		bclk_o            : out std_logic;
		lrclk_o           : out std_logic);  
end i2s_clock_gen;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of i2s_clock_gen is
------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
 --keep for debugging 
                 --component clk_wiz_0 is
                --port (
                --    --Clock out ports
                  
                --    clk_out1          : out    std_logic;
                  
                --   reset             : in     std_logic;
                --  locked            : out    std_logic;
                --   --Clock in ports
                --  clk_in1           : in     std_logic 
                
                -- );
                --end component;

-- COMP_TAG_END ------ End COMPONENT Declaration ------------
component clock_divider is
        generic (CLK_DIV_RATIO : integer := 4);
        port (
            fast_clk_i : in  std_logic;
            slow_clk_o : out std_logic
        );
    end component;

    component clock_divider_fall is
        generic (CLK_DIV_RATIO_FALL : integer := 64);
        port (
            fast_clk_fall_i : in  std_logic;
            slow_clk_fall_o : out std_logic
        );
    end component;

----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
-- Clocking Wizard output
    signal mclk_s : std_logic := '0';
    signal bclk_s : std_logic := '0';
    signal lrclk_s : std_logic := '0';
----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- The following code must appear in the VHDL architecture
-- body. Substitute your own instance name and net names.
------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG

 --keep for debugging --our_instance_name : clk_wiz_0
                -- port map ( 
                --     --Clock out ports  
                --clk_out1 => mclk_s,
                     
                  
                --     --Status and control signals                
                --reset => '0',
                --locked => open,
                --      --Clock in ports
                -- clk_in1 => sysclk_125MHz_i
                -- );
 --for hardware
 mclk_s <= sysclk_125MHz_i;
-- INST_TAG_END ------ End INSTANTIATION Template ------------
    bclk_div: clock_divider
        generic map (CLK_DIV_RATIO => 4)
        port map (
            fast_clk_i => mclk_s,
            slow_clk_o => bclk_s
        );

    lrclk_div: clock_divider_fall
        generic map (CLK_DIV_RATIO_FALL => 64)
        port map (
            fast_clk_fall_i => bclk_s,
            slow_clk_fall_o => lrclk_s
        );


-- Assign direct outputs
    mclk_o  <= mclk_s;
    bclk_o  <= bclk_s;
    lrclk_o <= lrclk_s;

    -- ODDR output forwarding
    mclk_forward: ODDR
        generic map (
            DDR_CLK_EDGE => "SAME_EDGE",
            INIT         => '0',
            SRTYPE       => "SYNC"
        )
        port map (
            Q  => mclk_fwd_o,
            C  => mclk_s,
            CE => '1',
            D1 => '1',
            D2 => '0',
            R  => '0',
            S  => '0'
        );

    bclk_forward: ODDR
        generic map (
            DDR_CLK_EDGE => "SAME_EDGE",
            INIT         => '0',
            SRTYPE       => "SYNC"
        )
        port map (
            Q  => bclk_fwd_o,
            C  => bclk_s,
            CE => '1',
            D1 => '1',
            D2 => '0',
            R  => '0',
            S  => '0'
        );

    lrclk_forward_adc: ODDR
        generic map (
            DDR_CLK_EDGE => "SAME_EDGE",
            INIT         => '0',
            SRTYPE       => "SYNC"
        )
        port map (
            Q  => adc_lrclk_fwd_o,
            C  => lrclk_s,
            CE => '1',
            D1 => '1',
            D2 => '0',
            R  => '0',
            S  => '0'
        );



lrclk_forward_dac: ODDR
    generic map (
        DDR_CLK_EDGE => "SAME_EDGE",
        INIT         => '0',
        SRTYPE       => "SYNC"
    )
    port map (
        Q  => dac_lrclk_fwd_o,
        C  => lrclk_s,
        CE => '1',
        D1 => '1',
        D2 => '0',
        R  => '0',
        S  => '0'
    );

end Behavioral;

