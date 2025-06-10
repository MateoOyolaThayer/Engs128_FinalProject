----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Kendall Farnham
--  Natalie Schreder Lab 2
----------------------------------------------------------------------------
--	Description: AXI Stream FIFO Controller/Responder Interface 
----------------------------------------------------------------------------
-- Library Declarations
library ieee;
use ieee.std_logic_1164.all;
library UNISIM;
use UNISIM.VComponents.all;
----------------------------------------------------------------------------
-- Entity definition
entity axis_fifo is
	generic (
		DATA_WIDTH	: integer	:= 32;
		FIFO_DEPTH	: integer	:= 128
	);
	port (
	
		-- Ports of Axi Responder Bus Interface S00_AXIS
		s00_axis_aclk     : in std_logic;
		s00_axis_aresetn  : in std_logic;
		s00_axis_tready   : out std_logic;
		s00_axis_tdata	  : in std_logic_vector(DATA_WIDTH-1 downto 0);
		s00_axis_tstrb    : in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic;

		-- Ports of Axi Controller Bus Interface M00_AXIS
		m00_axis_aclk     : in std_logic;
		m00_axis_aresetn  : in std_logic;
		m00_axis_tvalid   : out std_logic;
		m00_axis_tdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   : in std_logic
	);
end axis_fifo;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of axis_fifo is
----------------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------------  
signal wr_en_s   : std_logic;
signal rd_en_s   : std_logic;
signal wr_data_s : std_logic_vector(DATA_WIDTH-1 downto 0);
signal rd_data_s : std_logic_vector(DATA_WIDTH-1 downto 0);
signal full_s    : std_logic;
signal empty_s   : std_logic;
signal reset_s : std_logic;
signal reset_buf : std_logic;
----------------------------------------------------------------------------
-- Component Declarations
----------------------------------------------------------------------------  

component fifo is
    Generic (
		FIFO_DEPTH : integer := FIFO_DEPTH;
        DATA_WIDTH : integer := DATA_WIDTH);
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
end component fifo;

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Component Instantiations
----------------------------------------------------------------------------   
fifo_inst : fifo
    generic map (
        FIFO_DEPTH => FIFO_DEPTH,
        DATA_WIDTH => DATA_WIDTH )
    port map (
        clk_i     => s00_axis_aclk,
        reset_i   => reset_buf, 
        wr_en_i   => wr_en_s,
        wr_data_i => wr_data_s,
        rd_en_i   => rd_en_s,
        rd_data_o => rd_data_s,
        empty_o   => empty_s,
        full_o    => full_s
    );

----------------------------------------------------------------------------
-- Logic
----------------------------------------------------------------------------  
-- Write side (Responder interface)
wr_en_s   <= s00_axis_tvalid and (not full_s);  
wr_data_s <= s00_axis_tdata;
s00_axis_tready <= '0' when s00_axis_aresetn = '0' else not full_s;                  

-- Read side (Controller interface)
rd_en_s   <= m00_axis_tready and (not empty_s); 
m00_axis_tvalid <= not empty_s;                    
m00_axis_tdata  <= rd_data_s;
m00_axis_tstrb  <= (others => '1');                   -- not really sure what this is for
m00_axis_tlast  <= '0';                               -- also idk 

reset_s <= not s00_axis_aresetn;

-- BUFG instantiation for Reset Signal
BUFG_RST_INST : BUFG
    port map (
        I => reset_s,  -- Input: your reset signal (typically from the Proc Sys Reset block)
        O => reset_buf  -- Output: buffered reset signal that will be used in the design
    );

end Behavioral;