----------------------------------------------------------------------------
--  Final proj beat detect / frame gen wrapper
----------------------------------------------------------------------------

-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;                                    
----------------------------------------------------------------------------

entity beat_frame_wrapper is
      generic (
        DATA_WIDTH : integer := 32;
        AMP_WIDTH  : integer := 4 );
    port (
        s00_axis_clock          : in std_logic;
        m00_axis_tvalid         : in std_logic;     -- should come from output of lowpass filter
        data_in                 : in std_logic_vector(DATA_WIDTH-1 downto 0);
        threshold_factor        : in std_logic_vector(1 downto 0);
        sample_mode_i             : in std_logic;     -- 1 if in sample mode, 0 if not
        reset_i                 : in std_logic;
        
        pclk_i                  : in std_logic;
        active_video_i          : STD_LOGIC;   
        hsync_i                 : STD_LOGIC;
        vsync_i                 : STD_LOGIC;
        fsync_i                 : std_logic_vector(0 downto 0);
        
        video_pdata_o    : out std_logic_vector(23 downto 0);
        
        dbg_max_amplitude_o       : out std_logic_vector(23 downto 0);
        dbg_beat_detected_o       : out std_logic;
        dbg_detected_amplitude_o  : out std_logic_vector(23 downto 0)
        );
end beat_frame_wrapper;

architecture Behavioral of beat_frame_wrapper is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
signal beat : STD_LOGIC;
signal amplitude : std_logic_vector(23 downto 0);
signal max_amplitude   : std_logic_vector(23 downto 0);        
----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
-- beat detector (gets data post lpf)
component beat_detection is
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
end component;

--frame generator (more accurately pixel by position generator)
component frame_gen is
    Port (
        pclk_i : IN STD_LOGIC;
        beat_i : IN STD_LOGIC;
        amplitude_i : in std_logic_vector(23 downto 0);
        active_video_i : in STD_LOGIC;   
        hsync_i : in STD_LOGIC;
        vsync_i : in STD_LOGIC;
        fsync_i : in std_logic_vector(0 downto 0);
        max_amplitude_i   : in std_logic_vector(23 downto 0);

        video_pdata_o    : out std_logic_vector(23 downto 0)
    );
end component;

begin
----------------------------------------------------------------------------
-- Component instantiations
----------------------------------------------------------------------------    
--beat detector
beat_detection_port : beat_detection port map(

        s00_axis_clock          => s00_axis_clock,
        m00_axis_tvalid         => m00_axis_tvalid,
        data_in                 => data_in,
        threshold_factor_i        => threshold_factor,
        sample_mode_i             => sample_mode_i,
        reset_i                 => reset_i,
        fsync_i                 => fsync_i,
        max_amplitude_o         => max_amplitude,
        beat_detected_o           => beat,
        detected_amplitude_o      => amplitude,     
        dbg_max_amplitude_o       => dbg_max_amplitude_o,
        dbg_beat_detected_o       => dbg_beat_detected_o,
        dbg_detected_amplitude_o  => dbg_detected_amplitude_o
    );
  
--frame generator (more accurately pixel by position generator)
 frame_gen_port : frame_gen port map (
        pclk_i => pclk_i,
        beat_i => beat,
        amplitude_i => amplitude,
        active_video_i => active_video_i,   
        hsync_i => hsync_i,
        vsync_i => vsync_i,
        fsync_i => fsync_i,
        max_amplitude_i => max_amplitude,
        
        video_pdata_o => video_pdata_o
    );  
    
end Behavioral;
