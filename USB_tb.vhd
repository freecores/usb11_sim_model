
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
--  File name   : USB_tb.vhd                                                                                --
--  Author      : Martin Neumann  martin@neumanns-mail.de                                                   --
--  Description : USB test bench used with usb_mster.vhd, usb_Stimuli.vhd and usb_fs_monitor.vhd.           --
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
  USE work.usb_commands.ALL;

ENTITY usb_tb IS
END usb_tb;

ARCHITECTURE sim OF usb_tb IS

  CONSTANT BUFSIZE_BITS  : POSITIVE  := 8;

  SIGNAL FPGA_ready     : STD_LOGIC;
  SIGNAL RXdat          : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL RXlen          : STD_LOGIC_VECTOR(BUFSIZE_BITS-1 DOWNTO 0);
  SIGNAL RXrdy          : STD_LOGIC;
  SIGNAL RXval          : STD_LOGIC;
  SIGNAL TXcork         : STD_LOGIC;
  SIGNAL TXdat          : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL TXrdy          : STD_LOGIC;
  SIGNAL TXroom         : STD_LOGIC_VECTOR(BUFSIZE_BITS-1 DOWNTO 0);
  SIGNAL TXval          : STD_LOGIC;
  SIGNAL USB_rst        : STD_LOGIC;
  SIGNAL online         : STD_LOGIC;
  SIGNAL clk_12MHz      : STD_LOGIC;
  SIGNAL clk_60MHz      : STD_LOGIC;
  SIGNAL rst_neg_ext    : STD_LOGIC;
  SIGNAL rst_neg_syc    : STD_LOGIC;
  SIGNAL usb_Dn         : STD_LOGIC := 'L';
  SIGNAL usb_Dp         : STD_LOGIC := 'Z'; -- allow forcing 'H', avoid 'X'

BEGIN

  p_clk_60MHz : PROCESS
  BEGIN
    clk_60MHz <= '0';
    WAIT FOR 2 ns;
    While true loop
      clk_60MHz <= '0';
      WAIT FOR 8000 ps;
      clk_60MHz <= '1';
  --  WAIT FOR 8667 ps; -- 60 MHz
      WAIT FOR 8393 ps; -- 61 MHz
  --  WAIT FOR 8949 ps; -- 59 MHz
    end loop;
  END PROCESS;

  p_clk_12MHz : PROCESS
  BEGIN
    clk_12MHz <= '0';
    WAIT FOR 20866 ps;
    clk_12MHz <= '1';
    WAIT FOR 41600 ps;
    clk_12MHz <= '0';
    WAIT FOR 20867 ps;
  END PROCESS;

  p_rst_neg_ext : PROCESS
  BEGIN
    rst_neg_ext <= '0';
    WAIT FOR 301 ns;
    rst_neg_ext <= '1';
    WAIT;
  END PROCESS;

  usb_fs_master : ENTITY work.usb_fs_master
  port map (
    usb_clk     => clk_12MHz,
    int_clk     => clk_60MHz,
    rst_neg_ext => rst_neg_ext,
    usb_Dp      => usb_dp,
    usb_Dn      => usb_dn,
    RXval       => RXval,
    RXdat       => RXdat,
    RXrdy       => RXrdy,
    RXlen       => RXlen,
    TXval       => TXval,
    TXdat       => TXdat,
    TXrdy       => TXrdy,
    TXroom      => TXroom,
    TXcork      => TXcork
  );

  usb_dp <= 'H' WHEN FPGA_ready ='1' ELSE 'L'; -- connect FPGA_ready to the pullup resistor logic, ....
  usb_dn <= 'L';                               -- ... keeping usb_dp='L' during FPGA initialization.

  usb_fs_slave_1 : ENTITY work.usb_fs_slave
  GENERIC MAP(
    VENDORID        => X"FB9A",
    PRODUCTID       => X"FB9A",
    VERSIONBCD      => X"0020",
    SELFPOWERED     => FALSE,
    BUFSIZE_BITS    => BUFSIZE_BITS)
  PORT MAP(
    clk             => clk_60MHz,     -- i
    rst_neg_ext     => rst_neg_ext,   -- i
    rst_neg_syc     => rst_neg_syc,   -- o  RST_NEG_EXT streched to next clock
    d_pos           => usb_dp,        -- io Pos USB data line
    d_neg           => usb_dn,        -- io Neg USB data line
    USB_rst         => USB_rst,       -- o  USB reset detected (SE0 > 2.5 us)
    online          => online,        -- o  High when the device is in Config state.
    RXval           => RXval,         -- o  High if a received byte available on RXDAT.
    RXdat           => RXdat,         -- o  Received data byte, valid if RXVAL is high.
    RXrdy           => RXrdy,         -- i  High if application is ready to receive.
    RXlen           => RXlen,         -- o  No of bytes available in receive buffer.
    TXval           => TXval,         -- i  High if the application has data to send.
    TXdat           => TXdat,         -- i  Data byte to send, must be valid if TXVAL is high.
    TXrdy           => TXrdy,         -- o  High if the entity is ready to accept the next byte.
    TXroom          => TXroom,        -- o  No of free bytes in transmit buffer.
    TXcork          => TXcork,        -- i  Temp. suppress transmissions at the outgoing endpoint.
    FPGA_ready      => FPGA_ready     -- o  Connect FPGA_ready to the pullup resistor logic
  );

END sim;

