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
------------------------------------------------------------------------------

package body STM32.Board is

   ------------------
   -- All_LEDs_Off --
   ------------------

   procedure All_LEDs_Off is
   begin
      Set (All_LEDs);
   end All_LEDs_Off;

   -----------------
   -- All_LEDs_On --
   -----------------

   procedure All_LEDs_On is
   begin
      Clear (All_LEDs);
   end All_LEDs_On;

   ---------------------
   -- Initialize_LEDs --
   ---------------------

   procedure Initialize_LEDs is
      Conf : GPIO_Port_Configuration;
   begin
      Enable_Clock (All_LEDs);

      Conf.Mode        := Mode_Out;
      Conf.Output_Type := Push_Pull;
      Conf.Speed       := Speed_100MHz;
      Conf.Resistors   := Floating;

      Configure_IO (All_LEDs, Conf);
      All_LEDs_Off;
   end Initialize_LEDs;

   --------------------------------
   -- Configure_User_Button_GPIO --
   --------------------------------

   procedure Configure_User_Button_GPIO is
      Config : GPIO_Port_Configuration;
   begin
      Enable_Clock (User_Button_Point);

      Config.Mode := Mode_In;
      Config.Resistors := Floating;

      Configure_IO (User_Button_Point, Config);
   end Configure_User_Button_GPIO;

   ------------------------------
   -- Configure_SD_Device_GPIO --
   ------------------------------

   procedure Configure_SD_Device_GPIO
   is
      SD_Pins           : constant STM32.GPIO.GPIO_Points :=
                            (PC8, PC9, PC10, PC11, PC12, PD2);
      SD_DMA_Rx_Channel : constant DMA_Channel_Selector :=
                            Channel_4;
      SD_DMA_Tx_Channel : constant DMA_Channel_Selector :=
                            Channel_4;

   begin
      --  Enable the SDIO clock
      Enable_Clock (SD_Device);
      Reset (SD_Device);

      --  Enable the DMA2 clock
      Enable_Clock (SD_DMA);

      --  Enable the GPIOs
      Enable_Clock (SD_Pins & SD_Detect_Pin);

      --  GPIO configuration for the SDIO pins
      Configure_IO
        (SD_Pins,
         (Mode        => Mode_AF,
          Output_Type => Push_Pull,
          Speed       => Speed_High,
          Resistors   => Pull_Up));
      Configure_Alternate_Function (SD_Pins, GPIO_AF_12_SDMMC1);

      --  GPIO configuration for the SD-Detect pin
      Configure_IO
        (SD_Detect_Pin,
         (Mode        => Mode_In,
          Output_Type => Open_Drain,
          Speed       => Speed_High,
          Resistors   => Pull_Up));

      Disable (SD_DMA, SD_DMA_Rx_Stream);
      Configure
        (SD_DMA,
         SD_DMA_Rx_Stream,
         (Channel                      => SD_DMA_Rx_Channel,
          Direction                    => Peripheral_To_Memory,
          Increment_Peripheral_Address => False,
          Increment_Memory_Address     => True,
          Peripheral_Data_Format       => Words,
          Memory_Data_Format           => Words,
          Operation_Mode               => Peripheral_Flow_Control_Mode,
          Priority                     => Priority_Very_High,
          FIFO_Enabled                 => True,
          FIFO_Threshold               => FIFO_Threshold_Full_Configuration,
          Memory_Burst_Size            => Memory_Burst_Inc4,
          Peripheral_Burst_Size        => Peripheral_Burst_Inc4));
      Clear_All_Status (SD_DMA, SD_DMA_Rx_Stream);

      Disable (SD_DMA, SD_DMA_Tx_Stream);
      Configure
        (SD_DMA,
         SD_DMA_Tx_Stream,
         (Channel                      => SD_DMA_Tx_Channel,
          Direction                    => Memory_To_Peripheral,
          Increment_Peripheral_Address => False,
          Increment_Memory_Address     => True,
          Peripheral_Data_Format       => Words,
          Memory_Data_Format           => Words,
          Operation_Mode               => Peripheral_Flow_Control_Mode,
          Priority                     => Priority_Very_High,
          FIFO_Enabled                 => True,
          FIFO_Threshold               => FIFO_Threshold_Full_Configuration,
          Memory_Burst_Size            => Memory_Burst_Inc4,
          Peripheral_Burst_Size        => Peripheral_Burst_Inc4));
      Clear_All_Status (SD_DMA, SD_DMA_Tx_Stream);
   end Configure_SD_Device_GPIO;

end STM32.Board;
