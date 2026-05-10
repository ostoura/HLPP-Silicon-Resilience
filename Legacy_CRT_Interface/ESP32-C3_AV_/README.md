# ESP32-C3 Bare-Metal AV Solution (Under Development)

## 1. Project Overview
This module implements a **NTSC/PAL Composite Video (CVBS) generator** using the **RISC-V ESP32-C3** microcontroller. It is designed to demonstrate how legacy CRT hardware can be repurposed as functional IoT dashboards or diagnostic terminals using high-efficiency, bare-metal assembly.

## 2. Technical Strategy
The solution relies on cycle-accurate RISC-V assembly to generate the precise timing required for analog video signals.
*   **Architecture:** 100% RISC-V Assembly (`.s`) for raw signal control.
*   **Target Clock:** 160MHz (Internal PLL) for sub-microsecond timing precision.
*   **DAC Implementation:** 2-bit passive resistor ladder to achieve standard CVBS voltage levels (0V Sync, 0.3V Black, 1.0V White).
*   **Resolution:** Optimized for "Low-Footprint" display modes (e.g., 40x304) to maximize SRAM efficiency.

---

## 3. Current Development Status
> **[STATUS: ALPHA / EXPERIMENTAL]**  
> This code is currently part of a deep-technical audit to stabilize timing loops on the RISC-V architecture.

### ✅ Completed
*   GPIO and IO_MUX configuration via bare-metal register writes.
*   Hardware-level DAC interface design.
*   Signal level verification for PAL/NTSC standards.

### 🛠️ Ongoing Challenges (Active Debugging)
*   **System Hang Investigation:** Currently resolving a loop-exit issue involving the `mcycle` CSR and stack pointer (`sp`) alignment.
*   **Watchdog Management:** Implementing "Keep-Alive" routines within the assembly loop to prevent system resets during long frame draws.
*   **RISC-V Extension Optimization:** Verification of the `Zicsr` extension support in minimalist boot environments.

---

## 4. Hardware Interface
To connect the ESP32-C3 to an RCA/Composite input, the following passive DAC circuit is utilized:

*   **Signal High (White):** GPIO X -> 2.35kΩ Resistor -> RCA Tip
*   **Signal Low (Gray/Black):** GPIO Y -> 10kΩ Resistor -> RCA Tip
*   **Impedance Matching:** 1kΩ Resistor from RCA Tip to GND (to maintain 75Ω-standard behavior).

---

## 5. Licensing & Mission
This folder is released under the **GNU General Public License v3.0 (GPLv3)**. It serves as a practical implementation component of the **HLPP (Hardware-Level Persistence Protocol)** initiative, proving that even the newest silicon can be made compatible with the "Silicon Immortality" philosophy.
