library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c is
    generic 
	(
   	 N : integer := 4  -- Number of regs
  	);
    port(
        SDA       : inout std_logic;
        SCL       : in std_logic;
        Sys_Clock : in std_logic
    );
end entity i2c;

architecture rtl of i2c is

    type my_states_type is (
        Address_Frame,
        R_W_Check,
        RD,
        WR,
	ACK,
	Command_Byte,
        IDLE
    );
    

    type vector_array is array (0 to N-1) of std_logic_vector(7 downto 0);
    signal slave_regs : vector_array;

    signal id             : std_logic_vector(6 downto 0);
    signal bit_counter    : unsigned(2 downto 0) := (others => '0');
    
    signal current_state  : my_states_type := IDLE;
    signal saved_state  : my_states_type := IDLE;
    signal r1_SDA : std_logic := '0';
    signal r2_SDA : std_logic := '0';
    signal r3_SDA : std_logic := '0';

    signal r1_SCL : std_logic := '0';
    signal r2_SCL : std_logic := '0';
    signal r3_SCL : std_logic := '0';

    signal RW_flag : std_logic;
    signal ack_flag : std_logic := '0';

    signal sda_out : std_logic := 'Z';
    


    signal command_byte_reg : std_logic_vector(7 downto 0);
    signal reg_id : vector_array; 
    signal found_index : integer range -1 to N-1 := -1;
    signal j : integer;
    

begin
	
   
	
    SDA <= sda_out;
    process(Sys_Clock) 
    variable count : integer;
    begin
        if rising_edge(Sys_Clock) then
         
            r1_SDA <= SDA;
            r2_SDA <= r1_SDA;
            r3_SDA <= r2_SDA;

            
            r1_SCL <= SCL;
            r2_SCL <= r1_SCL;
            r3_SCL <= r2_SCL;

            case current_state is

                when IDLE =>
                    if (r3_SDA = '1') and (r2_SDA = '0') and (r2_SCL = '1') and (r1_SCL = '1') then
                        current_state <= Address_Frame;
                        bit_counter <= (others => '0');
                    end if;

                when Address_Frame =>
		if (r2_SCL = '0') and (r1_SCL = '1') then
                    if bit_counter /= "111" then
                        id <= id(5 downto 0) & r2_SDA; 
                        bit_counter <= bit_counter + 1;
                    else
                        if id = "0000000" then 
                            current_state <= R_W_Check;
                            bit_counter <= (others => '0');
                        else 
                            current_state <= IDLE;
                            bit_counter <= (others => '0');            
                        end if;
                    end if;
		end if;




                when R_W_Check =>
		    
                    if r2_SDA = '0' then
			RW_flag <= '0';
			if(r2_SCL = '1') and (r1_SCL = '0') then
                        	
				saved_state <= Command_byte;
				current_state <=ACK;
			end if;
		    	
                    else
			RW_flag <= '1';
                       
       		    	if(r2_SCL = '1') and (r1_SCL = '0') then
                        	saved_state <=RD;
				current_state <= ACK;
		    	end if;             	
		    end if;
		
		when ACK =>
		ack_flag <= '0';
		bit_counter <= (others => '0');
		if (r2_SCL = '0') and (r1_SCL = '0') then
		sda_out <='0';
		end if;
		if (r2_SCL = '1') and (r1_SCL = '0') then
		current_state <= saved_state;
		end if;




		
		




		when Command_Byte =>
		sda_out <= 'Z';
		if (r2_SCL = '0') and (r1_SCL = '1') then
		
                    if bit_counter /= "111" then
			
                        command_byte_reg <= command_byte_reg(6 downto 0) & r2_SDA; 
                        bit_counter <= bit_counter + 1;
                    else 
			ack_flag <= '1';
			command_byte_reg <= command_byte_reg(6 downto 0) & r2_SDA;
			
			if RW_flag = '1' then

				saved_state <= IDLE;
				
			else
				saved_state <=WR;
				
                    	end if;
		     end if;

                elsif (r2_SCL = '1') and (r1_SCL = '0') and ack_flag = '1' then
			current_state <= ACK;
		
		    	             	
                   
		end if;




                when WR =>
		
		sda_out <= 'Z';
		if (r3_SDA = '0') and (r2_SDA = '1') and (r2_SCL = '1') and (r1_SCL = '1') then
                            current_state <= IDLE; -- stop condition
                        
                end if;
		if (r2_SCL = '0') and (r1_SCL = '1') then
                    if bit_counter /= "111" then
                        slave_regs(to_integer(unsigned(command_byte_reg))) <= slave_regs(to_integer(unsigned(command_byte_reg)))(6 downto 0) & r2_SDA; 
                        bit_counter <= bit_counter + 1;
                    else 
			slave_regs(to_integer(unsigned(command_byte_reg))) <= slave_regs(to_integer(unsigned(command_byte_reg)))(6 downto 0) & r2_SDA; 
                        ack_flag <= '1';
                        saved_state <= IDLE;
			

                        
                    end if;
		elsif (r2_SCL = '1') and (r1_SCL = '0') and ack_flag = '1' then
			current_state <= ACK;
		end if;
		


		
		when RD =>
		sda_out <= 'Z';
		count := to_integer(unsigned(bit_counter));
		if (r3_SDA = '0') and (r2_SDA = '1') and (r2_SCL = '1') and (r1_SCL = '1') then
                            current_state <= IDLE; -- stop condition
                        
                end if;
		if (r2_SCL = '0') and (r1_SCL = '1') then
		    
                    if bit_counter /= "111" then
			sda_out <= slave_regs(to_integer(unsigned(command_byte_reg)))(count);
                        
                        bit_counter <= bit_counter + 1;
                    else 
			
			sda_out <= slave_regs(to_integer(unsigned(command_byte_reg)))(count);
                        ack_flag <= '1';
                        saved_state <= IDLE;
			
                        
                    end if;
		elsif (r2_SCL = '1') and (r1_SCL = '0') and ack_flag = '1' then
			current_state <= ACK;
		end if;
		







                when others =>
                    current_state <= IDLE;

            end case;
        end if;
    end process;
end rtl;
