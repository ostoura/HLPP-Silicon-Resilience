# Actions ATM7021 Implementation

This folder contains the implementation for the Actions Semiconductor ATM7021 SoC, tested on the **Zentality C701** tablet.

### Technical Details:
- **Execution Mode:** Physical Mode execution.
- **Boot Strategy:** Code is loaded into SRAM and executed in a dedicated "Utility Partition" environment.
- **Memory Management:** Operates without MMU initialization for maximum power efficiency and speed.
- **Resilience:** Specifically designed for the "Actions Logo Loop" failure, providing a stable utility state when the Android system fails to initialize.

### Instructions:
1. Download `clock_TM.img` from the Releases section.
2. Flash to SD card using the `dd` command.
3. Power on the device. The protocol will intercept the boot sequence and load the clock assets into the internal RAM.
