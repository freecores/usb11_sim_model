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
--  File name   : USB_tc_01.vhd                                                                             --
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
  USE   work.usb_commands.ALL;

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

--==========================================================================================================--

  --  Get discritor (control transfer to endp 0) is a Setup transaction of 8 data0 bytes:
  --  **************************************************************************
  --  |Setup Packet     |Bytes | Value | Details                               |  CRC5 : Init to "11111"
  --  +-----------------+------+-------+---------------------------------------+         Ignor Sync
  --  |Setup-PID        |  1   |   2Dh |                                       |         Ignor PIP
  --  +-----------------+------+-------+---------------------------------------+         Process Byte 1 + 2
  --  |Addr EndP CRC-5  |  2   | 1000h |                                       |         Send inverted CRC with MSB first
  --  |                 |      |       | .........00000000   Address (7bit)    |         CRC-checker expects "01100"
  --  |                 |      |       | .....0000........   EndP Ar (4bit)    |
  --  |                 |      |       | 00010............   CRC     (5bit)    |
  --  **************************************************************************
  --  **************************************************************************
  --  |Data0 Packet     |Bytes | Value | Details                               |  CRC16 : Init to "1111111111111111"
  --  +-----------------+------+-------+---------------------------------------+          Ignor Sync
  --  |Data0-PID        |  1   |   C3h |                                       |          Process all Bytes
  --  +-----------------+------+-------+---------------------------------------+          Send inverted CRC with MSB first
  --  |bmRequestType    |  1   |   81h |                                       |          CRC-checker expects "1000000000001101";
  --  |                 |      |       |Recipient ...00001   Interface         |
  --  |                 |      |       |Type      .00.....   Standard          |
  --  |                 |      |       |Direction 1.......   Device to Host    |
  --  +-----------------+------+-------+---------------------------------------+
  --  |bRequest         |  1   |   06h |                     Get Descriptor    |
  --  +-----------------+------+-------+---------------------------------------+
  --  |wValue LowByte   |  1   |   00h |                                       |
  --  +-----------------+------+-------+                     Report Descriptor |
  --  |wValue HiByte    |  1   |   22h |                                       |
  --  +-----------------+------+-------+---------------------------------------+
  --  |wIndex           |  2   | 0003h |                     Interface         |
  --  +-----------------+------+-------+---------------------------------------+
  --  |wLength          |  2   | 0072h |                     Descriptor Length |
  --  +-----------------+------+-------+---------------------------------------+
  --  |CRC-16           |  2   | BBCCh |                     CRC-Check         |
  --  **************************************************************************

