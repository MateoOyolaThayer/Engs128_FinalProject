----------------------------------------------------------------------------
--  Lab 3: task 1 wrapper
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Mateo Oyola
----------------------------------------------------------------------------
--	Description: task 1 wrapper dds->axi->FIR->axi->i2stx
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;                                    
----------------------------------------------------------------------------
-- Entity definition
entity toplab3task1 is
	generic (
		-- Parameters of Axi Stream Bus Interface S00_AXIS, M00_AXIS
		C_AXI_STREAM_DATA_WIDTH	: integer	:= 32
	);
    Port ( 
        ----------------------------------------------------------------------------
        -- Fabric clock from Zynq PS
		sysclk_i : in  std_logic;	
		
        ----------------------------------------------------------------------------
        -- I2S audio codec ports		
		-- User controls
		ac_mute_en_i : in STD_LOGIC;
		
		-- Audio Codec I2S controls
        ac_bclk_o : out STD_LOGIC;
        ac_mclk_o : out STD_LOGIC;
        ac_mute_n_o : out STD_LOGIC;	-- Active Low
        
        -- Audio Codec DAC (audio out)
        ac_dac_data_o : out STD_LOGIC;
        ac_dac_lrclk_o : out STD_LOGIC;
        
        -- Audio Codec ADC (audio in)
        ac_adc_data_i : in STD_LOGIC;
        ac_adc_lrclk_o : out STD_LOGIC;
        
        ----------------------------------------------------------------------------
        -- AXI Stream Interface (Receiver/Responder)
    	-- Ports of Axi Responder Bus Interface S00_AXIS
		s00_axis_aclk     : in std_logic;
		s00_axis_aresetn  : in std_logic;
		s00_axis_tready   : out std_logic;
		s00_axis_tdata	  : in std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		s00_axis_tstrb    : in std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic;
		
        -- AXI Stream Interface (Tranmitter/Controller)
		-- Ports of Axi Controller Bus Interface M00_AXIS
		m00_axis_aclk     : in std_logic;
		m00_axis_aresetn  : in std_logic;
		m00_axis_tvalid   : out std_logic;
		m00_axis_tdata    : out std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   : in std_logic;
		
		--debug ports (ILA)
		dbg_left_audio_rx_o : out std_logic_vector(23 downto 0);
		dbg_left_audio_tx_o : out std_logic_vector(23 downto 0);
		dbg_right_audio_rx_o : out std_logic_vector(23 downto 0);
		dbg_right_audio_tx_o : out std_logic_vector(23 downto 0)
		
		
		);
end toplab3task1;
----------------------------------------------------------------------------
architecture Behavioral of toplab3task1 is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
-- Constants
constant AXI_DATA_WIDTH : integer := 32;        -- 32-bit AXI data bus
constant AXI_FIFO_DEPTH : integer := 12;        -- AXI stream FIFO depth
constant AC_DATA_WIDTH : integer := 24;       


  -- Clocks for I2S components
		signal mclk_s		      : std_logic := '0';	
		signal bclk_s            : std_logic := '0';
		signal lrclk_s           : std_logic := '0';


--transmitter mux and register flip flop
        signal left_audio_data_tx_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
        signal right_audio_data_tx_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
        
        --receiver outputs 
        signal left_audio_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
        signal right_audio_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
        
        --mute signals
        signal ac_mute_n_s : std_logic := '0';
        signal ac_mute_n_reg_s : std_logic := '0';

----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
-- Clock generation
component i2s_clock_gen is
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
end component;

---------------------------------------------------------------------------- 
-- I2S receiver
component i2s_receiver is
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
end component;
	
---------------------------------------------------------------------------- 
-- I2S transmitter
component i2s_transmitter is
    Generic (AC_DATA_WIDTH : integer := 24);
    Port (

        -- Timing
		mclk_i    : in std_logic;	
		bclk_i    : in std_logic;	
		lrclk_i   : in std_logic;
		
		-- Data
		left_audio_data_i     : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_i    : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		dac_serial_data_o     : out std_logic);  
end component;

