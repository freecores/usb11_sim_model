--==========================================================================================================--
--                                                                                                          --
--  Copyright (C) 2011  by  Martin Neumann martin@neumanns-mail.de                                          --
--                                                                                                          --
--  This source file may be used and distributed without restriction provided that this copyright statement --
--  is not removed from the file and that any derivative work contains the original copyright notice and    --
--  the associated disclaimer.                                                                              --
--                                                                                                          --
--  This software is provided ''as is'' and without any express or implied warranties, including, but not   --
--  limited to, the implied warranties of merchantability and fitness for a particular purpose. in no event --
--  shall the author or contributors be liable for any direct, indirect, incidental, special, exemplary, or --
--  consequential damages (including, but not limited to, procurement of substitute goods or services; loss --
--  of use, data, or profits; or business interruption) however caused and on any theory of liability,      --
--  whether in  contract, strict liability, or tort (including negligence or otherwise) arising in any way  --
--  out of the use of this software, even if advised of the possibility of such damage.                     --
--                                                                                                          --
--==========================================================================================================--
--                                                                                                          --
--  File name   : USB_tc_02.vhd                                                                             --
--  Author      : Martin Neumann  martin@neumanns-mail.de                                                   --
--  Description : Copy and rename this file to usb_stimuli.vhd before running a new simulation!             --
--                                                                                                          --
--==========================================================================================================--
--                                                                                                          --
-- Change history                                                                                           --
--                                                                                                          --
-- Version / date        Description                                                                        --
--                                                                                                          --
-- 01  05 Mar 2011 MN    Initial version                                                                    --
--                                                                                                          --
-- End change history                                                                                       --
--==========================================================================================================--

LIBRARY work, IEEE;
  USE IEEE.std_logic_1164.ALL;
  USE IEEE.std_logic_arith.ALL;
  USE work.usb_commands.ALL;

ENTITY USB_Stimuli IS PORT(
  -- Test Control Interface --
  USB             : OUT usb_action;
  t_no            : OUT NATURAL;
  -- Application Interface
  clk             : IN  STD_LOGIC;
  rst_neg_ext     : OUT STD_LOGIC;
  RXval           : IN  STD_LOGIC;                    -- RX bytes available
  RXdat           : IN  STD_LOGIC_VECTOR(7 DOWNTO 0); -- Received data bytes
  RXrdy           : OUT STD_LOGIC := '0';             -- Application ready for data
  RXlen           : IN  STD_LOGIC_VECTOR(7 DOWNTO 0); -- Number of bytes available
  TXval           : OUT STD_LOGIC := '0';             -- Application has valid data
  TXdat           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- Data byte to send
  TXrdy           : IN  STD_LOGIC;                    -- Entity is ready for data
  TXroom          : IN  STD_LOGIC_VECTOR(7 DOWNTO 0); -- No of free bytes in TX
  TXcork          : OUT STD_LOGIC := '1');            -- Hold TX transmission
END USB_Stimuli;

ARCHITECTURE sim OF usb_stimuli IS

  SIGNAL   rd_data : byte_array(0 TO 7);
  SIGNAL   TX_load : STD_LOGIC := '0';

BEGIN

  p_stimuli_data : PROCESS
  BEGIN
    list("*****************************");
    list("*   Results of tc_02.vhd    *");
    list("*****************************");
    list(" ");
    list(T_No, 10);
    rst_neg_ext <= '0';
    WAIT FOR 301 ns;
    rst_neg_ext <= '1';
    WAIT FOR 40 ns;
    list("Reset completed, initializing");
    TX_load <= '1';
    list(T_No, 20);
    setup(usb, X"00", X"0");                                          --Send Setup to addr 0, endp 0 ..
    send_D0(usb,(X"80",X"06",X"00",X"01",X"00",X"00",X"40",X"00"));  -- .. 'Get Device descriptor'
    wait_slv(usb);                                                   --Recv ACK
    in_token(usb, X"00", X"0");                                      --Send IN-Token
    wait_slv(usb);                                                   --Recv Data1 Device Discriptor
    send_ack(usb);                                                   --Send ACK
    out_token(usb, X"00", X"0");
    send_D0(usb);                                                    --Send Zero Data
    wait_slv(usb);

    list(T_No, 30);
    setup(usb, X"00", X"0");                                         --Setup to addr 0, endp 0 ..
    send_D0(usb,(X"00",X"05",X"03",X"00",X"00",X"00",X"00",X"00"));  -- .. 'Set Address'
    wait_slv(usb);                                                   --Recv ACK
    in_token(usb, X"00", X"0");                                      --Send IN-Token
    wait_slv(usb);                                                   --Recv Data0 zero Length
    send_ack(usb);                                                   --Send ACK

    --Now we may use the new address :
    list(T_No, 50);
    out_token(usb, X"03", X"1");                                     --Send Out-Token to Endpoint 1
    send_D0(usb, (X"11",X"22",X"33",X"44",X"55",X"66",X"77",X"88"));
    wait_slv(usb);
    list(T_No, 51);
    out_token(usb, X"03", X"1");                                     --Send Out-Token to Endpoint 1
    send_D0(usb, (X"11",X"12",X"13",X"14",X"15",X"16",X"17",X"18"));
    wait_slv(usb);
    TXcork <= '0';                                                   --Release TX buffer
    FOR i IN 0 TO 5 LOOP
      list(T_No, 60+i);
      in_token(usb, X"03", X"1");                                    --Send IN-Token to Endpoint 1
      wait_slv(usb);                                                 --Recv Data ?
      send_ack(usb);                                                 --Send ACK
    END LOOP;
 --   list(T_No, 70);
 --   in_token(usb, X"03", X"1");                                    --Send IN-Token to Endpoint 1
 --   wait_slv(usb);                                                 --Recv Data ?
 --   send_ack(usb);                                                 --Send ACK
    IF usb_busy THEN                                                 --is a usb_monitor signal
      WAIT UNTIL NOT usb_busy;
    END IF;
    WAIT FOR 300 ns;
    send_RES(usb);
    WAIT FOR 1 us;
    ASSERT FALSE REPORT"End of Test" SEVERITY FAILURE;
  END PROCESS;

  p_rd_data : PROCESS
    VARIABLE i : NATURAL := 0;
  BEGIN
  WAIT UNTIL rising_edge(clk);
  RXrdy <= '1';
  IF i < 8 THEN
    RXrdy <= '1';
    IF RXval ='1' THEN
      rd_data(i) <= RXdat;
    END IF;
  ELSE
    RXrdy <= '0';
  END IF;
  END PROCESS;

  p_wr_data : PROCESS
    VARIABLE i : NATURAL := 0;
  BEGIN
  WAIT UNTIL rising_edge(clk);
  IF i < 333 AND TXrdy ='1' and TX_load ='1' THEN
    TXval <= '1';
    TXdat <= CONV_STD_LOGIC_VECTOR(i,8);
    i := i +1;
  ELSE
    TXval  <= '0';
  END IF;
  END PROCESS;

END sim;