BEGIN

  p_stimuli_data : PROCESS
  BEGIN
    list(T_No, 10);
    rst_neg_ext <= '0';
    WAIT FOR 301 ns;
    rst_neg_ext <= '1';
    WAIT FOR 40 ns;
    list("Reset completed");
    list(T_No, 20);
    setup(usb, X"00", X"0");                                          --Send Setup to addr 0, endp 0
 -- send_D0(usb,(X"01",X"FF",X"FF",X"80",X"FE",X"00",X"02",X"00"));   --Stuffing test pattern
 -- send_D0(usb,(X"80",X"06",X"00",X"01",X"00",X"00",X"40",X"00"));   --Mouse in Example No4
    send_D0(usb,(X"80",X"06",X"00",X"01",X"00",X"00",X"12",X"00"));   --Send 'Get Device descriptor'
    --=========================================--
    -- Send 'Get Device descriptor' Data Field --
    --=========================================--
    -- Byte 0-1  0x80, 0x06 Get Discriptor     --
    --       2   0x00       Descr.Index=0      --
    --       3   0x01       Descr.Type=Device  --
    --      4-5  0x00, 0x00 Zero               --
    --      6-7  0x12, 0x00 Byte Cnt (18 byte) --
    --=========================================--
    wait_slv(usb);                                                    --Recv ACK
    list(T_No, 30);
    in_token(usb, X"00", X"0");                                       --Send IN-Token
    wait_slv(usb);                                                    --Recv discriptor data
    --Recv 12 01 00 02 00 00 00 40 FE 13 00 1E 00 00 00 00 00 01  Mouse in Example No4
    --===========================================================--
    --Recv 12 01 10 01 02 00 00 40 9A FB 9A FB 20 00 00 00 00 01 --
    --======+==============+========+============================--
    --   0  | bLength      |   18   | Valid Length               --
    --   1  | bDiscType    |    1   | Device                     --
    --  2-3 | bcd USB      | 0x0110 | Spec Version               --
    --   4  | bDeviceClass |   0x02 | Communications             --
    --   5  | bDevSubClass |   0x00 | none                       --
    --   6  | bDevProtocol |   0x00 | none                       --
    --   7  | bMaxPacket   |   0x40 | 64 byte                    --
    --  8-9 | idVendor     | 0xFB9A |   ?                        --
    --  A-B | idProduct    | 0xFB9A |   ?                        --
    --  C-D | bcdDevice    | 0x0020 |   ?                        --
    --   E  | iManufact.   |   0x00 | Index to Manufact. (none)  --
    --   F  | iProduct     |   0x00 | Index to ProdString (none) --
    --  10  | iSerialNo    |   0x00 | Index to SerNo (none)      --
    --  11  | bNumConfig   |   0x01 | 1 Configuration            --
    --===========================================================--
    send_ack(usb);                                                    --Send ACK
    --Once the device descriptor is sent, a status transaction follows.
    list(T_No, 35);
    setup(usb, X"00", X"0");                                          --Send Setup to addr 0, endp 0
    send_D0(usb,(X"80",X"00",X"00",X"00",X"00",X"00",X"02",X"00"));   --Send 'Get Status' (Device, 2 byte)
    wait_slv(usb);
    in_token(usb, X"00", X"0");
    wait_slv(usb);                                                    --get 2 bytes
    send_ACK(usb);                                                    --Send ACK

    --If the transactions were successful, the host will send a zero length packet indicating the overall
    --transaction was successful. The function then replies to this zero length packet indicating its status:
    list(T_No, 40);
    out_token(usb, X"00", X"0");
    send_D0(usb);                                                     --Send Zero Data
    wait_slv(usb);                                                    --Recv ACK

    --Set Address is used during enumeration to assign a unique address to the USB device. The address is
    --specified in wValue and can only be a maximum of 127. This request is unique in that the device does
    --not set its address until after the completion of the status stage (send an IN Token, expect zero data).
    list(T_No, 50);
    setup(usb, X"00", X"0");                                          --Send Setup to addr 0, endp 0
    send_D0(usb,(X"00",X"05",X"03",X"00",X"00",X"00",X"00",X"00"));   --Send 'Set Address' to 0x0003
    wait_slv(usb);                                                    --Recv ACK
    in_token(usb, X"00", X"0");                                       --Send IN packet
    wait_slv(usb);                                                    --Recv Data0 zero Length
    send_ack(usb);                                                    --Send ACK

    --Now we may use the new address :
    list(T_No, 60);
    setup(usb, X"03", X"0");                                          --Send Setup to addr 3, endp 0
    send_D0(usb,(X"80",X"06",X"00",X"01",X"00",X"00",X"12",X"00"));   --Send 'Get Device descriptor'
    wait_slv(usb);                                                    --Recv ACK
    list(T_No, 70);
    in_token(usb, X"03", X"0");                                       --Send IN-Token
    wait_slv(usb);
    send_ack(usb);                                                    --Send ACK
    IF usb_busy THEN                                                  -- usb_usy is set in usb_monitor
      WAIT UNTIL NOT usb_busy;
    END IF;
    ASSERT FALSE REPORT"End of Test" SEVERITY FAILURE;
  END PROCESS;

END sim;