---------------------------------------------------------------------------- 
-- AXI stream transmitter
    component axis_transmitter is
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
end component;
---------------------------------------------------------------------------- 
-- AXI stream receiver
component axis_receiver is
generic (
		DATA_WIDTH	: integer	:= 32;
		FIFO_DEPTH	: integer	:= 1024;
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
end component;
----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Component instantiations
----------------------------------------------------------------------------    
-- Clock generation
i2s_clk_gen_port : i2s_clock_gen
    port map(
        sysclk_125MHz_i => sysclk_i, 
		-- Forwarded clocks
		mclk_fwd_o	   => ac_mclk_o,
		bclk_fwd_o    => ac_bclk_o,
		adc_lrclk_fwd_o   => ac_adc_lrclk_o,
		dac_lrclk_fwd_o   => ac_dac_lrclk_o,

        -- Clocks for I2S components
		mclk_o	=> mclk_s,
		bclk_o  => bclk_s,
		lrclk_o => lrclk_s
    
    );
        
---------------------------------------------------------------------------- 
-- I2S receiver
i2S_receiver_port : i2s_receiver port map (
        mclk_i => mclk_s,
        bclk_i => bclk_s,
        lrclk_i => lrclk_s,
        
        left_audio_data_o => left_audio_data_s,
        right_audio_data_o => right_audio_data_s,
        adc_serial_data_i => ac_adc_data_i
);
---------------------------------------------------------------------------- 
-- I2S transmitter
i2S_transmitter_port : i2s_transmitter port map(
        mclk_i    => mclk_s,
		bclk_i    => bclk_s,	
		lrclk_i   => lrclk_s,
		
		-- Data
		left_audio_data_i     => left_audio_data_tx_s,
		right_audio_data_i    => right_audio_data_tx_s,
		dac_serial_data_o     => ac_dac_data_o
         
);
---------------------------------------------------------------------------- 
-- AXI stream transmitter

axi_stream_transmitter_port : axis_transmitter port map(
        lrclk_i  => lrclk_s,
        --i2s from rx
        left_audio_data_i  => left_audio_data_s,
		right_audio_data_i   => right_audio_data_s,
		--fifo in
        m00_axis_aclk    => m00_axis_aclk ,
		m00_axis_aresetn  => m00_axis_aresetn,


		m00_axis_tready   => m00_axis_tready,
		--fifo out
		m00_axis_tdata    => m00_axis_tdata,
		m00_axis_tvalid   => m00_axis_tvalid,
		--optional
		m00_axis_tstrb    => open,
		m00_axis_tlast    => open
);
---------------------------------------------------------------------------- 
-- AXI stream receiver
axi_stream_receiver_port : axis_receiver port map(
        --i2s clk
        lrclk_i          => lrclk_s,      
        --i2s to tx
        left_audio_data_o => left_audio_data_tx_s,     
		right_audio_data_o => right_audio_data_tx_s,    
		--fifo in
        s00_axis_aclk     => s00_axis_aclk,
		s00_axis_aresetn  => s00_axis_aresetn,
		s00_axis_tdata    => s00_axis_tdata,
		s00_axis_tvalid   => s00_axis_tvalid,
		--fifo out
		s00_axis_tready   => s00_axis_tready, 


		--optional
		s00_axis_tstrb   => s00_axis_tstrb,  
		s00_axis_tlast    => s00_axis_tlast 
);

---------------------------------------------------------------------------- 
-- Logic
---------------------------------------------------------------------------- 

--MUTE process--------------
    ac_mute_n_s <= not ac_mute_en_i;
--mute_flipflop_process : process(mclk_s)
--    begin
--    if rising_edge(mclk_s ) then   
--        ac_mute_n_reg_s <= ac_mute_n_s;
--    end if;
--end process;
ac_mute_n_o <= not ac_mute_en_i;
----------------------------------------------------------------------------
--debugs 
        dbg_left_audio_rx_o <= left_audio_data_s;
		dbg_left_audio_tx_o <= left_audio_data_tx_s;
		dbg_right_audio_rx_o  <= right_audio_data_s;
		dbg_right_audio_tx_o  <= right_audio_data_tx_s;

end Behavioral;