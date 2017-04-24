----------------------------------------------------------------------------------
-- Engineer:            David Banks
--
-- Create Date:         14/4/2017
-- Module Name:         RGBtoHDMI CPLD
-- Project Name:        RGBtoHDMI
-- Target Devices:      XC9572XL
--
-- Version:             0.50
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RGBtoHDMI is
    Port (
        -- From Beeb RGB Connector
        R:         in    std_logic;
        G:         in    std_logic;
        B:         in    std_logic;
        nCSYNC:    in    std_logic;

        -- From Pi
        clk:       in    std_logic;

        -- To PI GPIO
        quad:      out   std_logic_vector(11 downto 0);
        psync:     out   std_logic;
        hsync:     out   std_logic;
        vsync:     out   std_logic;
        field:     out   std_logic;

        -- Test
        SW:        in    std_logic;
        LED1:      out   std_logic;
        LED2:      out   std_logic
    );
end RGBtoHDMI;

architecture Behavorial of RGBtoHDMI is

    signal shift : std_logic_vector(11 downto 0);

    signal nCSYNC1 : std_logic;

    -- The counter runs at 4x pixel clock
    --
    -- It serves several purposes:
    -- 1. Counts the 12us between the rising edge of nCSYNC and the first pixel
    -- 2. Counts within each pixel (bits 0 and 1)
    -- 3. Counts counts pixels within a quad pixel (bits 2 and 3)
    -- 4. Handles double buffering of alternative quad pixels (bit 4)
    --
    -- At the moment we don't count pixels with the line, the Pi does that
    --
    -- The sequence is basically:
    -- 80, 80, ..., 80, 81, 82, ... , 127
    -- 0, 1, 2, ..., 14, 15  - first quad pixel
    -- 16, 17, 18, ..., 30, 31, -- second quad pixel
    -- ...
    -- 80, 80, ..., 80, 81, 82, ... , 127

    signal counter : unsigned(6 downto 0);

    -- Hsync is every 64us
    signal led_counter : unsigned(11 downto 0);

begin

    process(nCSYNC)
    begin
        if rising_edge(nCSYNC) then
            led_counter <= led_counter + 1;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            -- synchronize nCSYNC to the sampling clock
            nCSYNC1 <= nCSYNC;

            if nCSYNC1 = '0' then
                -- within horizontal line sync pulse
                hsync <= '1';
                counter <= to_unsigned(80, counter'length);
            else
                -- within the line
                hsync <= '0';
                if counter = 31 then
                    counter <= to_unsigned(0, counter'length);
                else
                    counter <= counter + 1;
                end if;
                if counter(6) = '0' then
                    if counter(1 downto 0) = "11" then
                        shift <= B & G & R & shift(11 downto 3);
                        if counter(3 downto 2) = "11" then
                            quad <= shift;
                            psync <= counter(4);
                        end if;
                    end if;
                else
                    quad <= (others => '0');
                    psync <= '1';
                end if;
            end if;
        end if;
    end process;

    LED1 <= not SW;

    LED2 <= led_counter(led_counter'left);

end Behavorial;