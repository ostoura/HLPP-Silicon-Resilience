# Ventage_TV_Analog_Clock
This Project I try to add new life for an old 5.5 inch B/W TV by turning it into a Desktop Analog And Digital Clock

Initial proof-of-concept achieved via an 8-bit R-2R Resistor Ladder on an IEEE 1284 Parallel Port. By calculating the voltage offsets for Sync (0V), Black (0.3V), and White (0.7V-1.0V) within the hardware's 3.3V logic constraints, I successfully generated a composite signal for CRT display. This logic is now being ported to RISC-V (ESP32) for high-resolution deployment.

Here i do the HLPP but this time on a Ventage TV So It Is fun to try this analog devices with a PC as a start
what i did so far is i made a simple connection on Parallel port of my old PC to the Audio video composite input for this 5 inch tv 
i realize i need a resistor ladder to get 2 exact voltages 0.3 for black and 0.7 - 1.0 for white so a voltage devider would be good but remember to check the parallel port voltage if its 5v or 3.3v as in my case before making the ladder calculations and to know if your TV has 75 ohm internal or not cause you may need to put a resistor to the ground if your TV does not have it (also my case) 
anyway here is the results so far For A 40 x304 Pixels 

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
