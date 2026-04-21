# Rockchip RK2926 (Cortex-A9) Implementation

This folder contains the implementation for the Rockchip RK2926 SoC, tested on the **TouchMate TM-MD710** tablet.

### Technical Details:
- **Execution Mode:** Bootloader-level injection.
- **Boot Strategy:** Custom code injected into the primary bootloader to hijack the boot sequence before the Kernel mount attempt.
- **Sensor Integration:** Includes bare-metal **I2C/Gyroscope** support, allowing for gesture-based time setting.
- **Resilience:** Operates effectively even in cases of total NAND corruption where the device appears "dead" to standard recovery tools.

### Instructions:
1. Download `clock_TM.img` from the Releases section.
2. Flash to SD card using the `dd` command.
3. Insert SD card. This tablet may require a "Power + Volume" combination to trigger the bootloader injection if the MaskROM is not automatically defaulting to SD.
