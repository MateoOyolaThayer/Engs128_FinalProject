----------------------------------------------------------------------------------
-- LAB 3 fir wrapper
--Natalie Schreder
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL; 


entity FIR_wrapper is
--    generic (
--	);
    Port ( 
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tready : IN STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
end FIR_wrapper;

architecture Behavioral of FIR_wrapper is


----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
constant DATA_WIDTH : INTEGER := 24;

-- Low pass left
signal s_axis_data_tvalid_lp_l : std_logic := '0';	
signal s_axis_data_tready_lp_l : std_logic := '0';	
signal s_axis_data_tdata_lp_l : std_logic_vector(DATA_WIDTH-1 DOWNTO 0) := (others => '0');
signal m_axis_data_tvalid_lp_l : std_logic := '0';	
signal m_axis_data_tready_lp_l : std_logic := '0';	
signal m_axis_data_tdata_lp_l : std_logic_vector(DATA_WIDTH-1 DOWNTO 0) := (others => '0');
-- Low pass right
signal s_axis_data_tvalid_lp_r : std_logic := '0';	
signal s_axis_data_tready_lp_r : std_logic := '0';	
signal s_axis_data_tdata_lp_r : std_logic_vector(DATA_WIDTH-1 DOWNTO 0) := (others => '0');
signal m_axis_data_tvalid_lp_r : std_logic := '0';	
signal m_axis_data_tready_lp_r : std_logic := '0';	
signal m_axis_data_tdata_lp_r : std_logic_vector(DATA_WIDTH-1 DOWNTO 0) := (others => '0');


----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
COMPONENT fir_compiler_1_new
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_data_tvalid : IN STD_LOGIC;
    s_axis_data_tready : OUT STD_LOGIC;
    s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tready : IN STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
  );
END COMPONENT;

begin
----------------------------------------------------------------------------
-- Component instantiations
----------------------------------------------------------------------------    
-- Filters for the left audio stream
fir_lowpass_left : fir_compiler_1_new
  PORT MAP (
    aclk => aclk,
    s_axis_data_tvalid => s_axis_data_tvalid_lp_l,
    s_axis_data_tready => s_axis_data_tready_lp_l,
    s_axis_data_tdata => s_axis_data_tdata_lp_l,
    m_axis_data_tvalid => m_axis_data_tvalid_lp_l,
    m_axis_data_tready => m_axis_data_tready_lp_l,
    m_axis_data_tdata => m_axis_data_tdata_lp_l
  );
fir_lowpass_right : fir_compiler_1_new
  PORT MAP (
    aclk => aclk,
    s_axis_data_tvalid => s_axis_data_tvalid_lp_r,
    s_axis_data_tready => s_axis_data_tready_lp_r,
    s_axis_data_tdata => s_axis_data_tdata_lp_r,
    m_axis_data_tvalid => m_axis_data_tvalid_lp_r,
    m_axis_data_tready => m_axis_data_tready_lp_r,
    m_axis_data_tdata => m_axis_data_tdata_lp_r
  );
  

---------------------------------------------------------------------------- 
-- Logic
---------------------------------------------------------------------------- 
select_filter_process : process(aclk)
    variable lr_data_bit: std_logic;
    variable sw_select : std_logic_vector(1 downto 0);
begin

if rising_edge(aclk) then 

    lr_data_bit := s_axis_data_tdata(31);
        case lr_data_bit is
            when '0' => -- LEFTHAND CASE
                
                 -- Lowpass
                        -- map inputs
                        s_axis_data_tvalid_lp_l <= s_axis_data_tvalid;
                        s_axis_data_tdata_lp_l <= s_axis_data_tdata(23 downto 0);
                        m_axis_data_tready_lp_l <= m_axis_data_tready;
            
                        -- map outputs
                        s_axis_data_tready <= s_axis_data_tready_lp_l;
                        m_axis_data_tvalid <= m_axis_data_tvalid_lp_l;
                        m_axis_data_tdata <= "00000000" & m_axis_data_tdata_lp_l;
                    
            when '1' => -- RIGHTHAND CASE
                
                 -- Lowpass
                        -- map inputs
                        s_axis_data_tvalid_lp_r <= s_axis_data_tvalid;
                        s_axis_data_tdata_lp_r <= s_axis_data_tdata(23 downto 0);
                        m_axis_data_tready_lp_r <= m_axis_data_tready;
            
                        -- map outputs
                        s_axis_data_tready <= s_axis_data_tready_lp_r;
                        m_axis_data_tvalid <= m_axis_data_tvalid_lp_r;
                        m_axis_data_tdata <= "00000000" & m_axis_data_tdata_lp_r;   
         end case;
        
--    -- No filter
--    else
--        m_axis_data_tdata <= s_axis_data_tdata;
--        m_axis_data_tvalid <= s_axis_data_tvalid;
--        s_axis_data_tready <= m_axis_data_tready;
    
 end if;
end process;


end Behavioral;

 