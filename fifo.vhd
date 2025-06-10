----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: FIFO buffer with AXI stream valid signal
----------------------------------------------------------------------------
-- Library Declarations
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity definition
entity fifo is
Generic (
    FIFO_DEPTH : integer := 128;
    DATA_WIDTH : integer := 32);
Port ( 
    clk_i       : in std_logic;
    reset_i     : in std_logic;
    
    -- Write channel
    wr_en_i     : in std_logic;
    wr_data_i   : in std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Read channel
    rd_en_i     : in std_logic;
    rd_data_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Status flags
    empty_o         : out std_logic;
    full_o          : out std_logic);   
end fifo;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of fifo is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
type mem_type is array (0 to FIFO_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal fifo_buf : mem_type := (others => (others => '0'));

signal read_pointer, write_pointer : integer range 0 to FIFO_DEPTH-1 := 0;
signal data_count : integer range 0 to FIFO_DEPTH := 0;
signal empty_s, full_s, almost_empty_s, almost_full_s : std_logic := '0';
----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Processes and Logic
----------------------------------------------------------------------------
write_data : process(clk_i)
begin
    if rising_edge(clk_i) then 
        if reset_i = '1' then 
            for i in 0 to FIFO_DEPTH-1 loop
                fifo_buf(i) <= (others => '0');
            end loop;
        elsif wr_en_i = '1' and full_s = '0' then 
            fifo_buf(write_pointer) <= wr_data_i; --write in
        end if;
    end if;
end process;


write_counter : process(clk_i)
begin
    if rising_edge(clk_i) then 
        if reset_i = '1' or write_pointer = FIFO_DEPTH-1 then
           write_pointer <= 0;
        elsif wr_en_i = '1' and full_s = '0' then    
            write_pointer <= write_pointer+1; --write address
        end if;
    end if;
end process;

read_data : process(clk_i)
begin
    if rising_edge(clk_i) then  
        if rd_en_i = '1' and empty_s = '0' then 
            rd_data_o <= fifo_buf(read_pointer); --read out
        end if;
    end if;
end process;

read_counter : process(clk_i, rd_en_i)
begin
    if rising_edge(clk_i) then
        if reset_i = '1' or read_pointer = FIFO_DEPTH-1 then
            read_pointer <= 0;
        elsif rd_en_i = '1' and empty_s = '0' then    
            read_pointer <= read_pointer +1; --read address
        end if;
    end if;
end process;

Full_empty_counter : process(clk_i, wr_en_i, rd_en_i)
begin  
    if rising_edge(clk_i) then 

    --count the data address going up and down
        if reset_i = '0' then
        
            if wr_en_i='1' and rd_en_i = '0' then
                if full_s = '0' then
                    data_count <= data_count+1;  
                end if;
            
            elsif rd_en_i='1' and wr_en_i = '0' then
                if empty_s = '0' then
                    data_count <= data_count-1;  
                end if;
                
            elsif wr_en_i='1' and rd_en_i = '1' then
                --if empty_s = '1' then
                    data_count <= data_count;--+1?  
--                elsif full_s = '1' then
--                    data_count <= data_count;  ---1?
                --end if;
            end if;

        elsif reset_i = '1' then
            data_count <= 0;
        end if;
    end if;
end process;

Full_empty_mux : process(clk_i, data_count, almost_empty_s, almost_full_s)
begin
        --almost empty
        if data_count = 1 then
            almost_empty_s <= '1';
        else
            almost_empty_s <= '0';
        end if;
--almost full
        if data_count = FIFO_DEPTH-1 then
            almost_full_s <= '1';
        else
            almost_full_s <= '0';
        end if; 
     --empty
        if data_count = 0 and almost_empty_s = '1' then
            empty_s <= '1';
        elsif data_count = 0 then
            empty_s <= '1';
        else
            empty_s <= '0';
        end if;     
     
     --full   
        if data_count = FIFO_DEPTH and almost_full_s = '1' then
            full_s <= '1';
        elsif data_count = FIFO_DEPTH then
            full_s <= '1';
        else
            full_s <= '0';
        end if;         
               
end process;

    empty_o <= empty_s;
    full_o <= full_s;

end Behavioral;