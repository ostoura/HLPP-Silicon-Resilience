# Allwinner A13 (Cortex-A8) Implementation

This folder contains the implementation for the Allwinner A13 SoC, tested on the **iTechie iT708** tablet.

### Technical Details:
- **Execution Mode:** Bare-metal execution from SRAM.
- **Boot Strategy:** Utilizes the Allwinner FEL mode and SDMMC boot priority. 
- **Hardware Integration:** Direct register access to the A13 Display Controller and PMU.
- **Resilience:** Successfully bypasses the signature check on failed NAND blocks to initialize the clock utility.

### Instructions:
1. Download `clock_A13.img` from the Releases section.
2. Flash to SD card using the `dd` command provided in the main README.
3. Insert SD card and power on. If NAND is failed, the SoC will default to the SDMMC bootloader and trigger the HLPP clock.
