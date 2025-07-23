library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;  -- ??? random

entity i2c_tb is
end entity;

architecture sim of i2c_tb is

    signal SDA        : std_logic := '1';
    signal SCL        : std_logic := '1';
    signal Sys_Clock  : std_logic := '0';

    signal SDA_driver : std_logic := '1';

    constant SYS_CLK_PERIOD : time := 625 ns;
    constant SCL_CLK_PERIOD : time := 10_000 ns;

    component i2c
        generic (N : integer := 4);
        port (
            SDA       : inout std_logic;
            SCL       : in std_logic;
            Sys_Clock : in std_logic
        );
    end component;

begin

    SDA <= SDA_driver;

    uut: i2c
        port map (
            SDA => SDA,
            SCL => SCL,
            Sys_Clock => Sys_Clock
        );

    ---------------------------------------------------------------------
    -- System Clock
    sys_clk_process: process
    begin
        while true loop
            Sys_Clock <= '0';
            wait for SYS_CLK_PERIOD / 2;
            Sys_Clock <= '1';
            wait for SYS_CLK_PERIOD / 2;
        end loop;
    end process;

    ---------------------------------------------------------------------
    -- SCL Clock
    scl_clk_process: process
    begin
        SCL <= '1';
        wait for 25_000 ns;

        while true loop
            SCL <= '0';
            wait for SCL_CLK_PERIOD / 2;
            SCL <= '1';
            wait for SCL_CLK_PERIOD / 2;
        end loop;
    end process;

    ---------------------------------------------------------------------
    -- Stimulus
    stimulus_proc: process
        variable rand_real : real;
        variable rand_int  : integer;
        variable seed1, seed2 : positive := 1;
        variable rand_data  : std_logic_vector(7 downto 0);

        procedure send_byte(data : std_logic_vector(7 downto 0)) is
        begin
            for i in 7 downto 0 loop
                SDA_driver <= data(i);
                wait for SCL_CLK_PERIOD;
            end loop;
            SDA_driver <= 'Z';  -- ??? ACK
            wait for SCL_CLK_PERIOD;
        end procedure;

        procedure stop_condition is
        begin
            -- SDA must be low first (after ACK)
            SDA_driver <= '0';
            wait for SCL_CLK_PERIOD / 2;

            -- Wait until SCL is high
            wait until SCL = '1';

            -- SDA goes high while SCL is high ? STOP
            SDA_driver <= '1';
            wait for SCL_CLK_PERIOD;
        end procedure;

        constant command_byte : std_logic_vector(7 downto 0) := "00000010";

    begin
        -- ???? 1: Idle
        SDA_driver <= '1';
        wait for 20_000 ns;

        -- ???? 2: Start condition
        SDA_driver <= '0';
        wait for 5_000 ns;

        -- ???? 3: Address + RW = Write
        send_byte("00000000");

        -- ???? 5: Command Byte (register index)
        send_byte(command_byte);

        -- ???? 7: Write ??????? 8-bit ?????????
        uniform(seed1, seed2, rand_real);
        rand_int := integer(rand_real * 256.0);
        rand_data := std_logic_vector(to_unsigned(rand_int, 8));
        report "Random data to write: " & integer'image(rand_int);
        send_byte(rand_data);

        -- ?? ???? 8: Stop Condition
        stop_condition;

        wait for 100_000 ns;
        assert false report "????? ????????????" severity failure;
    end process;

end architecture;

