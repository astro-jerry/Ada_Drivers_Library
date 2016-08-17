------------------------------------------------------------------------------
--                                                                          --
--                    Copyright (C) 2015, AdaCore                           --
--                                                                          --
--  Redistribution and use in source and binary forms, with or without      --
--  modification, are permitted provided that the following conditions are  --
--  met:                                                                    --
--     1. Redistributions of source code must retain the above copyright    --
--        notice, this list of conditions and the following disclaimer.     --
--     2. Redistributions in binary form must reproduce the above copyright --
--        notice, this list of conditions and the following disclaimer in   --
--        the documentation and/or other materials provided with the        --
--        distribution.                                                     --
--     3. Neither the name of STMicroelectronics nor the names of its       --
--        contributors may be used to endorse or promote products derived   --
--        from this software without specific prior written permission.     --
--                                                                          --
--   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS    --
--   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT      --
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR  --
--   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   --
--   HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, --
--   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT       --
--   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,  --
--   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY  --
--   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT    --
--   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE  --
--   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.   --
--                                                                          --
--                                                                          --
--  This file is based on:                                                  --
--                                                                          --
--   @file    stm32f4xx_hal_dma.c                                           --
--   @author  MCD Application Team                                          --
--   @version V1.1.0                                                        --
--   @date    19-June-2014                                                  --
--   @brief   DMA HAL module driver.                                        --
--                                                                          --
--   COPYRIGHT(c) 2014 STMicroelectronics                                   --
------------------------------------------------------------------------------

with Ada.Unchecked_Conversion;
with System.Storage_Elements;

with STM32_SVD.DMA; use STM32_SVD.DMA;

