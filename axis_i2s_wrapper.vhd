----------------------------------------------------------------------------
--  Lab 3: AXI Stream FIFO and FIR TASK 1
----------------------------------------------------------------------------
--  ENGS 128 Spring 2025
--	Author: Mateo Oyola
----------------------------------------------------------------------------
--	Description: AXI wrapper DDS
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;                  
library UNISIM;
use UNISIM.VComponents.all;                  
----------------------------------------------------------------------------
-- Entity definition
entity axis_i2s_wrapper is
	generic (
		-- Parameters of Axi Stream Bus Interface S00_AXIS, M00_AXIS
		C_AXI_STREAM_DATA_WIDTH	: integer	:= 32;
		
		-- Users to add parameters here
		DDS_DATA_WIDTH : integer := 24;         -- DDS data width
        DDS_PHASE_DATA_WIDTH : integer := 12;   -- DDS phase increment data width --CHANGE to 12
		-- User parameters ends
		-- Do not modify the parameters beyond this line

		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer	:= 4
	);
    Port ( 
        ----------------------------------------------------------------------------
        -- Fabric clock from Zynq PS 12.288MHz
		sysclk_i : in  std_logic;	
		
        ----------------------------------------------------------------------------
        -- I2S audio codec ports		
		-- User controls
		ac_mute_en_i : in STD_LOGIC;
		audio_select_i : in std_logic; --task 2
		
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
		
		--debug ports (ILA) --MAKE SURE TO USE RX IN TASK 
		dbg_left_audio_rx_o : out std_logic_vector(23 downto 0);
		dbg_left_audio_tx_o : out std_logic_vector(23 downto 0);
		dbg_right_audio_rx_o : out std_logic_vector(23 downto 0);
		dbg_right_audio_tx_o : out std_logic_vector(23 downto 0);
		
		
		
		--DDS AXi ports 
		-- Users to add ports here
		--dds_enable_i  : in std_logic;
		--dds_reset_i   : in std_logic;
		left_dds_data_o    : out std_logic_vector(DDS_DATA_WIDTH-1 downto 0);
		right_dds_data_o    : out std_logic_vector(DDS_DATA_WIDTH-1 downto 0);
		
		-- Debug ports to send to ILA
		left_dds_phase_inc_dbg_o : out std_logic_vector(DDS_PHASE_DATA_WIDTH-1 downto 0);   
		right_dds_phase_inc_dbg_o : out std_logic_vector(DDS_PHASE_DATA_WIDTH-1 downto 0);   
		
		-- User ports ends
		-- Do not modify the ports beyond this line

		-- Ports of Axi Responder/Slave Bus Interface S00_AXI
		s00_axi_aclk	: in std_logic;
		s00_axi_aresetn	: in std_logic;
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_awprot	: in std_logic_vector(2 downto 0);
		s00_axi_awvalid	: in std_logic;
		s00_axi_awready	: out std_logic;
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		s00_axi_wvalid	: in std_logic;
		s00_axi_wready	: out std_logic;
		s00_axi_bresp	: out std_logic_vector(1 downto 0);
		s00_axi_bvalid	: out std_logic;
		s00_axi_bready	: in std_logic;
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_arprot	: in std_logic_vector(2 downto 0);
		s00_axi_arvalid	: in std_logic;
		s00_axi_arready	: out std_logic;
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_rresp	: out std_logic_vector(1 downto 0);
		s00_axi_rvalid	: out std_logic;
		s00_axi_rready	: in std_logic
		
		);
end axis_i2s_wrapper;
----------------------------------------------------------------------------
architecture Behavioral of axis_i2s_wrapper is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
-- Constants
constant AXI_DATA_WIDTH : integer := 32;        -- 32-bit AXI data bus
constant AXI_FIFO_DEPTH : integer := 128;        -- AXI stream FIFO depth
constant AC_DATA_WIDTH : integer := 24;       

  -- Clocks for I2S components
		signal mclk_s		      : std_logic := '0';	
		signal bclk_s            : std_logic := '0';
		signal lrclk_s           : std_logic := '0';
       -- DDS signals
        signal dds_clk_s : std_logic;
        signal dds_enable_s : std_logic;
        signal dds_reset_s : std_logic;
        signal left_dds_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        signal right_dds_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        
--muxed dds/i2srx signal
        signal left_axi_tx_in_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        signal right_axi_tx_in_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
