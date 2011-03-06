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
--  File name   : usb_fs_monitor.vhd                                                                        --
--  Author      : Martin Neumann  martin@neumanns-mail.de                                                   --
--  Description : USB bus monitor, logs all USB activities in result.out file.                              --
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

LIBRARY IEEE;
  USE IEEE.std_logic_1164.all;
  USE IEEE.std_logic_textio.all;
  USE std.textio.all;
LIBRARY work;
  USE work.usb_commands.all;

ENTITY usb_fs_monitor IS PORT(
  clk_60MHz       : IN STD_LOGIC;
  master_oe       : IN STD_LOGIC;
  usb_Dp          : IN STD_LOGIC;
  usb_Dn          : IN STD_LOGIC);
END usb_fs_monitor;

ARCHITECTURE SIM OF usb_fs_monitor IS
  TYPE   state_mode   IS(idle, pid, addr, frame, data, spec, eop);
  SIGNAL usb_state      : state_mode;
  SIGNAL usb_dp_sync    : STD_LOGIC;
  SIGNAL usb_dn_sync    : STD_LOGIC;
  SIGNAL clk_en         : STD_LOGIC;
  SIGNAL usb_byte       : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL byte_valid     : STD_LOGIC;
  SIGNAL xfer_busy      : STD_LOGIC;
  SIGNAL bit_cntr       : NATURAL;
  SIGNAL dll_cntr       : NATURAL;
  SIGNAL next_state     : state_mode;
  SIGNAL edge_detect    : STD_LOGIC;
  SIGNAL usb_dp_s0      : STD_LOGIC;
  SIGNAL usb_dp_s1      : STD_LOGIC;
  SIGNAL usb_dn_s0      : STD_LOGIC;
  SIGNAL usb_dn_s1      : STD_LOGIC;
  SIGNAL usb_dp_last    : STD_LOGIC;

BEGIN

--==========================================================================================================--
  -- Synchronize Inputs                                                                                     --
--==========================================================================================================--

  p_usb_dp_sync: process (clk_60MHz)
  begin
    if rising_edge(clk_60MHz) then
      usb_dp_s0  <= usb_dp;
      usb_dp_s1  <= usb_dp_s0;
      if (usb_dp_s0 and usb_dp_s1) ='1' then
        usb_dp_sync <= '1';
      elsif (usb_dp_s0 OR usb_dp_s1) ='0' then
        usb_dp_sync <= '0';
      end if;
    end if;
  end process;

  p_usb_dn_sync: process (clk_60MHz)
  begin
    if rising_edge(clk_60MHz) then
      usb_dn_s0  <= usb_Dn;
      usb_dn_s1  <= usb_dn_s0;
      if (usb_dn_s0 and usb_dn_s1) ='1' then
        usb_dn_sync <= '1';
      elsif (usb_dn_s0 OR usb_dn_s1) ='0' then
        usb_dn_sync <= '0';
      end if;
    end if;
  end process;

  p_usb_d_last: process (clk_60MHz)
  begin
    if rising_edge(clk_60MHz) THEN
      usb_dp_last <= usb_dp_sync;
    end if;
  end process;

  edge_detect <= usb_dp_last XOR usb_dp_sync;

  p_dll_cntr: process (clk_60MHz)
  begin
    if rising_edge(clk_60MHz) then
      if edge_detect ='1' then
        if dll_cntr >= 8 then
          dll_cntr <= 2;         -- clk_en detected, now centered in following cycle
        else
          dll_cntr <= 7;         -- adjust clk_en to center cycle
        end if;
      elsif dll_cntr >= 8 then   -- normal count sequence is 8->4->5->6->7->8->4...
        dll_cntr <= 4;
      else
        dll_cntr <= dll_cntr +1;
      end if;
    end if;
  end process;

  clk_en <= '1' WHEN dll_cntr >= 8 ELSE '0';

--==========================================================================================================--
  -- Analyse USB Inputs                                                                                     --