package body STM32.DMA is

   type DMA_Stream is access all Stream_Cluster;

   function Get_Stream
     (Port : DMA_Controller;
      Num  : DMA_Stream_Selector) return DMA_Stream
     with Inline;

   procedure Set_Interrupt_Enabler
     (This_Stream : DMA_Stream;
      Source      : DMA_Interrupt;
      Value       : Boolean);
   --  An internal routine, used to enable and disable the specified interrupt

   function "-" is new Ada.Unchecked_Conversion
     (Memory_Buffer_Target, Boolean);
   function "-" is new Ada.Unchecked_Conversion
     (Boolean, Memory_Buffer_Target);

   ----------------
   -- Get_Stream --
   ----------------

   function Get_Stream
     (Port : DMA_Controller;
      Num  : DMA_Stream_Selector) return DMA_Stream
   is
      Addr : System.Address;
      function To_Stream is new Ada.Unchecked_Conversion
        (System.Address, DMA_Stream);
   begin
      Addr := Port.Stream (DMA_Stream_Selector'Enum_Rep (Num))'Address;

      return To_Stream (Addr);
   end Get_Stream;

   ------------
   -- Enable --
   ------------

   procedure Enable
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector)
   is
   begin
      Get_Stream (Unit, Stream).SxCR.EN := True;
   end Enable;

   -------------
   -- Enabled --
   -------------

   function Enabled
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector)
      return Boolean
   is
   begin
      return Get_Stream (Unit, Stream).SxCR.EN;
   end Enabled;

   -------------
   -- Disable --
   -------------

   procedure Disable
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector)
   is
   begin
      Get_Stream (Unit, Stream).SxCR.EN := False;
      --  the STMicro Reference Manual RM0090, Doc Id 018909 Rev 6, pg 319,
      --  step 1 says we must await the bit actually clearing, to confirm no
      --  ongoing operation remains active.
      loop
         exit when not Enabled (Unit, Stream);
      end loop;
   end Disable;

   ---------------------------
   -- Set_Interrupt_Enabler --
   ---------------------------

   procedure Set_Interrupt_Enabler
     (This_Stream : DMA_Stream;
      Source      : DMA_Interrupt;
      Value       : Boolean)
   is
   begin
      case Source is
         when Direct_Mode_Error_Interrupt =>
            This_Stream.SxCR.DMEIE := Value;
         when Transfer_Error_Interrupt =>
            This_Stream.SxCR.TEIE := Value;
         when Half_Transfer_Complete_Interrupt =>
            This_Stream.SxCR.HTIE := Value;
         when Transfer_Complete_Interrupt =>
            This_Stream.SxCR.TCIE := Value;
         when FIFO_Error_Interrupt =>
            This_Stream.SxFCR.FEIE := Value;
      end case;
   end Set_Interrupt_Enabler;

   ----------------------
   -- Enable_Interrupt --
   ----------------------

   procedure Enable_Interrupt
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector;
      Source : DMA_Interrupt)
   is
   begin
      Set_Interrupt_Enabler (Get_Stream (Unit, Stream), Source, True);
   end Enable_Interrupt;

   -----------------------
   -- Disable_Interrupt --
   -----------------------

   procedure Disable_Interrupt
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector;
      Source : DMA_Interrupt)
   is
   begin
      Set_Interrupt_Enabler (Get_Stream (Unit, Stream), Source, False);
   end Disable_Interrupt;

   -----------------------
   -- Interrupt_Enabled --
   -----------------------

   function Interrupt_Enabled
     (Unit        : DMA_Controller;
      Stream      : DMA_Stream_Selector;
      Source      : DMA_Interrupt)
      return Boolean
   is
      Result      : Boolean;
      This_Stream : DMA_Stream renames Get_Stream (Unit, Stream);
      --  this is a bit heavy, considering it will be called from interrupt
      --  handlers.
      --  TODO: consider a much lower level implementation, based on bit-masks.
   begin
      case Source is
         when Direct_Mode_Error_Interrupt =>
            Result := This_Stream.SxCR.DMEIE;
         when Transfer_Error_Interrupt =>
            Result := This_Stream.SxCR.TEIE;
         when Half_Transfer_Complete_Interrupt =>
            Result := This_Stream.SxCR.HTIE;
         when Transfer_Complete_Interrupt =>
            Result := This_Stream.SxCR.TCIE;
         when FIFO_Error_Interrupt =>
            Result := This_Stream.SxFCR.FEIE;
      end case;
      return Result;
   end Interrupt_Enabled;

   --------------------
   -- Start_Transfer --
   --------------------

   procedure Start_Transfer
     (Unit        : DMA_Controller;
      Stream      : DMA_Stream_Selector;
      Source      : Address;
      Destination : Address;
      Data_Count  : Short)
   is
   begin
      Disable (Unit, Stream);  --  per the RM, eg section 10.5.6 for the NDTR

      Configure_Data_Flow
        (Unit,
         Stream,
         Source      => Source,
         Destination => Destination,
         Data_Count => Data_Count);

      Enable (Unit, Stream);
   end Start_Transfer;

   ------------------------------------
   -- Start_Transfer_with_Interrupts --
   ------------------------------------

   procedure Start_Transfer_with_Interrupts
     (Unit               : DMA_Controller;
      Stream             : DMA_Stream_Selector;
      Source             : Address;
      Destination        : Address;
      Data_Count         : Short;
      Enabled_Interrupts : Interrupt_Selections := (others => True))
   is
   begin
      Disable (Unit, Stream);  --  per the RM, eg section 10.5.6 for the NDTR

      Configure_Data_Flow
        (Unit,
         Stream,
         Source      => Source,
         Destination => Destination,
         Data_Count  => Data_Count);

      for Selected_Interrupt in Enabled_Interrupts'Range loop
         if Enabled_Interrupts (Selected_Interrupt) then
            Enable_Interrupt (Unit, Stream, Selected_Interrupt);
         else
            Disable_Interrupt (Unit, Stream, Selected_Interrupt);
         end if;
      end loop;

      Enable (Unit, Stream);
   end Start_Transfer_with_Interrupts;

   -------------------------
   -- Configure_Data_Flow --
   -------------------------

   procedure Configure_Data_Flow
     (Unit        : DMA_Controller;
      Stream      : DMA_Stream_Selector;
      Source      : Address;
      Destination : Address;
      Data_Count  : Short)
   is
      This_Stream : DMA_Stream renames Get_Stream (Unit, Stream);
      function W is new Ada.Unchecked_Conversion
        (Address, Word);
   begin
      --  the following assignment has NO EFFECT if flow is controlled by
      --  peripheral. The hardware resets it to 16#FFFF#, see RM0090 10.3.15.
      This_Stream.SxNDTR.NDT := Data_Count;

      if This_Stream.SxCR.DIR = Memory_To_Peripheral'Enum_Rep then
         This_Stream.SxM0AR := W (Source);
         This_Stream.SxPAR  := W (Destination);
      else
         This_Stream.SxPAR  := W (Source);
         This_Stream.SxM0AR := W (Destination);
      end if;
   end Configure_Data_Flow;

   --------------------
   -- Abort_Transfer --
   --------------------

   procedure Abort_Transfer
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector;
      Result : out DMA_Error_Code)
   is
      Max_Abort_Time : constant Time_Span := Seconds (1);
      Timeout        : Time;
      This_Stream    : DMA_Stream renames Get_Stream (Unit, Stream);
   begin
      Disable (Unit, Stream);
      Timeout := Clock + Max_Abort_Time;
      loop
         exit when not This_Stream.SxCR.EN;
         if Clock > Timeout then
            Result := DMA_Timeout_Error;
            return;
         end if;
      end loop;
      Result := DMA_No_Error;
   end Abort_Transfer;

   -------------------------
   -- Poll_For_Completion --
   -------------------------

   procedure Poll_For_Completion
     (Unit           : in out DMA_Controller;
      Stream         : DMA_Stream_Selector;
      Expected_Level : DMA_Transfer_Level;
      Timeout        : Time_Span;
      Result         : out DMA_Error_Code)
   is
      Deadline : constant Time := Clock + Timeout;
   begin
      Result := DMA_No_Error;  -- initially anyway

      Polling : loop
         if Expected_Level = Full_Transfer then
            exit Polling when
              Status (Unit, Stream, Transfer_Complete_Indicated);
         else
            exit Polling when
              Status (Unit, Stream, Half_Transfer_Complete_Indicated);
         end if;

         if Status (Unit, Stream, Transfer_Error_Indicated) or
            Status (Unit, Stream, FIFO_Error_Indicated) or
            Status (Unit, Stream, Direct_Mode_Error_Indicated)
         then
            Clear_Status (Unit, Stream, Transfer_Error_Indicated);
            Clear_Status (Unit, Stream, FIFO_Error_Indicated);
            Clear_Status (Unit, Stream, Direct_Mode_Error_Indicated);

            Result := DMA_Device_Error;
            return;
         end if;

         if Clock > Deadline then
            Result := DMA_Timeout_Error;
            return;
         end if;
      end loop Polling;

      Clear_Status (Unit, Stream, Half_Transfer_Complete_Indicated);

      if Expected_Level = Full_Transfer then
         Clear_Status (Unit, Stream, Transfer_Complete_Indicated);
      else
         Clear_Status (Unit, Stream, Half_Transfer_Complete_Indicated);
      end if;
   end Poll_For_Completion;

   ------------------
   -- Clear_Status --
   ------------------

   procedure Clear_Status
     (Unit   : in out DMA_Controller;
      Stream : DMA_Stream_Selector;
      Flag   : DMA_Status_Flag)
   is
   begin
      case Stream is
         when Stream_0 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  Unit.LIFCR.CFEIF0 := True;
               when Direct_Mode_Error_Indicated =>
                  Unit.LIFCR.CDMEIF0 := True;
               when Transfer_Error_Indicated =>
                  Unit.LIFCR.CTEIF0 := True;
               when Half_Transfer_Complete_Indicated =>
                  Unit.LIFCR.CHTIF0 := True;
               when Transfer_Complete_Indicated =>
                  Unit.LIFCR.CTCIF0 := True;
            end case;

         when Stream_1 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  Unit.LIFCR.CFEIF1 := True;
               when Direct_Mode_Error_Indicated =>
                  Unit.LIFCR.CDMEIF1 := True;
               when Transfer_Error_Indicated =>
                  Unit.LIFCR.CTEIF1 := True;
               when Half_Transfer_Complete_Indicated =>
                  Unit.LIFCR.CHTIF1 := True;
               when Transfer_Complete_Indicated =>
                  Unit.LIFCR.CTCIF1 := True;
            end case;

         when Stream_2 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  Unit.LIFCR.CFEIF2 := True;
               when Direct_Mode_Error_Indicated =>
                  Unit.LIFCR.CDMEIF2 := True;
               when Transfer_Error_Indicated =>
                  Unit.LIFCR.CTEIF2 := True;
               when Half_Transfer_Complete_Indicated =>
                  Unit.LIFCR.CHTIF2 := True;
               when Transfer_Complete_Indicated =>
                  Unit.LIFCR.CTCIF2 := True;
            end case;

         when Stream_3 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  Unit.LIFCR.CFEIF3 := True;
               when Direct_Mode_Error_Indicated =>
                  Unit.LIFCR.CDMEIF3 := True;
               when Transfer_Error_Indicated =>
                  Unit.LIFCR.CTEIF3 := True;
               when Half_Transfer_Complete_Indicated =>
                  Unit.LIFCR.CHTIF3 := True;
               when Transfer_Complete_Indicated =>
                  Unit.LIFCR.CTCIF3 := True;
            end case;

         when Stream_4 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  Unit.HIFCR.CFEIF4 := True;
               when Direct_Mode_Error_Indicated =>
                  Unit.HIFCR.CDMEIF4 := True;
               when Transfer_Error_Indicated =>
                  Unit.HIFCR.CTEIF4 := True;
               when Half_Transfer_Complete_Indicated =>
                  Unit.HIFCR.CHTIF4 := True;
               when Transfer_Complete_Indicated =>
                  Unit.HIFCR.CTCIF4 := True;
            end case;

         when Stream_5 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  Unit.HIFCR.CFEIF5 := True;
               when Direct_Mode_Error_Indicated =>
                  Unit.HIFCR.CDMEIF5 := True;
               when Transfer_Error_Indicated =>
                  Unit.HIFCR.CTEIF5 := True;
               when Half_Transfer_Complete_Indicated =>
                  Unit.HIFCR.CHTIF5 := True;
               when Transfer_Complete_Indicated =>
                  Unit.HIFCR.CTCIF5 := True;
            end case;

         when Stream_6 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  Unit.HIFCR.CFEIF6 := True;
               when Direct_Mode_Error_Indicated =>
                  Unit.HIFCR.CDMEIF6 := True;
               when Transfer_Error_Indicated =>
                  Unit.HIFCR.CTEIF6 := True;
               when Half_Transfer_Complete_Indicated =>
                  Unit.HIFCR.CHTIF6 := True;
               when Transfer_Complete_Indicated =>
                  Unit.HIFCR.CTCIF6 := True;
            end case;

         when Stream_7 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  Unit.HIFCR.CFEIF7 := True;
               when Direct_Mode_Error_Indicated =>
                  Unit.HIFCR.CDMEIF7 := True;
               when Transfer_Error_Indicated =>
                  Unit.HIFCR.CTEIF7 := True;
               when Half_Transfer_Complete_Indicated =>
                  Unit.HIFCR.CHTIF7 := True;
               when Transfer_Complete_Indicated =>
                  Unit.HIFCR.CTCIF7 := True;
            end case;
      end case;
   end Clear_Status;

   ----------------------
   -- Clear_All_Status --
   ----------------------

   procedure Clear_All_Status
     (Unit   : in out DMA_Controller;
      Stream : DMA_Stream_Selector)
   is
   begin
      case Stream is
         when Stream_0 =>
            Unit.LIFCR.CFEIF0 := True;
            Unit.LIFCR.CDMEIF0 := True;
            Unit.LIFCR.CTEIF0 := True;
            Unit.LIFCR.CHTIF0 := True;
            Unit.LIFCR.CTCIF0 := True;

         when Stream_1 =>
            Unit.LIFCR.CFEIF1 := True;
            Unit.LIFCR.CDMEIF1 := True;
            Unit.LIFCR.CTEIF1 := True;
            Unit.LIFCR.CHTIF1 := True;
            Unit.LIFCR.CTCIF1 := True;

         when Stream_2 =>
            Unit.LIFCR.CFEIF2 := True;
            Unit.LIFCR.CDMEIF2 := True;
            Unit.LIFCR.CTEIF2 := True;
            Unit.LIFCR.CHTIF2 := True;
            Unit.LIFCR.CTCIF2 := True;

         when Stream_3 =>
            Unit.LIFCR.CFEIF3 := True;
            Unit.LIFCR.CDMEIF3 := True;
            Unit.LIFCR.CTEIF3 := True;
            Unit.LIFCR.CHTIF3 := True;
            Unit.LIFCR.CTCIF3 := True;

         when Stream_4 =>
            Unit.HIFCR.CFEIF4 := True;
            Unit.HIFCR.CDMEIF4 := True;
            Unit.HIFCR.CTEIF4 := True;
            Unit.HIFCR.CHTIF4 := True;
            Unit.HIFCR.CTCIF4 := True;

         when Stream_5 =>
            Unit.HIFCR.CFEIF5 := True;
            Unit.HIFCR.CDMEIF5 := True;
            Unit.HIFCR.CTEIF5 := True;
            Unit.HIFCR.CHTIF5 := True;
            Unit.HIFCR.CTCIF5 := True;

         when Stream_6 =>
            Unit.HIFCR.CFEIF6 := True;
            Unit.HIFCR.CDMEIF6 := True;
            Unit.HIFCR.CTEIF6 := True;
            Unit.HIFCR.CHTIF6 := True;
            Unit.HIFCR.CTCIF6 := True;

         when Stream_7 =>
            Unit.HIFCR.CFEIF7 := True;
            Unit.HIFCR.CDMEIF7 := True;
            Unit.HIFCR.CTEIF7 := True;
            Unit.HIFCR.CHTIF7 := True;
            Unit.HIFCR.CTCIF7 := True;
      end case;
   end Clear_All_Status;

   ------------
   -- Status --
   ------------

   function Status
     (Unit    : DMA_Controller;
      Stream  : DMA_Stream_Selector;
      Flag    : DMA_Status_Flag)
      return Boolean
   is
   begin
      case Stream is
         when Stream_0 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  return Unit.LISR.FEIF0;
               when Direct_Mode_Error_Indicated =>
                  return Unit.LISR.DMEIF0;
               when Transfer_Error_Indicated =>
                  return Unit.LISR.TEIF0;
               when Half_Transfer_Complete_Indicated =>
                  return Unit.LISR.HTIF0;
               when Transfer_Complete_Indicated =>
                  return Unit.LISR.TCIF0;
            end case;

         when Stream_1 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  return Unit.LISR.FEIF1;
               when Direct_Mode_Error_Indicated =>
                  return Unit.LISR.DMEIF1;
               when Transfer_Error_Indicated =>
                  return Unit.LISR.TEIF1;
               when Half_Transfer_Complete_Indicated =>
                  return Unit.LISR.HTIF1;
               when Transfer_Complete_Indicated =>
                  return Unit.LISR.TCIF1;
            end case;

         when Stream_2 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  return Unit.LISR.FEIF2;
               when Direct_Mode_Error_Indicated =>
                  return Unit.LISR.DMEIF2;
               when Transfer_Error_Indicated =>
                  return Unit.LISR.TEIF2;
               when Half_Transfer_Complete_Indicated =>
                  return Unit.LISR.HTIF2;
               when Transfer_Complete_Indicated =>
                  return Unit.LISR.TCIF2;
            end case;

         when Stream_3 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  return Unit.LISR.FEIF3;
               when Direct_Mode_Error_Indicated =>
                  return Unit.LISR.DMEIF3;
               when Transfer_Error_Indicated =>
                  return Unit.LISR.TEIF3;
               when Half_Transfer_Complete_Indicated =>
                  return Unit.LISR.HTIF3;
               when Transfer_Complete_Indicated =>
                  return Unit.LISR.TCIF3;
            end case;

         when Stream_4 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  return Unit.HISR.FEIF4;
               when Direct_Mode_Error_Indicated =>
                  return Unit.HISR.DMEIF4;
               when Transfer_Error_Indicated =>
                  return Unit.HISR.TEIF4;
               when Half_Transfer_Complete_Indicated =>
                  return Unit.HISR.HTIF4;
               when Transfer_Complete_Indicated =>
                  return Unit.HISR.TCIF4;
            end case;

         when Stream_5 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  return Unit.HISR.FEIF5;
               when Direct_Mode_Error_Indicated =>
                  return Unit.HISR.DMEIF5;
               when Transfer_Error_Indicated =>
                  return Unit.HISR.TEIF5;
               when Half_Transfer_Complete_Indicated =>
                  return Unit.HISR.HTIF5;
               when Transfer_Complete_Indicated =>
                  return Unit.HISR.TCIF5;
            end case;

         when Stream_6 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  return Unit.HISR.FEIF6;
               when Direct_Mode_Error_Indicated =>
                  return Unit.HISR.DMEIF6;
               when Transfer_Error_Indicated =>
                  return Unit.HISR.TEIF6;
               when Half_Transfer_Complete_Indicated =>
                  return Unit.HISR.HTIF6;
               when Transfer_Complete_Indicated =>
                  return Unit.HISR.TCIF6;
            end case;

         when Stream_7 =>
            case Flag is
               when FIFO_Error_Indicated =>
                  return Unit.HISR.FEIF7;
               when Direct_Mode_Error_Indicated =>
                  return Unit.HISR.DMEIF7;
               when Transfer_Error_Indicated =>
                  return Unit.HISR.TEIF7;
               when Half_Transfer_Complete_Indicated =>
                  return Unit.HISR.HTIF7;
               when Transfer_Complete_Indicated =>
                  return Unit.HISR.TCIF7;
            end case;
      end case;
   end Status;

   -----------------
   -- Set_Counter --
   -----------------

   procedure Set_NDT
     (Unit       : DMA_Controller;
      Stream     : DMA_Stream_Selector;
      Data_Count : Short)
   is
      This_Stream : DMA_Stream renames Get_Stream (Unit, Stream);
   begin
      This_Stream.SxNDTR.NDT := Data_Count;
   end Set_NDT;

   function Items_Transferred
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector)
      return Short
   is
      ndt : constant Unsigned_16 := Current_NDT (Unit, Stream);
      items : Unsigned_16;
   begin
      if Operating_Mode (Unit, Stream) = Peripheral_Flow_Control_Mode then
         items := 16#ffff# - ndt;
      else
         items := ndt;
      end if;
      return items;
   end Items_Transferred;

   function Current_NDT
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector)
      return Short
   is
      This_Stream : DMA_Stream renames Get_Stream (Unit, Stream);
   begin
      return This_Stream.SxNDTR.NDT;
   end Current_NDT;

   ---------------------
   -- Double_Buffered --
   ---------------------

   function Double_Buffered
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector)
      return Boolean
   is
   begin
      return Get_Stream (Unit, Stream).SxCR.DBM;
   end Double_Buffered;

   -------------------
   -- Circular_Mode --
   -------------------

   function Circular_Mode
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector)
      return Boolean
   is
   begin
      return Get_Stream (Unit, Stream).SxCR.CIRC;
   end Circular_Mode;

   ---------------
   -- Configure --
   ---------------

   procedure Configure
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector;
      Config : DMA_Stream_Configuration)
   is
      --  see HAL_DMA_Init in STM32F4xx_HAL_Driver\Inc\stm32f4xx_hal_dma.h
      This_Stream : DMA_Stream renames Get_Stream (Unit, Stream);
   begin
      --  the STMicro Reference Manual RM0090, Doc Id 018909 Rev 6, pg 319 says
      --  we must disable the stream before configuring it
      Disable (Unit, Stream);

      This_Stream.SxCR.CT  := -Memory_Buffer_0;
      This_Stream.SxCR.DBM := False;

      This_Stream.SxCR.CHSEL :=
        DMA_Channel_Selector'Enum_Rep (Config.Channel);
      This_Stream.SxCR.DIR :=
        DMA_Data_Transfer_Direction'Enum_Rep (Config.Direction);
      This_Stream.SxCR.PINC := Config.Increment_Peripheral_Address;
      This_Stream.SxCR.MINC := Config.Increment_Memory_Address;
      This_Stream.SxCR.PSIZE :=
        DMA_Data_Transfer_Widths'Enum_Rep (Config.Peripheral_Data_Format);
      This_Stream.SxCR.MSIZE :=
        DMA_Data_Transfer_Widths'Enum_Rep (Config.Memory_Data_Format);
      This_Stream.SxCR.PL :=
        DMA_Priority_Level'Enum_Rep (Config.Priority);

      case Config.Operation_Mode is
         when Normal_Mode =>
            This_Stream.SxCR.PFCTRL := False; --  DMA is the flow controller
            This_Stream.SxCR.CIRC   := False; --  Disable circular mode
         when Peripheral_Flow_Control_Mode =>
            This_Stream.SxCR.PFCTRL := True;  --  Peripheral is the flow ctrl.
            This_Stream.SxCR.CIRC   := False; --  Disable circular mode
         when Circular_Mode =>
            This_Stream.SxCR.PFCTRL := False; --  DMA is the flow controller
            This_Stream.SxCR.CIRC   := True;  --  Enable circular mode
      end case;

      --  the memory burst and peripheral burst values are only used when
      --  the FIFO is enabled
      if Config.FIFO_Enabled then
         This_Stream.SxCR.MBURST :=
           DMA_Memory_Burst'Enum_Rep (Config.Memory_Burst_Size);
         This_Stream.SxCR.PBURST :=
           DMA_Peripheral_Burst'Enum_Rep (Config.Peripheral_Burst_Size);
      else
         This_Stream.SxCR.MBURST := Memory_Burst_Single'Enum_Rep;
         This_Stream.SxCR.PBURST := Peripheral_Burst_Single'Enum_Rep;
      end if;

      --  DMDIS: disable the direct mode (set to True) when FIFO is enabled
      This_Stream.SxFCR.DMDIS := Config.FIFO_Enabled;

      if Config.FIFO_Enabled then
         This_Stream.SxFCR.FTH :=
           DMA_FIFO_Threshold_Level'Enum_Rep (Config.FIFO_Threshold);
      else
         This_Stream.SxFCR.FTH :=
           FIFO_Threshold_1_Quart_Full_Configuration'Enum_Rep; -- 0, default
      end if;
   end Configure;

   -----------
   -- Reset --
   -----------

   procedure Reset
     (Unit   : in out DMA_Controller;
      Stream : DMA_Stream_Selector)
   is
      This_Stream : DMA_Stream renames Get_Stream (Unit, Stream);
   begin
      Disable (Unit, Stream);

      This_Stream.SxCR := (others => <>);
      This_Stream.SxNDTR.NDT := 0;
      This_Stream.SxPAR := 0;
      This_Stream.SxM0AR := 0;
      This_Stream.SxM1AR := 0;
      This_Stream.SxFCR := (others => <>);

      Clear_All_Status (Unit, Stream);
   end Reset;

   ---------------------------
   -- Peripheral_Data_Width --
   ---------------------------

   function Peripheral_Data_Width
     (Unit : DMA_Controller;  Stream : DMA_Stream_Selector)
      return DMA_Data_Transfer_Widths
   is
   begin
      return DMA_Data_Transfer_Widths'Val
        (Get_Stream (Unit, Stream).SxCR.PSIZE);
   end Peripheral_Data_Width;

   -----------------------
   -- Memory_Data_Width --
   -----------------------

   function Memory_Data_Width
     (Unit : DMA_Controller;  Stream : DMA_Stream_Selector)
      return DMA_Data_Transfer_Widths
   is
   begin
      return DMA_Data_Transfer_Widths'Val
        (Get_Stream (Unit, Stream).SxCR.MSIZE);
   end Memory_Data_Width;

   ------------------------
   -- Transfer_Direction --
   ------------------------

   function Transfer_Direction
     (Unit : DMA_Controller;  Stream : DMA_Stream_Selector)
      return DMA_Data_Transfer_Direction
   is
   begin
      return DMA_Data_Transfer_Direction'Val
        (Get_Stream (Unit, Stream).SxCR.DIR);
   end Transfer_Direction;

   --------------------
   -- Operating_Mode --
   --------------------

   function Operating_Mode
     (Unit : DMA_Controller;  Stream : DMA_Stream_Selector)
      return DMA_Mode
   is
   begin
      if Get_Stream (Unit, Stream).SxCR.PFCTRL then
         return Peripheral_Flow_Control_Mode;
      elsif Get_Stream (Unit, Stream).SxCR.CIRC then
         return Circular_Mode;
      end if;
      return Normal_Mode;
   end Operating_Mode;

   --------------
   -- Priority --
   --------------

   function Priority
     (Unit : DMA_Controller;  Stream : DMA_Stream_Selector)
      return DMA_Priority_Level
   is
   begin
      return DMA_Priority_Level'Val (Get_Stream (Unit, Stream).SxCR.PL);
   end Priority;

   ---------------------------
   -- Current_Memory_Buffer --
   ---------------------------

   function Current_Memory_Buffer
     (Unit : DMA_Controller;  Stream : DMA_Stream_Selector)
      return Memory_Buffer_Target
   is
   begin
      return -Get_Stream (Unit, Stream).SxCR.CT;
   end Current_Memory_Buffer;

   -----------------------
   -- Set_Memory_Buffer --
   -----------------------

   procedure Set_Memory_Buffer
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector;
      Buffer : Memory_Buffer_Target;
      To     : System.Address)
   is
      function W is new Ada.Unchecked_Conversion
        (System.Address, Word);
      This_Stream : DMA_Stream renames Get_Stream (Unit, Stream);
   begin
      case Buffer is
         when Memory_Buffer_0 =>
            This_Stream.SxM0AR := W (To);
         when Memory_Buffer_1 =>
            This_Stream.SxM1AR := W (To);
      end case;
   end Set_Memory_Buffer;

   ----------------------------------
   -- Select_Current_Memory_Buffer --
   ----------------------------------

   procedure Select_Current_Memory_Buffer
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector;
      Buffer : Memory_Buffer_Target)
   is
   begin
      Get_Stream (Unit, Stream).SxCR.CT := -Buffer;
   end Select_Current_Memory_Buffer;

   ------------------------------------
   -- Configure_Double_Buffered_Mode --
   ------------------------------------

   procedure Configure_Double_Buffered_Mode
     (Unit              : DMA_Controller;
      Stream            : DMA_Stream_Selector;
      Buffer_0_Value    : Address;
      Buffer_1_Value    : Address;
      First_Buffer_Used : Memory_Buffer_Target)
   is
   begin
      Set_Memory_Buffer (Unit, Stream, Memory_Buffer_0, Buffer_0_Value);
      Set_Memory_Buffer (Unit, Stream, Memory_Buffer_1, Buffer_1_Value);
      Select_Current_Memory_Buffer (Unit, Stream, First_Buffer_Used);
   end Configure_Double_Buffered_Mode;

   ---------------------------------
   -- Enable_Double_Buffered_Mode --
   ---------------------------------

   procedure Enable_Double_Buffered_Mode
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector)
   is
   begin
      Get_Stream (Unit, Stream).SxCR.DBM := True;
   end Enable_Double_Buffered_Mode;

   ----------------------------------
   -- Disable_Double_Buffered_Mode --
   ----------------------------------

   procedure Disable_Double_Buffered_Mode
     (Unit   : DMA_Controller;
      Stream : DMA_Stream_Selector)
   is
   begin
      Get_Stream (Unit, Stream).SxCR.DBM := False;
   end Disable_Double_Buffered_Mode;

   ----------------------
   -- Selected_Channel --
   ----------------------

   function Selected_Channel
     (Unit : DMA_Controller;  Stream : DMA_Stream_Selector)
      return DMA_Channel_Selector
   is
   begin
      return DMA_Channel_Selector'Val (Get_Stream (Unit, Stream).SxCR.CHSEL);
   end Selected_Channel;

   -------------
   -- Aligned --
   -------------

   function Aligned (This : Address;  Width : DMA_Data_Transfer_Widths)
      return Boolean
   is
      use System.Storage_Elements;
   begin
      case Width is
         when Words =>
            return To_Integer (This) mod 4 = 0;
         when HalfWords =>
            return To_Integer (This) mod 2 = 0;
         when Bytes =>
            return True;
      end case;
   end Aligned;

end STM32.DMA;