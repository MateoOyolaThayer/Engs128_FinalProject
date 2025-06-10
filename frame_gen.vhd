----------------------------------------------------------------------------------
--E 128 final proj
--Frame generator 
--Mateo Oyola
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

-- ----------------------------------------------------------------------------------
entity frame_gen is
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
end frame_gen;

-- ----------------------------------------------------------------------------------
architecture Behavioral of frame_gen is
-- ----------------------------------------------------------------------------------
-- Signal declarations    
    -- VGA 640x480 @ 60Hz with 800x525 total timing
    constant H_VISIBLE : integer := 640;
    constant V_VISIBLE : integer := 480;

    constant cx : integer := H_VISIBLE / 2;  -- 320 center x
    constant cy : integer := V_VISIBLE / 2;  -- 240 center y

    signal h_count : integer range 0 to H_VISIBLE - 1 := 0;
    signal v_count : integer range 0 to V_VISIBLE - 1 := 0;

    signal radius : integer range 0 to 300 := 50;
    
    signal data_range : integer := 0;
    signal max_amplitude_latch : integer := 0;

    signal   video_red       : std_logic_vector(7 downto 0);
    signal   video_green     : std_logic_vector(7 downto 0);
    signal   video_blue      : std_logic_vector(7 downto 0);
    signal   in_circle_s     : std_logic := '0';
    signal   color_s         : std_logic_vector(23 downto 0) := (others => '0');
    signal   dx, dy, dx_sq, dy_sq, dist_sq : integer := 0;

-- ----------------------------------------------------------------------------------
begin

    -- Horizontal and Vertical pixel counters
    pixel_counter_process : process(pclk_i)
    begin
        if rising_edge(pclk_i) then
            if hsync_i = '0' then -- for sim is opposite? CHANGE active low for HARDWARE
                h_count <= 0;
            elsif active_video_i = '1' then
                h_count <= h_count + 1;
            end if;
            
            if vsync_i = '0' then -- for sim is opposite?
                v_count <= 0;
            elsif h_count = 1 then
                v_count <= v_count + 1;
            end if;
        end if;
    end process pixel_counter_process;

-- Compute distance and flag if inside circle
distance_check_process : process(pclk_i)
begin
    if rising_edge(pclk_i) then
        dx <= h_count - cx;
        dy <= v_count - cy;
        
        --pipelining multiplication 
        for i in 0 to 2 loop
            case i is 
                when 0 => dx_sq <= dx * dx;
                when 1 => dy_sq <= dy * dy;
                when 2 => dist_sq <= dx_sq + dy_sq;
            end case;
        end loop;
 
        if dist_sq <= radius * radius then
            in_circle_s <= '1';
        else
            in_circle_s <= '0';
        end if;
    end if;
end process;

-- Set color and update control logic
pixel_output_process : process(pclk_i)
begin
    if rising_edge(pclk_i) then
        -- Color based on in_circle
        if in_circle_s = '1' then
            video_pdata_o <= X"FFFF00";  -- Yellow
        else
            video_pdata_o <= X"0000FF";  -- Blue
        end if;

        -- Update max amplitude on fsync rising edge
        if fsync_i(0) = '1' then
            max_amplitude_latch <= to_integer(signed(max_amplitude_i));
            
                    -- Update radius 
            if beat_i = '1' then
                if max_amplitude_latch /= 0 then
                     radius <= 100 + (to_integer(abs(signed(amplitude_i))) * 180) / max_amplitude_latch;
                else
                    radius <= 100;
                end if;
            else
            radius <= 100;
        end if;
    end if;

--        -- Update radius 
--        if beat_i = '1' then
--            if max_amplitude_latch /= 0 then
--                radius <= 100 + (to_integer(abs(signed(amplitude_i))) * 180) / max_amplitude_latch;
--            else
--                radius <= 100;
--            end if;
--        else
--            radius <= 100;
--        end if;
    end if;
end process;


end Behavioral;