--transmitter mux and register flip flop
        signal left_audio_data_tx_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
        signal right_audio_data_tx_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
        
        --receiver outputs 
        signal left_audio_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
        signal right_audio_data_s : std_logic_vector(AC_DATA_WIDTH-1 downto 0) := (others => '0');
        
        --mute signals
        signal ac_mute_n_s : std_logic := '0';
        signal ac_mute_n_reg_s : std_logic := '0';
        
        -- switch input from dds / rx
        signal audio_select_s   : std_logic := '0'; -- switch 3, 0 for dds / 1 for rx

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
---AXI DDS 
component engs128_axi_dds is
	generic (
	    ----------------------------------------------------------------------------
		-- Users to add parameters here
		DDS_DATA_WIDTH : integer := 24;         -- DDS data width
        DDS_PHASE_DATA_WIDTH : integer := 12;   -- DDS phase increment data width --CHANGE to 12
        ----------------------------------------------------------------------------

		-- User parameters ends
		-- Do not modify the parameters beyond this line

		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer	:= 4
	);
	port (
	    ----------------------------------------------------------------------------
		-- Users to add ports here
		dds_clk_i     : in std_logic;
		dds_enable_i  : in std_logic;
		dds_reset_i   : in std_logic;
		left_dds_data_o    : out std_logic_vector(DDS_DATA_WIDTH-1 downto 0);
		right_dds_data_o    : out std_logic_vector(DDS_DATA_WIDTH-1 downto 0);
		
		-- Debug ports to send to ILA
		left_dds_phase_inc_dbg_o : out std_logic_vector(DDS_PHASE_DATA_WIDTH-1 downto 0);   
		right_dds_phase_inc_dbg_o : out std_logic_vector(DDS_PHASE_DATA_WIDTH-1 downto 0);   
		
		----------------------------------------------------------------------------
		-- User ports ends
		-- Do not modify the ports beyond this line

		-- Ports of Axi Responder/Slave Bus Interface S00_AXI
		s00_axi_aclk	: in std_logic;
		s00_axi_aresetn	: in std_logic;
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_awprot	: in std_logic_vector(2 downto 0);
		s00_axi_awvalid	: in std_logic;
		s00_axi_awready	: out std_logic;
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		s00_axi_wvalid	: in std_logic;
		s00_axi_wready	: out std_logic;
		s00_axi_bresp	: out std_logic_vector(1 downto 0);
		s00_axi_bvalid	: out std_logic;
		s00_axi_bready	: in std_logic;
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_arprot	: in std_logic_vector(2 downto 0);
		s00_axi_arvalid	: in std_logic;
		s00_axi_arready	: out std_logic;
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_rresp	: out std_logic_vector(1 downto 0);
		s00_axi_rvalid	: out std_logic;
		s00_axi_rready	: in std_logic
	);
end component;
---------------------------------------------------------------------------- 
-- I2S receiver -- FOR TASK 1 LEAVE OUT FOR NOW
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
		FIFO_DEPTH	: integer	:= 128;
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
		FIFO_DEPTH	: integer	:= 128;
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
---AXI DDS 
-- DDS Instantiation
    dds_inst : engs128_axi_dds
        port map (
            dds_clk_i => lrclk_s,
            dds_enable_i => '1', --dds_enable_i,  -- Enable DDS
            dds_reset_i => '0', --dds_reset_i,   -- No reset
            left_dds_data_o => left_dds_data_s,
            right_dds_data_o => right_dds_data_s,
		    left_dds_phase_inc_dbg_o => left_dds_phase_inc_dbg_o,
		    right_dds_phase_inc_dbg_o => right_dds_phase_inc_dbg_o,
            s00_axi_aclk => s00_axi_aclk,
            s00_axi_aresetn => s00_axi_aresetn,
            s00_axi_awaddr => s00_axi_awaddr,
            s00_axi_awprot => s00_axi_awprot,
            s00_axi_awvalid => s00_axi_awvalid,
            s00_axi_awready => s00_axi_awready,
            s00_axi_wdata => s00_axi_wdata,
            s00_axi_wstrb => s00_axi_wstrb,
            s00_axi_wvalid => s00_axi_wvalid,
            s00_axi_wready => s00_axi_wready,
            s00_axi_bresp => s00_axi_bresp,
            s00_axi_bvalid => s00_axi_bvalid,
            s00_axi_bready => s00_axi_bready,
            s00_axi_araddr => s00_axi_araddr,
            s00_axi_arprot => s00_axi_arprot,
            s00_axi_arvalid => s00_axi_arvalid,
            s00_axi_arready => s00_axi_arready,
            s00_axi_rdata => s00_axi_rdata,
            s00_axi_rresp => s00_axi_rresp,
            s00_axi_rvalid => s00_axi_rvalid,
            s00_axi_rready => s00_axi_rready
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
        left_audio_data_i  => left_axi_tx_in_s,
		right_audio_data_i   => right_axi_tx_in_s,
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
-- Process for switching between DDS and I2S Receiver 
dds_i2s_rx_en_process : process(mclk_s, audio_select_s)
begin
    if rising_edge(mclk_s) then
      if audio_select_s = '1' then 
            left_axi_tx_in_s <= left_audio_data_s;
            right_axi_tx_in_s <= right_audio_data_s;
        else
            left_axi_tx_in_s <= left_dds_data_s;
            right_axi_tx_in_s <=   right_dds_data_s;
        end if;
    end if;
end process;
--left_axi_tx_in_s <= left_dds_data_s; --comment out for task 2
--right_axi_tx_in_s <=   right_dds_data_s; ---comment out for task 2 !!!!!!

--MUTE process-------------- keep for task 1
    ac_mute_n_s <= not ac_mute_en_i;
mute_flipflop_process : process(mclk_s)
    begin
    if rising_edge(mclk_s ) then   
        ac_mute_n_reg_s <= ac_mute_n_s;
    end if;
end process;
ac_mute_n_o <= ac_mute_n_reg_s ;
audio_select_s <= audio_select_i; --task 2

----------------------------------------------------------------------------
--debugs 
        --i2s rx and tx
        --dbg_left_audio_rx_o <= left_audio_data_s;
		dbg_left_audio_tx_o <= left_audio_data_tx_s;
		--dbg_right_audio_rx_o  <= right_audio_data_s;
		dbg_right_audio_tx_o  <= right_audio_data_tx_s;
        
        --axi dds
        left_dds_data_o <= left_dds_data_s;
        right_dds_data_o <= right_dds_data_s;
        
        --set redundant outputs
        m00_axis_tstrb <= (others => '0');
        m00_axis_tlast <= '1';
        
end Behavioral;