--==========================================================================================================--


  p_xfer_busy : PROCESS
    VARIABLE sync_pattern : STD_LOGIC_VECTOR(7 DOWNTO 0);
  BEGIN
    WAIT UNTIL rising_edge(clk_60MHz) AND clk_en ='1';
    sync_pattern := sync_pattern(6 DOWNTO 0) & usb_Dp_sync;
    IF sync_pattern = "01010100" THEN
      xfer_busy <= '1';
      WAIT UNTIL rising_edge(clk_60MHz) AND usb_Dp_sync ='0' AND usb_Dn_sync ='0' AND clk_en ='1';
    END IF;
    xfer_busy <= '0';
  END PROCESS;

  p_se0_det : PROCESS
    VARIABLE sync_pattern : STD_LOGIC_VECTOR(7 DOWNTO 0);
    VARIABLE se0_lev      : BOOLEAN;
    VARIABLE se0_time     : Time := 0 ns;
    VARIABLE v_LineWr     : line := NULL;
  BEGIN
    WAIT UNTIL rising_edge(clk_60MHz) AND clk_en ='1';
    IF usb_Dp_sync ='0' AND usb_Dn_sync ='0' THEN
      IF NOT se0_lev THEN
        se0_lev  := TRUE;
        se0_time := now;
      END IF;
    ELSE
      IF se0_lev THEN
        se0_time := now - se0_time;
        IF se0_time >= 200 ns THEN
          write (v_LineWr, now, right,15);
          IF se0_time >= 2500 ns THEN
            write (v_LineWr, STRING'("  USB Reset detected for "));
          ELSE
            write (v_LineWr, STRING'("  USB lines at SE0 for "));
          END IF;
          write (v_LineWr, se0_time, right,15);
          PrintLine(v_LineWr);
        END IF;
      END IF;
      se0_lev := FALSE;
    END IF;
  END PROCESS;

  p_usb_byte : PROCESS(xfer_busy, clk_60MHz, clk_en)
    VARIABLE hold, usb_last : STD_LOGIC;
    VARIABLE ones_cnt : NATURAL;
  BEGIN
    IF xfer_busy ='0' THEN
      usb_last := usb_Dp_sync;
      bit_cntr <= 0;
      ones_cnt := 0;
      byte_valid <= '0';
      usb_byte <= (OTHERS => 'H');
    ELSIF rising_edge(clk_60MHz) AND clk_en ='1' THEN
      IF usb_Dp_sync = usb_last THEN
        usb_byte <= '1' & usb_byte(7 DOWNTO 1);
        bit_cntr <= (bit_cntr +1) MOD 8;
        ones_cnt := (ones_cnt +1);
        IF ones_cnt > 6 THEN
          ASSERT FALSE REPORT"Stuffing error" SEVERITY ERROR;
        END IF;
        hold := '0';
      ELSE
        IF ones_cnt /= 6 THEN
          usb_byte <= '0' & usb_byte(7 DOWNTO 1);
          bit_cntr <= (bit_cntr +1) MOD 8;
          hold := '0';
        ELSE
          hold := '1';
        END IF;
        ones_cnt := 0;
      END IF;
      IF bit_cntr=7 THEN
        byte_valid <= NOT hold;
      ELSE
        byte_valid <= '0';
      END IF;
      usb_last := usb_Dp_sync;
    END IF;
  END PROCESS;

  p_usb_state : PROCESS
  BEGIN
    WAIT UNTIL rising_edge(clk_60MHz) AND clk_en ='1';
    IF xfer_busy ='0' THEN
      usb_state <= idle;
    ELSIF usb_Dp_sync ='0' AND usb_Dn_sync ='0' THEN
      usb_state <= eop;
    ELSE
      usb_state <= next_state;
    END IF;
  END PROCESS;

  p_next_state : PROCESS
    VARIABLE address  : STD_LOGIC_VECTOR(6 DOWNTO 0);
    VARIABLE endpoint : STD_LOGIC_VECTOR(3 DOWNTO 0);
    VARIABLE frame_no : STD_LOGIC_VECTOR(10 DOWNTO 0);
    VARIABLE byte_cnt : NATURAL;
    VARIABLE v_LineWr : line := NULL;
  BEGIN
    WAIT UNTIL rising_edge(clk_60MHz) AND clk_en ='1';
    CASE usb_state IS
      WHEN idle => next_state <= pid;
      WHEN pid  => IF byte_valid ='1' THEN
                     IF usb_byte(3 DOWNTO 0) /= NOT usb_byte(7 DOWNTO 4) THEN
                       ASSERT FALSE REPORT"PID error" SEVERITY ERROR;
                     END IF;
                     write (v_LineWr, now, right,15);
                     IF master_oe ='1' THEN
                       write (v_LineWr, STRING'("  Send "));
                     ELSE
                       write (v_LineWr, STRING'("  Recv "));
                     END IF;
                     byte_cnt := 0;
                     CASE usb_byte(3 DOWNTO 0) IS
                       WHEN x"1" => next_state <= addr;
                                    write (v_LineWr, STRING'("OUT-Token"));
                       WHEN x"9" => next_state <= addr;
                                    write (v_LineWr, STRING'("IN-Token"));
                       WHEN x"5" => next_state <= frame;
                                    write (v_LineWr, STRING'("SOF-Token"));
                       WHEN x"D" => next_state <= addr;
                                    write (v_LineWr, STRING'("Setup"));
                       WHEN x"3" => next_state <= data;
                                    write (v_LineWr, STRING'("Data0"));
                       WHEN x"B" => next_state <= data;
                                    write (v_LineWr, STRING'("Data1"));
                       WHEN x"7" => next_state <= data;
                                    write (v_LineWr, STRING'("Data2"));
                       WHEN x"F" => next_state <= data;
                                    write (v_LineWr, STRING'("MData"));
                       WHEN x"2" => next_state <= idle;
                                    write (v_LineWr, STRING'("ACK"));
                       WHEN x"A" => next_state <= idle;
                                    write (v_LineWr, STRING'("NAK"));
                       WHEN x"E" => next_state <= idle;
                                    write (v_LineWr, STRING'("STALL"));
                       WHEN x"6" => next_state <= idle;
                                    write (v_LineWr, STRING'("NYET"));
                    -- WHEN x"C" => next_state <= spec;
                    --              write (v_LineWr, STRING'("Preamble"));
                       WHEN x"C" => next_state <= spec;
                                    write (v_LineWr, STRING'("ERR"));
                       WHEN x"8" => next_state <= spec;
                                    write (v_LineWr, STRING'("Split"));
                       WHEN x"4" => next_state <= spec;
                                    write (v_LineWr, STRING'("Ping"));
                       WHEN OTHERS => next_state <= idle;
                                      ASSERT FALSE REPORT"PID is zero" SEVERITY ERROR;
                     END CASE;
                   END IF;
      WHEN addr => IF byte_valid ='1' THEN
                     address  := usb_byte(6 DOWNTO 0);
                     endpoint(0) := usb_byte(7);
                     WAIT UNTIL rising_edge(clk_60MHz) AND byte_valid ='1' AND clk_en ='1';
                     endpoint(3 DOWNTO 1) := usb_byte(2 DOWNTO 0);
                     write (v_LineWr, STRING'(": Address 0x"));
                     HexWrite (v_LineWr, address);
                     write (v_LineWr, STRING'(", Endpoint 0x"));
                     HexWrite (v_LineWr, endpoint);
                     write (v_LineWr, STRING'(", CRC5 0x"));
                     HexWrite (v_LineWr, usb_byte(7 DOWNTO 3));
                     next_state <= idle;
                   END IF;
      WHEN frame =>IF byte_valid ='1' THEN
                     frame_no(7 DOWNTO 0) := usb_byte;
                     WAIT UNTIL rising_edge(clk_60MHz) AND byte_valid ='1' AND clk_en ='1';
                     frame_no(10 DOWNTO 8) := usb_byte(2 DOWNTO 0);
                     write (v_LineWr, STRING'(": Frame No 0x"));
                     HexWrite (v_LineWr, frame_no);
                     write (v_LineWr, STRING'(", CRC5 0x"));
                     HexWrite (v_LineWr, usb_byte(7 DOWNTO 3));
                     next_state <= idle;
                   END IF;
      WHEN data => WAIT UNTIL rising_edge(clk_60MHz) AND byte_valid ='1' AND clk_en ='1';
                   byte_cnt := byte_cnt +1;
                   IF byte_cnt = 17 THEN
                     PrintLine(v_LineWr);
                     write (v_LineWr, now, right,15);
                     write (v_LineWr, STRING'("       ....."));
                     byte_cnt := 1;
                   END IF;
                   write (v_LineWr, STRING'(" 0x"));
                   HexWrite (v_LineWr, usb_byte);
      WHEN eop  => next_state <= idle;
                   PrintLine(v_LineWr);
      WHEN OTHERS => next_state <= idle;
    END CASE;
  END PROCESS;

  usb_busy <= usb_state /= idle;  -- global signal, used in usb_commands --

END SIM;

--======================================== END OF usb_fs_monitor.vhd =======================================--
