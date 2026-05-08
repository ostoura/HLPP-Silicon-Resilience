# Legacy CRT Interface (Parallel Port Proof-of-Concept)

This project demonstrates the "Universal" nature of the HLPP protocol. By bit-banging an IEEE 1284 Parallel Port using a hand-soldered R-2R Resistor Ladder, I successfully generated a composite video signal to run a functional clock on a vintage 5" B/W CRT television.

### Hardware-Level Details:
- **Interface:** Parallel Port (LPT) 3.3V Logic.
- **Signal Generation:** R-2R Resistor Ladder for Composite Sync/Video.
- **Resolution:** 40 x 304 (Limited by LPT bus clock).
- **Architecture:** x86 Legacy support.

<div align="center">
  <a href="https://www.youtube.com/watch?v=NK5V5Bh_uik">
    <img src="https://img.youtube.com/vi/NK5V5Bh_uik/maxresdefault.jpg" alt="Vintage TV Clock Demo" width="400">
    <p><b>🎥 Watch: Rescuing a 1980s CRT with Modern Logic</b></p>
  </a>
</div>

<div align="center">
  <a href="https://www.youtube.com/watch?v=hc7ue-cmpGg">
    <img src="https://img.youtube.com/vi/hc7ue-cmpGg/maxresdefault.jpg" alt="Vintage TV Clock Demo" width="400">
    <img src="https://img.youtube.com/vi/hc7ue-cmpGg/2.jpg" alt="Parallel Port To Composite A/V" width="300">
    <p><b>🎥 Watch: Rescuing a 1980s CRT with Modern Logic</b></p>
  </a>
</div>

*Note: This proof-of-concept is currently being ported to RISC-V (ESP32) for high-resolution deployment.*
