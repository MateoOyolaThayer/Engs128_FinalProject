----------------------------------------------------------------------------------
--E 128 final proj
--Frame generator TB
--Mateo Oyola
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;

entity tb_frame_gen is
-- Testbench has no ports
end entity;

architecture Behavioral of tb_frame_gen is

  -- Component declaration
  component frame_gen is
    Port ( 
      pclk_i : IN STD_LOGIC;
      beat_i : IN STD_LOGIC;
      amplitude_i : IN std_logic_vector(23 downto 0);
      
      video_red_o   : OUT std_logic_vector(7 downto 0);
      video_green_o : OUT std_logic_vector(7 downto 0);
      video_blue_o  : OUT std_logic_vector(7 downto 0)
    );
  end component;

  -- Signals to connect to DUT
  signal pclk_i     : std_logic := '0';
  signal beat_i     : std_logic := '0';
  signal amplitude_i: std_logic_vector(23 downto 0) := (others => '0');

  signal video_red   : std_logic_vector(7 downto 0);
  signal video_green : std_logic_vector(7 downto 0);
  signal video_blue  : std_logic_vector(7 downto 0);

  -- Internal access to radius signal is not possible directly,
  -- so we'll simulate radius indirectly by monitoring beat and amplitude changes.
  
  -- Clock period for 100 MHz
  constant CLK_PERIOD : time := 10 ns;

  -- File for printing
  file output_file : text open write_mode is "simulation_output.txt";

begin

  -- Instantiate DUT
  uut: frame_gen port map (
    pclk_i      => pclk_i,
    beat_i      => beat_i,
    amplitude_i => amplitude_i,
    video_red_o   => video_red,
    video_green_o => video_green,
    video_blue_o  => video_blue
  );

  -- Clock generation process: 100 MHz clock
  clk_process : process
  begin
    pclk_i <= '0';
    wait for CLK_PERIOD/2;
      loop
        pclk_i <= not(pclk_i);
        wait for CLK_PERIOD/2;
    end loop;
    wait;
  end process clk_process;

  -- Beat signal generator: pulse '1' for 1 clock cycle every 100 ns
  beat_process : process
  begin
      beat_i <= '0';
      wait for 1 us;
        loop
            beat_i <= not(beat_i);
            wait for CLK_PERIOD*10;
        end loop;
    wait;
  end process beat_process;
  
  --STIMULUS process
  --increase amplitude up and down
  amplitude_process : process
  begin
    amplitude_i <= "000000000000000000000000";
    
    wait for 1 us;
    
    wait for CLK_PERIOD*307200;
    amplitude_i <= "000000000000000000000001";
    wait for CLK_PERIOD*307200;
    amplitude_i <= "000000000000000000010001";
    wait for CLK_PERIOD*307200;
    amplitude_i <= "000000000000010000010001";    
    wait for CLK_PERIOD*307200;
    amplitude_i <= "001000000000010000010001";       
    wait for CLK_PERIOD*307200;
    amplitude_i <= "111111111111111111111111";       
    wait for CLK_PERIOD*307200;    
    amplitude_i <= "001000000000010000010001";  
    wait for CLK_PERIOD*307200;
    amplitude_i <= "000000000000010000010001";       
    wait for CLK_PERIOD*307200;
    amplitude_i <= "000000000000000000010001";    
    wait for CLK_PERIOD*307200;
    amplitude_i <= "000000000000000000000001";
    wait for CLK_PERIOD*307200;
    amplitude_i <= "000000000000000000000000";        
    
  end process amplitude_process;
end Behavioral;
