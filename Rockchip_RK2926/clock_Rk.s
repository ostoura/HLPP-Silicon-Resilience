.arch armv7-a          @ Specify the ARMv7-A architecture
.fpu neon              @ Enable both NEON and VFPv3 instructions for FPU Functions
.syntax unified        @ Use modern Unified Assembly Language (UAL)

.equ Injection_Start,           0x148B100           // Where you should inject the codes on file
.equ RAM_Injection_Start,       0xC048F100          // if you have Strings you need to add this number to its location
.equ LCD_BASE,                  0xC0000800          // This is the base of the LCD FrameBuffer Data
                                                    // +04 = VA Framebase Address 0xE1000000
                                                    // +08 = PA Framebase Address 0x7A400000
                                                    // +0C = Framebase length in bytes 0xC00000 Should Be 0xBB800
.equ Temp_Data,                 0xB0000000          // Use it for test and get values from kernel
.equ Data_BASE,                 0xC0000810          // This is the base of the Read/Write Data Section
.equ SRAM_BASE,                 0x10080000          // SRAM is 16kb only
.equ Get_Time,                  0xC0774E7C          //inputs: r0: 0xD9066A00 RTC_Device_Driver r1: 0xD903DEC0 Time_Structure
.equ Set_Time,                  0xC0774BEC          //inputs: r0: 0xD9066A00 RTC_Device_Driver r1: 0xD903DEC0 Time_Structure
.equ RTC_Device_Driver,         0xD9066A00
.equ Time_Structure,            0xD903DEC0
.equ CPU_Clock,                 0xC0AFC8A8          // to check if the Heart Of The SOC is Beating
.equ Battery_Device_Structure,  0xD9007800          // hold All Battery Informations
.equ Battery_Voltage_mV,        Battery_Device_Structure + 0x110          // +0x110 => Voltage in mV
.equ Battery_Percentage,        Battery_Device_Structure + 0x114          // +0x114 => Percentage % 0x0 - 0x64
.equ Battery_Charging_State,    Battery_Device_Structure + 0x11C          // +0x11C => 00:not connected to charger, 01:Connected
.equ TTBR0,                     0xC0404000          // Address Where TTBR0 Remap Table Is (remap table)
.equ LCD_FB_PA,                 0x7A400000          // VA = 0xE1000000
.equ LCD_FB_VA,                 0xE1000000          // PA = 0x7A400000
.equ cursor_x,                  0xC0000600 + 0x100
.equ cursor_y,                  0xC0000600 + 0x104
.equ PWM0_BASE,                 0x20050000          // Backlight
.equ PWM0_CNTR,                 0x0000              // Counter (Read Only)
.equ PWM0_HRC,                  0x0004              // PWM0_Duty Set to 0x0:Full, 0x9196:Default, 0xC196:Dimmed, 0x1220A:Off
.equ PWM0_LRC,                  0x0008              // PWM0_Period Default = 0x1220A
.equ PWM0_CTRL,                 0x000C              // Control Default = 0x9 bit[0] 1:Timer Enable, bit[3] 1:out Enable
                                                    // bit[4] = 0 repeating, bits[9-12] Prescale factor 0000: 1/2
.equ Gyroscope_Control,         0x20056200          // Accelerometer bits[0-11]
                                                    // Yaw bits[16-19] 0b1111: Horizontal  0b1010: Tilt Right 0b0000: Tilt Left
                                                    // Roll bit[20] 0:LCD 90º Facing you 1:LCD Facing up
.equ Power_Button,              0x20080050          // Power Button bit[4] 0b1:Released 0b0:Pressed
.equ SARADC_BASE,               0x2006C000          // SARADC_Base Address has 4 Channels
.equ SARADC_DATA,               0x0000              // Data bits[0-9] Read Only
.equ SARADC_STAS,               0x0004              // Status bit[0] Read Only 0: ADC stop, 1: Conversion in progress
.equ SARADC_CTRL,               0x0008              // bits[0-2] Input Source Selection(CH_SEL[2:0]).
                                                    //  111 : Input source 0 (SARADC_AIN[0])
                                                    //  110 : Input source 1 (SARADC_AIN[1])
                                                    //  101 : Input source 2 (SARADC_AIN[2])
                                                    //  100 : Input source 3 (SARADC_AIN[3])
                                                    // bit[3] Power Down Control Bit
                                                    //  0: ADC power down;
                                                    //  1: ADC power up and reset.
                                                    // bit[5] Interrupt Enable
                                                    //  0: Disable
                                                    //  1: Enable
                                                    // bit[5] Interrupt Status
                                                    //  This bit will be set to 1 when end-of-conversion.
                                                    //  Set 0 to clear the interrupt.
.equ SARADC_DLY_PU_SOC,         0x000C              // (Default 0x8) bits[0-5] Delay between Power up and Start Command
                                                    
                                                    // -----------------------------------------------------------------
                                                    //  Steps to Use SARADC:
                                                    //  - Power-down A/D Converter in SARADC_CTRL[3]
                                                    //  - Power-up A/D Converter in SARADC_CTRL[3] and select input channel
                                                    //          of A/D Converter in SARADC_CTRL[2:0] bit
                                                    //  - Wait an A/D interrupt or poll the SARADC_STAS register to determine
                                                    //          when the conversion is completed
                                                    //  - Read the conversion result in the SARADC_DATA register
                                                    //          input clock period of SAR-ADC , it must be minimum 1000ns .
                                                    // -----------------------------------------------------------------

.equ GIC_Base,                  0x1013C000          // Address Where GIC is (General Interrupt Controller)

 .text
 .global _start
 .align 2
 _start:
 
    @=============================================================================================
    @
    @ Steps Needed If You Dont Have sdstart.img or sdmaster.img
    @ 1- patch the FlashBoot then scrumble it and return it inside the firmware after patching
    @ 2- inject the Framebuffer Extractor At 0x16B0880-0x16B08B8
    @       (frame buffer at r1-r4 and we store it at 0xC0000800-0xC000080C)
    @ 3- inject the Far jumper At 0x1405440 (Far Jump  is jumping to 0xC048F100 aka 0x148B100 on file)
    @ 4- Inject This code in sdstart.img At 0x148B100
    @ If you have the sdstart.img you would skip steps 1 to 3 and only apply step 4
    @
    @=============================================================================================

 
    @=============================================================================================
    @ 2. Unlock VFP/NEON (Very Important if you Wanna Use FPU, And NEON Or it would Crash)
    @ this would work in Previlage mode only (Bare Metal SD-Card Boot or FEL) Or Else you Should
    @ Set the Cpu Mode TO Supervisor or System Manually
    @=============================================================================================
    mrc             p15, 0, r0, c1, c0, 2
    orr             r0, r0, #(0xf << 20)
    mcr             p15, 0, r0, c1, c0, 2
    isb
    mov             r0, #0x40000000
    vmsr            fpexc, r0


    // ------- Reset SOC Registers VA:PA 1:1 ------------------
    bl      Force_Identity_Map_Registers        // this line return the SOC registers to its Physical Addresss 1:1 VA:PA
    // --------------------------------------------------------

    // ---------------- turn LCD Black ------------------------
    bl      blackout                            // do cover the Splash with a black screen
    // --------------------------------------------------------

    ldr     r2, =X0
    ldr     r3, =Y0
    ldr     r0, =radius
    
    mov     r1, #400
    str     r1, [r2]            // X0 = 400
    mov     r1, #240
    str     r1, [r3]            // Y0 = 240
    mov     r1, #240
    str     r1, [r0]            // radius = 240

    mov     r2, #400            // r0 = X0
    mov     r3, #240            // r1 = Y0
    mov     r0, #240            // r2 = radius
    ldr     r4, =COLOR_TURQUOISE
    //bl      draw_pie_a

    // Create the dots around the clock
    ldr     r2, = ddStore
    mov     r3, #0              // n starts from 0
    str     r3, [r2]            // n = 0
        
    ldr     r2, = radius
    mov     r3, #220            //dword [radius], 220
    str     r3, [r2]            // radius = 240

    mov     r0, #60             //number of dots
    ldr     r4, =dotsColor
    bl      createDotsCircle
    
    
    // Clear Index
    mov     r0, #0
    ldr     r7, =index
    str     r0, [r7]                        // clean index

    // Clear cursors
    mov     r0, #20
    ldr     r7, =cursor_x
    str     r0, [r7]                        // reset cursors
    mov     r0, #7
    ldr     r7, =cursor_y
    str     r0, [r7]                        // reset cursors

    mov     r0, #0x9                        // From 0x0 - 0xF inverted
    bl      BCK_L_CTRL                      // Set Backlight to 50%
 
 /*
 rtre:
    ldr     r0, =Gyroscope_Control
    ldr     r0, [r0]
    bl      printBin
    b       rtre
*/

again:
    bl      Battery_Read            // External Located At lcd.inc
    bl      printBattery

    bl      checkButtons

    bl      get_time

    b       again

    b       end
    
end:
    b       end
    
//----------------------------------------------------------------
// get_time
// input:
//----------------------------------------------------------------
get_time:
    push    {r0-r10,lr}
        
    bl      RTC_Read                        // Get Time And Day
                                            //  r0: Time & Week
                                            //      bits[0-5] Second
                                            //      bits[8-13] Minute
                                            //      bits[16-20] Hour
                                            //      bits[29-31] Week Day
                                            //  r1: Day
                                            //      bits[0-4] Day
                                            //      bits[8-11] Month
                                            //      bits[16-23] Year
                                            //      bit[31] Leap Year Bit 0:365 Days 1: 366 Days
                                            // for  test : Monday 11:54:17  => ldr     r0, =0x000B3611
    
    // check if second have changed or same
    and     r3, r0, #0x3F                   // get seconds
    ldr     r5, =prev_S                     // get last seconds
    ldr     r5, [r5]
    cmp     r3, r5
    beq     .timerEnd
            
    // Set AM/PM
    lsr     r3, r0, #16
    and     r3, r3, #0x3F                   // r3 = hours
    cmp     r3, #12
    ldr     r2, =ampm
    movlo   r3, #'A'
    movhs   r3, #'P'
    str     r3, [r2]
    
    // Set Time As 12h not 24
    lsr     r3, r0, #16
    and     r3, r3, #0x3F                   // r3 = hours
    cmp     r3, #0
    moveq   r3, 12
    beq     .continuetime
    cmp     r3, 12
    subhi   r3, 12

.continuetime:
    ldr     r5, =HEX_H                      // Save  hours (after readjust 24h to 12h)
    str     r3, [r5]
    
    and     r3, r0, #0x3F                   // get seconds
    ldr     r5, =HEX_S
    str     r3, [r5]
    ldr     r5, =prev_S                     // save prev sec
    str     r3, [r5]
    
    lsr     r3, r0, #8                      // get minutes
    and     r3, r3, #0x3F
    ldr     r5, =HEX_M
    str     r3, [r5]
    
    lsr     r3, r0, #29                     // get weeks
    and     r3, r3, #0x7
    ldr     r5, =HEX_W
    str     r3, [r5]
    
    and     r3, r1, #0x1F                   // get days
    ldr     r5, =HEX_D
    str     r3, [r5]
    
    lsr     r3, r1, #8                      // get months
    and     r3, r3, #0xF
    ldr     r5, =HEX_N
    str     r3, [r5]
    
    lsr     r3, r1, #16                      // get years
    and     r3, r3, #0xFF
    ldr     r5, =HEX_Y
    str     r3, [r5]
    
    lsr     r3, r1, #31                     // get leap year status
    and     r3, r3, #0x1
    ldr     r5, =HEX_L
    str     r3, [r5]

    // Digital Clock Starts preperation Here
    ldr     r0, =HEX_H
    ldr     r0, [r0]
    bl      Dec2UTF32
    ldr     r2, =outputDec
    ldr     r0, [r2, #0x24]                //<<<<
    ldr     r3, =currentH0
    str     r0, [r3]                     // 00H0
    ldr     r0, [r2, #0x28]                //<<<<
    ldr     r3, =currentH1
    str     r0, [r3]                     // 00H1
    
    ldr     r0, =HEX_M
    ldr     r0, [r0]
    bl      Dec2UTF32
    ldr     r2, =outputDec
    ldr     r0, [r2, #0x24]                //<<<<
    ldr     r3, =currentM0
    str     r0, [r3]                     // 00M0
    ldr     r0, [r2, #0x28]                //<<<<
    ldr     r3, =currentM1
    str     r0, [r3]                     // 00M1
    
    ldr     r0, =HEX_S
    ldr     r0, [r0]
    bl      Dec2UTF32
    ldr     r2, =outputDec
    ldr     r0, [r2, #0x24]                //<<<<
    ldr     r3, =currentS0
    str     r0, [r3]                     // 00S0
    ldr     r0, [r2, #0x28]                //<<<<
    ldr     r3, =currentS1
    str     r0, [r3]                     // 00S1

    ldr     r0, =HEX_W
    ldr     r0, [r0]
    bl      Dec2WeekDay
    ldr     r3, =currentW0
    str     r0, [r3]                     // 00W0
    ldr     r3, =currentW1
    str     r1, [r3]                     // 00W1
    
    ldr     r0, =HEX_D
    ldr     r0, [r0]
    bl      Dec2UTF32
    ldr     r2, =outputDec
    ldr     r0, [r2, #0x24]                //<<<<
    ldr     r3, =currentD0
    str     r0, [r3]                     // 00D0
    ldr     r0, [r2, #0x28]                //<<<<
    ldr     r3, =currentD1
    str     r0, [r3]                     // 00D1

    ldr     r0, =HEX_N
    ldr     r0, [r0]
    bl      Dec2UTF32
    ldr     r2, =outputDec
    ldr     r0, [r2, #0x24]                //<<<<
    ldr     r3, =currentN0
    str     r0, [r3]                     // 00N0   Month Number
    ldr     r0, [r2, #0x28]                //<<<<
    ldr     r3, =currentN1
    str     r0, [r3]                     // 00N1

    ldr     r0, =HEX_N
    ldr     r0, [r0]
    bl      Dec2Month
    ldr     r3, =currentT0
    str     r0, [r3]                     // 00T0   Month Title
    ldr     r3, =currentT1
    str     r1, [r3]                     // 00T1
    ldr     r3, =currentT2
    str     r2, [r3]                     // 00T1


    mov     r0, #20
    bl      Dec2UTF32
    ldr     r2, =outputDec
    ldr     r0, [r2, #0x24]                //<<<<
    ldr     r3, =currentY0
    str     r0, [r3]                     // 00Y2
    ldr     r0, [r2, #0x28]                //<<<<
    ldr     r3, =currentY1
    str     r0, [r3]                     // 00Y2

    ldr     r0, =HEX_Y
    ldr     r0, [r0]
    bl      Dec2UTF32
    ldr     r2, =outputDec
    ldr     r0, [r2, #0x24]                 //<<<<
    ldr     r3, =currentY2
    str     r0, [r3]                        // 00Y2
    ldr     r0, [r2, #0x28]                 //<<<<
    ldr     r3, =currentY3
    str     r0, [r3]                        // 00Y3


    //)))))))))))))))))))))))))))))))))))))
    // Start The Digital Clock 7 Segment
    //)))))))))))))))))))))))))))))))))))))
    mov     r2, #240                        // Starting x position
    mov     r3, #350                        // Starting y position
    ldr     r4, =digiClockColor             // color
    mov     r5, #1                          // Size Div Medium
    ldr     r6, =editColor                  // r6 = editing color
    ldr     r7, =index
    ldr     r7, [r7]                        // r6 = index
    mov     r8, #64                         // Space between characters
    lsr     r8, r8, r5                      // Adjust space accordingly
    
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =currentH0
    cmp     r7, #3
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor
    ldr     r0, [r0]                        // digit
    bl      write_digit
    
    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =currentH1
    cmp     r7, #3
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    mov     r0, #':'
    ldr     r4, =digiClockColor
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                           // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentM0
    cmp     r7, #2
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentM1
    cmp     r7, #2
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    mov     r0, #':'
    ldr     r4, =digiClockColor
    bl      write_digit

    add     r2, r8                         // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentS0
    cmp     r7, #1
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r8                         // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentS1
    cmp     r7, #1
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r8                         // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentW0
    cmp     r7, #4
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r8                         // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentW1
    cmp     r7, #4
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor
    ldr     r0, [r0]                        // digit
    bl      write_digit

    ldr     r0, =monthMode
    ldr     r0, [r0]
    //and     r0, r0, #0xF
    cmp     r0, #0                          // 0: Text Months 1: Numeric Months
    bne     .numericM

// ---- Text Month Mode ----
    mov     r2, #300                        // Starting x position
    mov     r3, #410                       // Starting y position
    mov     r5, #2                         // Size Div Small
    mov     r8, #80
    lsr     r8, r8, r5                     // Adjust spaces for new line
    
    mov     r0, #0                           // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentT0
    cmp     r7, #6
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentT1
    cmp     r7, #6
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentT2
    cmp     r7, #6
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =currentD0
    cmp     r7, #5
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit
    
    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =currentD1
    cmp     r7, #5
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8
    mov     r0, #0                           // code for clear 7 segment
    bl      write_digit
    mov     r0, #','
    ldr     r4, =digiClockColor2
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                           // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentY0
    cmp     r7, #7
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentY1
    cmp     r7, #7
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentY2
    cmp     r7, #7
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentY3
    cmp     r7, #7
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    b       .analogStart
//------ Numeric Months -----
.numericM:
    mov     r2, #300                        // Starting x position
    mov     r3, #410                       // Starting y position
    mov     r5, #2                         // Size Div Small
    mov     r8, #80
    lsr     r8, r8, r5                     // Adjust spaces for new line
    
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =currentD0
    cmp     r7, #5
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit
    
    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =currentD1
    cmp     r7, #5
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    mov     r0, #'/'
    ldr     r4, =digiClockColor2
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                           // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentN0
    cmp     r7, #6
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentN1
    cmp     r7, #6
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    mov     r0, #'/'
    ldr     r4, =digiClockColor2
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                           // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentY0
    cmp     r7, #7
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentY1
    cmp     r7, #7
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentY2
    cmp     r7, #7
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =currentY3
    cmp     r7, #7
    ldreq   r4, =editColor
    ldrne   r4, =digiClockColor2
    ldr     r0, [r0]                        // digit
    bl      write_digit

    //)))))))))))))))))))))))))))))))))))))
    // Start The Analog Clock
    //)))))))))))))))))))))))))))))))))))))
.analogStart:

    // notice i intentionally makes the hands up side down cause
    // i wanted the long hands not to cover the short ones since i have not added thikness to the lines
    // so i put the seconds hands on the lower layer then the min then the hours on the upper
    // while in the normal clocks it is the other way
    
    bl makingHoursHand

    bl makingMinutesHand

    bl makingSecondsHand


    //)))))))))))))))))))))))))))))))))))))
    // Start AM/PM & Pin
    //)))))))))))))))))))))))))))))))))))))

    // draw_am_pm
    mov     r2, #364
    mov     r3, #50
    mov     r5, #1
    mov     r8, #64
    lsr     r8, r8, r5
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =ampm
    ldr     r0, [r0]                        // digit
    cmp     r0, #'P'
    ldreq   r4, =pmColor
    ldrne   r4, =amColor
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    mov     r0, #'M'
    bl      write_digit


   // draw the center pin that holds the clock hands (Decoration)
    ldr     r2, =X0
    ldr     r2, [r2]            // r0 = X0
    ldr     r3, =Y0
    ldr     r3, [r3]            // r1 = Y0
    ldr     r5, =radius
    mov     r0, #12             // !!!!! TODO - when change this to less than 12 it hangs while it work in draw_pie_a
                                // check draw_pie_b for less than #12 radius or for small radius !!!!
    str     r0, [r5]            // radius = 240
    ldr     r5, [r5]            // r2 = radius
    ldr     r4, =COLOR_PINK
    bl      draw_pie_a

.timerEnd:
    pop     {r0-r10,pc}
    .ltorg


//-------------------------------------
//
//Making Hours Hand
//
//-------------------------------------
makingHoursHand:
    push    {r0-r10,lr}

    ldr     r0, =HEX_H
    ldr     r0, [r0]
    ldr     r1, =prevHEX_H
    ldr     r1, [r1]
    cmp     r0, r1
    beq     .skipClearH

    // Clear old Hours Hand
    //[X0] Xcenter
    //[Y0] Yccenter
    ldr     r2, =prevDistHorX
    ldr     r2, [r2]
    cmp     r2, #0
    beq     .skipClearH
    ldr     r3, =prevDistHorY
    ldr     r3, [r3]
    cmp     r3, #0
    beq     .skipClearH
    ldr     r6, =X1
    str     r2, [r6]
    ldr     r7, =Y1
    str     r3, [r7]
    ldr     r4, =backgroundColor
    mov     r5, #0       // thikness as dot 1-3-1
    bl      draw_line_a

 .skipClearH:
    
    //Adjust Hours Number to Location
    ldr     r0, =HEX_H
    ldr     r0, [r0]
    mov     r1, #5                      // every 1 hour reflect 5 min on Clock location
    mul     r0, r1, r0
    // at this point hours hand is stick at the hour number
    // even if the min hand changes
    // next we add the effect of the min Hand
    ldr     r1, =HEX_M
    ldr     r1, [r1]                    // Load the Min Number into r0
    
    ldr     r9, =0xAAAAAAAB             @ Load the magic number for dividing by 12 (unsigned)
    umull   r8, r9, r9, r1              @ Perform 32x32 -> 64-bit multiply: (R1 * R9).
                                        @ Lower 32 bits in R8, upper 32 bits in R9
    mov     r1, r9, lsr #3              @ The result is the upper 32 bits (R9) logically shifted right by 3 bits
                                        // 60 min / 12 hours every 12 min the hour hand mov 1 tick
                                        // r1 / 12
    add r0, r0, r1                      // add the min effect to the hour count
        
    ldr     r1, =HEX_H
    str     r0, [r1]
    ldr     r1, =prevHEX_H
    str     r0, [r1]    // save HEX_S to prevHEX_S

    // Load Hour Hand Distination Point X , Y
    // Y = (r * sin((n+45) * 6 * (pi/180)) + YCenter  rounded to integers
    // X = (r * cos((n+45) * 6 * (pi/180)) + XCenter  rounded to integers
    
    add     r0, r0, #45          // Adjust n rotation 45º more
    cmp     r0, #60
    blt     .continueH          // make sure the result less than 60
    sub     r0, r0, 60          // else subtract 60 from result and it would be like back to zero

 .continueH:
    ldr     r2, =ddStore
    str     r0, [r2]
    ldr     r2, =radius
    ldr     r0, =150            // radius => set Seconds Hand Radius (Length)
    str     r0, [r2]
    bl      sec2Loc             //convertSecToLoc
    
    ldr     r2, =X1
    ldr     r2, [r2]
    ldr     r1, =prevDistHorX
    str     r2, [r1]            // Save a copy to clear with next loop
    
    ldr     r3, =Y1
    ldr     r3, [r3]
    ldr     r1, =prevDistHorY
    str     r3, [r1]            // Save a copy to clear with next loop
    
    // Draw The Hours Hand
    //[X0] => Xcenter           // preset at start
    //[Y0] => Ycenter           // preset at start
    //[X1] => Xdist             // from sec2loc function
    //[Y1] => Ydist             // from sec2loc function
    ldr     r4, =hoursColor       // color
    mov     r5, #0                  // thikness as dot 1-3-1
    bl      draw_line_a

    pop     {r0-r10,pc}
    .ltorg

//-------------------------------------
//
//Making Minutes Hand
//
//-------------------------------------
makingMinutesHand:
    push    {r0-r7,lr}

    ldr     r0, =HEX_M
    ldr     r0, [r0]
    ldr     r1, =prevHEX_M
    ldr     r1, [r1]
    cmp     r0, r1
    beq     .skipClearM

    // Clear old Min Hand
    //[X0] Xcenter
    //[Y0] Yccenter
    ldr     r2, =prevDistMinX
    ldr     r2, [r2]
    cmp     r2, #0
    beq     .skipClearM
    ldr     r3, =prevDistMinY
    ldr     r3, [r3]
    cmp     r3, #0
    beq     .skipClearM
    ldr     r6, =X1
    str     r2, [r6]
    ldr     r7, =Y1
    str     r3, [r7]
    ldr     r4, =backgroundColor
    mov     r5, #1       // thikness as dot 1-3-1
    bl      draw_line_a

 .skipClearM:
    ldr     r0, =HEX_M
    ldr     r0, [r0]
    ldr     r1, =prevHEX_M
    str     r0, [r1]    // save HEX_S to prevHEX_S

    // Load Sec Hand Distination Point X , Y
    // Y = (r * sin((n+45) * 6 * (pi/180)) + YCenter  rounded to integers
    // X = (r * cos((n+45) * 6 * (pi/180)) + XCenter  rounded to integers
    
    add     r0, r0, #45          // Adjust n rotation 45º more
    cmp     r0, #60
    blt     .continueM          // make sure the result less than 60
    sub     r0, r0, 60          // else subtract 60 from result and it would be like back to zero

 .continueM:
    ldr     r2, =ddStore
    str     r0, [r2]
    ldr     r2, =radius
    ldr     r0, =200            // radius => set Seconds Hand Radius (Length)
    str     r0, [r2]
    bl      sec2Loc             //convertSecToLoc
    
    ldr     r2, =X1
    ldr     r2, [r2]
    ldr     r1, =prevDistMinX
    str     r2, [r1]            // Save a copy to clear with next loop
    
    ldr     r3, =Y1
    ldr     r3, [r3]
    ldr     r1, =prevDistMinY
    str     r3, [r1]            // Save a copy to clear with next loop

    // Draw The Minutes Hand
    //[X0] => Xcenter           // preset at start
    //[Y0] => Ycenter           // preset at start
    //[X1] => Xdist             // from sec2loc function
    //[Y1] => Ydist             // from sec2loc function
    ldr     r4, =minsColor       // color
    mov     r5, #1                  // thikness as dot 1-3-1
    bl      draw_line_a

    pop     {r0-r7,pc}
    .ltorg

//-------------------------------------
//
//Making Seconds Hand
//
//-------------------------------------
makingSecondsHand:
    push    {r0-r7,lr}

    ldr     r0, =HEX_S
    ldr     r0, [r0]
    ldr     r1, =prevHEX_S
    ldr     r1, [r1]
    cmp     r0, r1
    beq     .skipClearS
        
    // Clear old Sec Hand
    //[X0] Xcenter
    //[Y0] Yccenter
    ldr     r2, =prevDistSecX
    ldr     r2, [r2]
    cmp     r2, #0
    beq     .skipClearS
    ldr     r3, =prevDistSecY
    ldr     r3, [r3]
    cmp     r3, #0
    beq     .skipClearS
    ldr     r6, =X1
    str     r2, [r6]
    ldr     r7, =Y1
    str     r3, [r7]
    ldr     r4, =backgroundColor
    mov     r5, #2       // thikness as dot 1-3-1
    bl      draw_line_a

 .skipClearS:
    ldr     r0, =HEX_S
    ldr     r0, [r0]
    ldr     r1, =prevHEX_S
    str     r0, [r1]    // save HEX_S to prevHEX_S
    
    // Load Sec Hand Distination Point X , Y
    // Y = (r * sin((n+45) * 6 * (pi/180)) + YCenter  rounded to integers
    // X = (r * cos((n+45) * 6 * (pi/180)) + XCenter  rounded to integers
    
    add     r0, r0, #45          // Adjust n rotation 45º more
    cmp     r0, #60
    blt     .continueS          // make sure the result less than 60
    sub     r0, r0, 60          // else subtract 60 from result and it would be like back to zero
    
 .continueS:
    ldr     r2, =ddStore
    str     r0, [r2]
    ldr     r2, =radius
    ldr     r0, =215            // radius => set Seconds Hand Radius (Length)
    str     r0, [r2]
    bl      sec2Loc             //convertSecToLoc
    
    ldr     r2, =X1
    ldr     r2, [r2]
    ldr     r1, =prevDistSecX
    str     r2, [r1]            // Save a copy to clear with next loop
    
    ldr     r3, =Y1
    ldr     r3, [r3]
    ldr     r1, =prevDistSecY
    str     r3, [r1]            // Save a copy to clear with next loop
    
    // Draw The Seconds Hand
    //[X0] => Xcenter           // preset at start
    //[Y0] => Ycenter           // preset at start
    //[X1] => Xdist             // from sec2loc function
    //[Y1] => Ydist             // from sec2loc function
    ldr     r4, =secondsColor       // color
    mov     r5, #2                  // thikness as dot 1-3-1
    bl      draw_line_a

    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// checkButtons
// input:
// r0: 0:decrease 1:increase
// [index]
//----------------------------------------------------------------
checkButtons:
    push    {r0-r7,lr}

    bl      Get_Gyro_State          // r0= 0x3F(63):No Press   0x5(5): Vol Up Button Pressed 0xB(11): Vol Down Button Pressed
    mov     r0, r0, lsr #16         // mov bits[16-19] to the least Byte
    and     r0, r0, #0xF            // Get bits[0-4]
    cmp     r0, #0b1111             // 0b1111: No Tilt
    beq     .checkKeys

    bl      Get_Gyro_State          // r0= 0x3F(63):No Press   0x5(5): Vol Up Button Pressed 0xB(11): Vol Down Button Pressed
    mov     r0, r0, lsr #16         // mov bits[16-19] to the least Byte
    and     r0, r0, #0xF            // Get bits[0-4]
    cmp     r0, #0b0000             // 0b0000: Tilt Left => VolDown
    bne     .gyroRight
    
    ldr     r0, =100000000
.delayGyroLeft:
    subs    r0, r0, #1
    bne     .delayGyroLeft
    mov     r0,#0                   // Down indication
    bl      set_time                // bl this only when the user release after press
    b       .checkSelectSw

.gyroRight:
    bl      Get_Gyro_State          // r0= 0x3F(63):No Press   0x5(5): Vol Up Button Pressed 0xB(11): Vol Down Button Pressed
    mov     r0, r0, lsr #16         // mov bits[16-19] to the least Byte
    and     r0, r0, #0xF            // Get bits[0-4]
    cmp     r0, #0b1010             //0b1010: Tilt Right => VolUp
    bne     .checkKeys
    
    ldr     r0, =100000000
.delayGyroRight:
    subs    r0, r0, #1
    bne     .delayGyroRight
    mov     r0,#1                   // Up indication
    bl      set_time                // bl this only when the user release after press
    b       .checkSelectSw

.checkKeys:
    bl      Get_Keys_State      // r0= 0x3F(63):No Press   0x5(5): Vol Up Button Pressed 0xB(11): Vol Down Button Pressed
    and     r0, r0, #0xF        // Get bits[0-4]
    cmp     r0, #0xB
    bne     .volUp

.waitToReleaseVolDown:
    bl      Get_Keys_State
    cmp     r0, #0x3F
    bne     .waitToReleaseVolDown
    mov     r0,#0                   // Down indication
    bl      set_time                // bl this only when the user release after press
    b       .checkSelectSw
.volUp:
    cmp     r0, #0x5
    bne     .checkSelectSw
.waitToReleaseVolUp:
    bl      Get_Keys_State
    cmp     r0, #0x3F
    bne     .waitToReleaseVolUp
    mov     r0,#1                   // Up indication
    bl      set_time                // bl this only when the user release after press

.checkSelectSw:
    bl      PWR_SW_Read             // r0= 03:No Press   01: Power Button Pressed
    lsr     r0, r0, #0x4            // Shift bit[4] State to far right
    and     r0, r0, #0b1            // Get bit[0] state only
    cmp     r0, #0
    beq     .waitToRelaeseoPower
    b       .endCheckButtons

.waitToRelaeseoPower:
    bl      PWR_SW_Read
    lsr     r0, r0, #0x4            // Shift bit[4] State to far right
    and     r0, r0, #0b1            // Get bits[0-4]
    cmp     r0, #0
    beq     .waitToRelaeseoPower


    ldr     r0, =index              // bl this only when the user release after press
    ldr     r1, [r0]
    add     r1, r1, #1
    cmp     r1, #7
    movhi   r1, #0
    str     r1, [r0]

.endCheckButtons:
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// set_time
// input:
// r0: 0:decrease 1:increase
// [index]
//----------------------------------------------------------------
set_time:
    push    {r0-r7,lr}
    
    mov     r5, r0                          // save inc/dec position
    ldr     r7, =index
    ldr     r7, [r7]                        // r7 has index

    bl      RTC_Read                        // Get Time And Day
                                            //  r0: Time & Week
                                            //      bits[0-5] Second
                                            //      bits[8-13] Minute
                                            //      bits[16-20] Hour
                                            //      bits[29-31] Week Day
                                            //  r1: Day
                                            //      bits[0-4] Day
                                            //      bits[8-11] Month
                                            //      bits[16-23] Year
    cmp     r7, #0
    bne     .chgSeconds
    //---- State of pressing vol+/- when not in edit mode
    ldr     r1, =batteryMode
    ldr     r2, =monthMode
    cmp     r5, #1
    ldrne   r3, [r2]                        // if vol down change month mode view
    eorne   r3, r3, #1                      // XOR r3, #1 toggle it from 0 to 1 and vise versa
    strne   r3, [r2]
    ldreq   r3,[r1]                         // if vol up inc change battery mode view
    eoreq   r3, r3, #1                      // Toggle from 0 to 1
    streq   r3, [r1]
    b       .endSetTime
.chgSeconds:
    cmp     r7, #1                          // check if the index on Minutes
    bne     .chgMinutes
    and     r3, r0, #0x3F                   // r3 = Current Seconds
    cmp     r5, #1                          // see if inc or dec
    addeq   r3, r3, #1                      // inc if 1
    subne   r3, r3, #1                      // dec if 0
    cmp     r3, #59
    movgt   r3, #0
    cmp     r3, #0
    movlt   r3, #59
    mov     r0, r3
    mov     r1, #0x0                        // indicate we going to write r0 on seconds
    b       .doWriteTime

.chgMinutes:
    cmp     r7, #2                          // check if the index on Minutes
    bne     .chgHours
    lsr     r3, r0, #8                      // set bits[8-13] to the lsb
    and     r3, r3, #0x3F                   // r3 = Current Minutes
    cmp     r5, #1                          // see if inc or dec
    addeq   r3, r3, #1                      // inc if 1
    subne   r3, r3, #1                      // dec if 0
    cmp     r3, #59
    movgt   r3, #0
    cmp     r3, #0
    movlt   r3, #59
    mov     r0, r3
    mov     r1, #0x1                        // indicate we going to write r0 on minutes
    b       .doWriteTime
.chgHours:
    cmp     r7, #3                          // check if the index on Hours
    bne     .chgWeekDays
    lsr     r3, r0, #16                     // set bits[16-20] to the lsb
    and     r3, r3, #0x1F                   // r3 = Current hours
    cmp     r5, #1                          // see if inc or dec
    addeq   r3, r3, #1                      // inc if 1
    subne   r3, r3, #1                      // dec if 0
    cmp     r3, #23
    movgt   r3, #0
    cmp     r3, #0
    movlt   r3, #23
    mov     r0, r3
    mov     r1, #0x2                        // indicate we going to write r0 on Hours
    b       .doWriteTime

.chgWeekDays:
    cmp     r7, #4                          // check if the index on Days
    bne     .chgDays
    lsr     r3, r0, #29                     // set bits[29-31] to the lsb
    and     r3, r3, #0x7                    // r3 = Current WeekDay
    cmp     r5, #1                          // see if inc or dec
    addeq   r3, r3, #1                      // inc if 1
    subne   r3, r3, #1                      // dec if 0
    cmp     r3, #6
    movgt   r3, #0
    cmp     r3, #0
    movlt   r3, #6
    mov     r0, r3
    mov     r1, #0x4                        // indicate we going to write r0 on WeekDays
    b       .doWriteTime

.chgDays:
    cmp     r7, #5                          // check if the index on Days
    bne     .chgMonths
    and     r3, r1, #0x1F                   // r3 = Current Days
    cmp     r5, #1                          // see if inc or dec
    addeq   r3, r3, #1                      // inc if 1
    subne   r3, r3, #1                      // dec if 0
    bl      get_last_day_for_the_month      // return r0 30,31,28,or 29 According to Leap Year And Month Number
    cmp     r3, r0                          // Compare with last day of month 31,30,29 or 28 in case we increase the days
    movgt   r3, #1                          // if higher than last day of month return to day 1
    cmp     r3, #1                          // compare with first day of month in case we decrease the days
    movlt   r3, r0                          // if lower than 1 then set it to last day
    mov     r0, r3                          // set r0 for the RTC_Write function
    mov     r1, #0x3                        // set r1 for the RTC_Write function (indicate we going to write r0 on Days)
    b       .doWriteTime
.chgMonths:
    cmp     r7, #6                          // check if the index on Days
    bne     .chgYears
    lsr     r3, r1, #8                      // set bits[8-11] to the lsb
    and     r3, r3, #0xF                    // r3 = Current Months
    cmp     r5, #1                          // see if inc or dec
    addeq   r3, r3, #1                      // inc if 1
    subne   r3, r3, #1                      // dec if 0
    cmp     r3, #12
    movgt   r3, #1
    cmp     r3, #1
    movlt   r3, #12
    mov     r0, r3
    mov     r1, #0x5                        // indicate we going to write r0 on Months
    b       .doWriteTime
.chgYears:
    cmp     r7, #7                          // check if the index on Days
    bne     .endSetTime
    lsr     r3, r1, #16                     // set bits[16-21] to the lsb
    and     r3, r3, #0xFF                   // r3 = Current Years
    cmp     r5, #1                          // see if inc or dec
    addeq   r3, r3, #1                      // inc if 1
    subne   r3, r3, #1                      // dec if 0
    cmp     r3, #99
    movgt   r3, #0
    cmp     r3, #0
    movlt   r3, #99
    mov     r0, r3
    mov     r1, #0x6                        // indicate we going to write r0 on Years
    b       .doWriteTime


.doWriteTime:
    bl      RTC_Write                       // r0 = value
                                            // r1 = Type
                                            //      0x0: Seconds
                                            //      0x1: Minutes
                                            //      0x2: Hours
                                            //      0x3: Days
                                            //      0x4: WeekDay
                                            //      0x5: Months
                                            //      0x6: Year
                                            //      0x7: Minute_alarm
                                            //      0x8: Hour_alarm
                                            //      0x9: Day_alarm
                                            //      0xA: Weekday_alarm


.endSetTime:
    pop     {r0-r7,pc}
    .ltorg
 // End of function DE_BE_Offset_To_Addr

//----------------------------------------------------------------
// get_last_day_for_the_month
// input:
// r0: last Day for the Month
//      #30
//      #31
//      #28
//      #29
//----------------------------------------------------------------
get_last_day_for_the_month:
    push    {r1-r7,lr}

    ldr     r7, =[HEX_L]
    ldr     r7, [r7]            // Get leap Year Bit 0/1 (
    ldr     r6, =[HEX_N]
    ldr     r6, [r6]            // Get Month Number 1-12
    
    cmp     r6, #1
    bne     .feb
    b       .31
.feb:
    cmp     r6, #2
    bne     .mar
    cmp     r7, #1
    beq     .29
    b       .28
.mar:
    cmp     r6, #3
    bne     .apr
    b       .31
.apr:
    cmp     r6, #4
    bne     .may
    b       .30
.may:
    cmp     r6, #5
    bne     .jun
    b       .31
.jun:
    cmp     r6, #6
    bne     .jul
    b       .30
.jul:
    cmp     r6, #7
    bne     .aug
    b      .31
.aug:
    cmp     r6, #8
    bne     .sep
    b       .31
.sep:
    cmp     r6, #9
    bne     .oct
    b       .30
.oct:
    cmp     r6, #10
    bne     .nov
    b       .31
.nov:
    cmp     r6, #11
    bne     .dec
    b       .30
.dec:
    cmp     r6, #12
    bne     .30
    b       .31
    
.28:
    mov     r0,#28
    b       .endGetDaysMonth
.29:
    mov     r0,#29
    b       .endGetDaysMonth
.30:
    mov     r0,#30
    b       .endGetDaysMonth
.31:
    mov     r0,#31
    b       .endGetDaysMonth

.endGetDaysMonth:
    pop     {r1-r7,pc}
    .ltorg

//----------------------------------------------------------------
// stopTillVolDown
// Stop Code untill you press Volume Down Once
// Useful for Debugging as a Breakpoint
// input:
// r0: 0:decrease 1:increase
// [index]
//----------------------------------------------------------------
stopTillVolDown:
    push    {r0-r7,lr}
    
.loopBreakPoint:
    bl      Get_Keys_State      // r0= 0x3F(63):No Press   0x5(5): Vol Up Button Pressed 0xB(11): Vol Down Button Pressed
    and     r0, r0, #0xF        // Get bits[0-4]
    cmp     r0, #0xB
    bne     .loopBreakPoint

.waitToReleaseVolDownBreakPoint:
    bl      Get_Keys_State
    cmp     r0, #0x3F
    bne     .waitToReleaseVolDownBreakPoint

    pop     {r0-r7,pc}
    .ltorg

// =============== S U B R O U T I N E =======================================
// Cover Splash With A Black Screen
// Data to be used after inspection is
// r4       = 0xD912E800
// Va       = 0xE1000000
// Pa       = 0x7A400000
// Length   = 0xC00000 Should Be 0xBB800 
// ===========================================================================
blackout:
    push {r0-r4, lr}
    
    // VA_SAVE address
    ldr     r0, =0xC0000800
    
    ldr     r4, [r0]    // get r4
    ldr     r3, [r0,#0x4] // get r3 (VA)
    ldr     r2, [r0,#0x8] // get r2 (PA)
    //ldr     r1, [r0,#0xC] // get r1 Length (it is proofed as 800 x 480 x 2 = 0xBB800)
    ldr     r1, =0xBB800  //800 x 480 x 2 = 0xBB800
    dsb     sy
    isb     sy

    // r4 must point to the framebuffer descriptor struct (same as caller).
    mov     r0, r3                  // r0 = fb_virtual_base

    mov     r2, #COLOR_BLACK        // high word 0x0000 black color RGB565

    // compute end pointer
    add     r4, r0, r1         // r5 = end

.fill_loop_16:
    cmp     r0, r4
    bcs     .fb_done

    /* store halfword and advance by 2 */
    strh    r2, [r0], #2
    b       .fill_loop_16

.fb_done:
    pop {r0-r4, pc}
// End of Blackout Subroutine



// =============== S U B R O U T I N E =======================================
// Convert Offset Aka X, Y Point into Address
// Address = FrameBufferBase + (Bpp * [(width * Y) + X])//
// input:
// r2 = X
// r3 = Y
// r4 = Color
// ===========================================================================
 draw_point:
    push    {r0-r7,lr}
    
    ldr     r0, =GFX_VA_Address_Location            // FrameBufferBase
    ldr     r0, [r0]
    mov     r1, #GFX_WIDTH              // LCD Width 800
    mov     r5, #2                      // Bpp = 2 (16 bit color)

    mul     r6, r1, r3                 // r6 = width * Y
    add     r6, r2, r6                 // r6 = [width * Y] + X
    mul     r6, r5, r6                 // r6 = Bpp * [(width * Y) + X]
    add     r6, r0, r6                 // r6 = FrameBufferBase + (Bpp * [(width * Y) + X])
    strh    r4, [r6]
    
    pop     {r0-r7,pc}
    .ltorg
 // End of function DE_BE_Offset_To_Addr

//----------------------------------------------------------------------------
// convert seconds into locations on the rim of the Clock
// to be used as an end point for drawing a line from center
// x = Xc + [r * cos(n * Çº)]
// y = Yc + [r * sin(n * Çº)]
// Çº = segment angle (6º * (pi/180)), r = radius,
// Xc & XY = center X & Y, n = Second number on clock ( 0.. 59)
//   Inputs
// [sAngle] = Çº = [(360/60) * (pi/180)] => [6º * (pi/180)] => 0.10471976
// [radius] = r  = 95
// [ddStore] = n = (0..59)
// [X0] = Circle center Point x Position
// [Y0] = Circle center Point y Position
//   Output
// [X1] = x
// [Y1] = y
//----------------------------------------------------------------------------
    //<<<<<<<<<<<<<<<<<<<<<<IMPORTANT NOTICE ABOUT FPU REGISTERS>>>>>>>>>>>>>>>>>>>>
    // FPU and NEON Registers are not permenant but like a stack so
    // you do not assume that because you put a number in A register
    // that it would stay intact when make operations on other S registers
    // they are all related even if you dont use.
    // for example having a number in S3 could be effected when vmul s0, s1, s2
    // even though you did not touch s3 but it could get garbage so easily
    // or at the bast circumestances it would get cleared (become zero).
    //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
sec2Loc:
    push                    {r0-r10,lr}

  // a) Getting X1 Section
    
    // n * Çº
    ldr                     r1, =sAngle     // this is a constant .eq sAngle, 0.10471976
    vmov.f32                s0, r1
    ldr                     r1, =ddStore
    vldr                    s1, [r1]
    vcvt.f32.s32            s1, s1          // convert from int to float
    vmul.f32                s3, s0, s1      // s3 = n * Çº aka fResult

    // cos(n * Çº)
    vmov.f32                r0, s3
    bl                      vcos            // Calculate cos(r0)
    vmov.f32                s0, r0          // s0 = cos(n * Çº)
    
    // r * cos(n * Çº)
    ldr                     r1, =radius
    vldr                    s4, [r1]        // s4 = (INT) radius
    vcvt.f32.s32            s4, s4          // s4 = (FLOAT) radius (convert from int to float)
    vmul.f32                s2, s0, s4      // s2 = r * cos(n * Çº) to memory
    
    // add X center location to the ddStore 160
    ldr                     r2, =X0
    vldr                    s1, [r2]        // s1 = X0
    vcvt.f32.s32            s1, s1          // convert from int to float
    vadd.f32                s0, s1, s2      // s0 = X0 + [r * cos(n * Çº)]
    
    // float2Int for X1
    vcvt.s32.f32            s0, s0          // convert from float to int
    ldr                     r2, =X1
    vstr                    s0, [r2]        // X1 Has the X Location Out

  // b) Getting Y1 Section
    
    // n * Çº
    ldr                     r1, =sAngle     // this is a constant .eq sAngle, 0.10471976
    vmov.f32                s0, r1
    ldr                     r1, =ddStore
    vldr                    s1, [r1]
    vcvt.f32.s32            s1, s1          // convert from int to float
    vmul.f32                s3, s0, s1      // s3 = n * Çº aka fResult

    // sin(n * Çº)
    vmov.f32                r0, s3          // s3 stil holds n * Çº aka fResult
    bl                      vsin            // Calculate sin(r0)
    vmov.f32                s0, r0          // s0 = sin(n * Çº)
    
    // r * sin(n * Çº)
    ldr                     r1, =radius
    vldr                    s4, [r1]        // s4 = (INT) radius
    vcvt.f32.s32            s4, s4          // s4 = (FLOAT) radius (convert from int to float)
    vmul.f32                s2, s0, s4      // s2 = r * sin(n * Çº) to memory

    // add Y center location to the ddStore 100
    ldr                     r3, =Y0
    vldr                    s1, [r3]        // s1 = Y0
    vcvt.f32.s32            s1, s1          // convert from int to float
    vadd.f32                s0, s1, s2      // s0 = Y0 + [r * sin(n * Çº)]

    // Float2Int for Y1
    vcvt.s32.f32            s0, s0          // convert from float to int
    ldr                     r3, =Y1
    vstr                    s0, [r3]        // Y1 Has the Y Location Out

    pop                     {r0-r10,pc}
    .ltorg


//-------------------------------------
// Draws a line using x86 legacy modulated for x64 (Bresenham`s line algorithm)
// [X0] = StartX X0
// [X1] = EndX X1
// [Y0] = StartY Y0
// [Y1] = EndY Y1
// r4 = Color
// r5 = Thikness
//      0: large (max)
//      1: medium
//      2: small (min)
//-------------------------------------
draw_line_a:
    push    {r0-r10,lr}

    ldr     r2, =X0
    ldr     r2, [r2]                // r2 = X0
    ldr     r1, =.newXa
    str     r2, [r1]

    ldr     r3, =Y0
    ldr     r3, [r3]                // r3 = Y0
    ldr     r1, =.newYa
    str     r3, [r1]

    ldr     r6, = X1
    ldr     r6, [r6]
    sub     r6, r6, r2              // r6 = ∆X = X1 - X0 (distance on X Axis)) fits 32k
                                    // ex. X1 = 32000 X0 = 0 (32000 - 0) = 32000 = 0x7d00 (16bit)
    ldr     r7, =Y1
    ldr     r7, [r7]
    sub     r7, r7, r3              // r7 = ∆Y = Y1 - Y0 (distance on Y Axis) fits 32k
                                    // ex. Y1 = 32000 Y0 = 0 (32000 - 0) = 32000 = 0x7d00 (16bit)

        // Start Assesment the Line Slope And direction
    mov     r2, #1                  // Xi = X Axis index one pixel increase/decrease 1 = increase -1 = decrease
    mov     r3, #1                  // Yi = X Axis index one pixel increase/decrease 1 = increase -1 = decrease

    ldr     r0, =.Sl
    mov     r1, #1
    str     r1, [r0]                // SL is set to Positive Slope  Slope Direction (Default is Positive) 1 = Positive, 0 = Negative

    cmp     r6, #0x80000000         // Compare r6 with center value of 32bit 0x80000000 to know if its minus or plus
                                    // This to get ABS(∆X) (make it positive if its negative value fits 32K+ Resolution)
                                    // if ∆X is already positive value so we targeting >>> RIGHT <<< go to r0
                                    // else (if ∆X is negative) so we targeting >>> LEFT <<<
    rsbhs   r6, r6, #0              // neg r6 (If unsigned higher or same, r6 = 0 - r6)
                                    // make r6 = ABS(∆X) Correct it to Positive again Aka distance on X Axis
    rsbhs   r2, r2, #0              // neg r2 (If unsigned higher or same, r2 = 0 - r2)
                                    // make r2 = -1/0 also make sure that AX has changed into X DECREMENTAL index
                                    
    cmp     r7, #0x80000000         // Compare r7 with center value of 32bit 0x80000000 to know if its minus or plus
                                    // This to get ABS(∆Y) (make it positive if its negative value fits 32K+ Resolution)
                                    // if ∆Y is already positive value so we targeting >>> DOWN <<< go to r1
                                    // else (if ∆Y is negative) so we targeting >>> UP <<<
    rsbhs   r7, r7, #0              // neg r7 (If unsigned higher or same, r7 = 0 - r6)
                                    // make r7 = ABS(∆Y) Correct it to Positive again Aka distance on Y Axis
    rsbhs   r3, r3, #0              // neg r3 (If unsigned higher or same, r3 = 0 - r3)
                                    // make r3 = -1/0 make sure that r3 has changed into Y DECREMENTAL index

    cmp     r6, r7                  // Compare ABS(∆X) with ABS(∆Y (distance on Y Axis to distance on Y Axis)
                                    // to get the slope direction (Positive / Negative)
    bhi   .region2                  // if ABS(∆X) > ABS(∆Y) So it is >>> POSITIVE <<< slope
                                    // So Keep AX As Horizontal Index and r2 As Vertical Index and go to r2

    mov     r0, r2                  // else if it is >>> NEGATIVE <<< Slope so exchange Xi with Yi -> r2 with r3
    mov     r2, r3
    mov     r3, r0                  // xchg r2, r3
    
    mov     r0, r6                  // and exchange also ∆X with ∆Y si, di
    mov     r6, r7
    mov     r7, r0                  // xchg r6, r7
                                    // hint: Positive Slope where the Line angel with X Axis is smaller than its angel with Y Axis
                                    // as if its leaning more to X Axis and far from Y Axis
                                    // Negative Slope where the Line angel with Y Axis is smaller then its angel with X Axis
                                    // as if its leaning more to Y Axis and far from Y Axis
                                    // check photos below for negative and positive slopes in all directions
     ldr    r0, =.Sl
     mov    r1, #0
     str    r1, [r0]                // SL is set to Negative Slope 0 = Negative
     
 
 
        //   POSITIVE Slope SL = 1 Conditions (ABS(∆X) > ABS(∆Y)         //   NEGATIVE Slope SL = 0 Conditions (ABS(∆Y) ≥ ABS(∆X)
        //               Çº < Øº Line lean to X                          //            Øº ≤ Çº Line lean to Y
        //                          -Y                                   //                       -Y
        //  r2 = -(Xi), r3 = -(Yi)   |  r2 = Xi, r3 = -(Yi)              //               .        |        .
        //                           |                                   //                .       |       .
        //                           |                                   //  r3 = -(Xi),    .      |      .  r3 = Xi,
        //       -(∆X) & -(∆Y)       |     +∆X & -(∆Y)                   //  r2 = -(Yi)      .     |     .   r2 = -(Yi)
        //   .                       |                       .           //                   .    |    .
        //         .                 |                 .                 //                    .   |   .
        //               .           | Øº        .                       //                     .  |Øº.
        //                     .     |     .                             //   -(∆X) & -(∆Y)      . | .      +∆X & -(∆Y)
        //                          .|.    Çº                            //                       .|. Ç
        //-X ------------------------|----------------------- +X         //-X ---------------------|---------------------- +X
        //                          .|.    Çº                            //                       .|. Çº
        //                     .     |     .                             //                      . | .
        //               .           |  Øº       .                       //    r3 = -(Xi),      .  |Øº.       r3 = Xi,
        //         .                 |                 .                 //    r2 = Yi         .   |   .      r2 = Yi
        //   .                       |                       .           //                   .    |    .
        //                           |                                   //                  .     |     .
        //   r2 = -(Xi), r3 = Yi     |   r2 = Xi, r3 = Yi                //                 .      |      .
        //                           |                                   //   -(∆X) & +∆Y  .       |       .   +∆X & +∆Y
        //       -(∆X) & +∆Y         |       +∆X & +∆Y                   //               .        |        .
        //                          +Y                                   //                       +Y
                                                                                
                                        
.region2:
        // Drawing loop starts here after assesment of the line condition (slope, direction etc.)
    ldr     r0, =.ct
    str     r6, [r0]                // .ct = save r6 what ever it is ∆X or if slope is negative ∆Y

    mov     r10, #0                 // make sure rcx start at 0
 .l0:
        // Draw Point According to Thikness
    mov     r8, r2                  // save r2 main point draw
    mov     r9, r3                  // save r3
    ldr     r2, =.newXa
    ldr     r2, [r2]
    ldr     r3, =.newYa
    ldr     r3, [r3]
    bl      draw_dot
    mov     r3, r9                      // restore r3
    mov     r2, r8                      // restore r2

    ldr     r0, =.Sl
    ldr     r0, [r0]
    cmp     r0, #1                  // Check Slope Direction
    
    ldreq   r0, =.newXa              // if Positive Slope
    ldreq   r1, [r0]
    addeq   r1, r1, r2              // add [.newXa], r2
    streq   r1, [r0]
    
    ldrne   r0, =.newYa              // if Negative Slope
    ldrne   r1, [r0]
    addne   r1, r1, r2              // add [.newYa], r2
    strne   r1, [r0]

    subs    r10, r10, r7            // sub rcx (starts at 0 1st loop) - ∆Y/∆X according to the ABS results
    bhs     .region3                // if unsigned high or same (aka carry set) so it is still within ∆X scope
                                    // so draw another horizontal X Pixel at same row
    add     r10, r10, r6            // else (if unsigned lower (aka carry clear) so it is out of ∆X (the screen width)
                                    // so you need to go to the next row
                                    // add the rcx with the ∆X/∆Y according to the ABS results but since it is a Carry Set
                                    // so it is definatly ∆Y so next pixel have to be on a new raw
    ldr     r0, =.Sl
    ldr     r0, [r0]
    cmp     r0, #1                  // Check Slope Direction

    ldreq     r0, =.newYa            // if Positive Slope
    ldreq     r1, [r0]
    addeq     r1, r1, r3            // add [.newYa], r3
    streq     r1, [r0]

    ldrne     r0, =.newXa            // if Negative Slope
    ldrne     r1, [r0]
    addne     r1, r1, r3            // add [.newXa], r3
    strne     r1, [r0]

.region3:
    ldr     r0, =.ct
    ldr     r1, [r0]
    sub     r1, r1, #1              // decrease the ∆Y/∆X according to the ABS results untill its zero
    str     r1, [r0]
    cmp     r1, #0
    bne     .l0                     // loop for next pixel draw


    pop     {r0-r10,pc}
    .ltorg


//-------------------------------------------------------------------------------------------------------------
// Draw line using FPU Triangility
// we get the angle of the line from the X Axis
// then we draw a dot on the rim of circle around the center (X0, Y0) using the angle
// then we repeat thease dots with different circle radiuses
// untill the radius became more than the length of the line
// [X0] = StartX X0 (center X0)
// [Y0] = StartY Y0 (center Y0)
// [X1] = EndX X1
// [Y1] = EndY Y1
// r4 = Color
// r5 = Thikness
//-------------------------------------------------------------------------------------------------------------
draw_line_b:

        //
        //                             ∆X                X = X0 + [r * cos(Çº)]
        //                       -Y (X1-X0)              Y = Y0 + [r * sin(Çº)]
        //                        |<------>. (X1, Y1)
        //                        |       .^
        //                        |      . |
        //                        |     .  |
        //                        |    .   |  ∆Y (Y1 - Y0)
        //                        |   .    |
        //                        |  .     |
        //                        | .      |
        //                        |. Çº    v Çº = ATAN2(∆X, ∆Y)
        //-X ---------------------|---------------------- +X
        //                (X0, Y0)|
        //                        | 1- get ∆`s
        //                        | 2- get Çº
        //                        | 3- get length √[∆X² + ∆Y²]
        //                        | 4- get (X, Y) Positions At radius (r) = 0
        //                        |     X = X0 + [r * cos(Çº)]
        //                        |     Y = Y0 + [r * sin(Çº)]
        //                        | 5- increase radius (r) and draw a dot at (X, Y)
        //                        | 6- repeat from step 4 untill radius (r) is above Length
        //                       +Y
        //
        // .X0:        r2 r6
        // .Y0:        r3, r7
        // .X1:        r0
        // .Y1:        r1
        // .∆X:        r6
        // .∆Y:        r7
        // .Çº:        r8
        // .rad:       r9
        // .len:       r10
        // .newX:      r2
        // .newY:      r3

    push                {r0-r10,lr}
    
    ldr                 r2, =X0
    ldr                 r2, [r2]                    // r2 = X0
    
    ldr                 r3, =Y0
    ldr                 r3, [r3]                    // r3 = Y0

    ldr                 r0, =X1
    ldr                 r0, [r0]                    // r0 = X1
    
    ldr                 r1, =Y1
    ldr                 r1, [r1]                    // r1 = Y1

        // 1st: we get the Deltas ∆X, ∆Y (distance between X1 and X0 , Y1 And Y0)
        // ΔX = X1 - X0b
        // ΔY = Y1 - Y0b
    //mov     r9, r0              //x1 = 600 x2 = 300
    //mov     r0, r2
    //bl      printDec00A
    //mov     r0, r3
    //bl      printDec00B
    //mov     r0, r9

    // (Float) Calculate ΔX = X1 - X0
    //sub    r6, r0, r2  // (FLoat) r6 = ΔX = X1 - X0
    vmov                s0, r0  // Load X1
    vcvt.f32.s32        s0, s0  //Convert to Float
    vmov                s2, r2  // Load X0
    vcvt.f32.s32        s2, s2  //Convert to Float
    vsub.f32            s6, s0, s2
    vmov.f32            r6, s6  // r6 = ΔX
    

    // (Float) Calculate ΔY = Y1 - Y0
    //sub    r7, r1, r3  // (Float) r7 = ΔY = Y1 - Y0
    vmov                s1, r1  // Load Y1
    vcvt.f32.s32        s1, s1  //Convert to Float
    vmov                s3, r3  // Load Y0
    vcvt.f32.s32        s3, s3  //Convert to Float
    vsub.f32            s7, s1, s3
    vmov.f32            r7, s7  // r7 = ΔY

        // 2nd: get the line length  To have the Maximum radius of the invisible circles we draw a dot on each
        // Length=√[∆X² +∆Y²]
 
    //mov     r0, r6
    //bl      printIEEE100A       //-200.00
    //mov     r0, r7
    //bl      printIEEE100B       //-140.00


    // Calculate ∆X²
    vmov.f32            s6, r6      // Load r6 = ΔX
    vmul.f32            s8, s6, s6  // (Float) r8 = ΔX² = (mul r6, r6)
    vmov.f32            r8, s8      // r8 = ΔX²

    // Calculate ∆Y²
    vmov.f32            s7, r7      // Load r7 = ΔY
    vmul.f32            s9, s7, s7  // (Float) r9 = ΔY² = (mul r7, r7)
    vmov.f32            r9, s9      // r9 = ΔY²

    // Add ∆X² + ∆Y²
    vmov.f32            s8, r8
    vmov.f32            s9, r9
    vadd.f32            s9, s9, s8  // (Float) r9 = ΔX² + ΔY²

    // Calculate the square root <---- float input
    vsqrt.f32           s10, s9     // (Float) s10 = √[∆X² + ∆Y²]
    vcvt.s32.f32        s10, s10    // Convert Length to Integer
    vmov                r10, s10    // (INT) r10 = Length = √[∆X² + ∆Y²]

    //mov     r0, r10
    //bl      printDec200A            // 208 length 244

        // 3rd: get the angel of the line From X Axis
        // Çº = ATAN2(∆X, ∆Y)
        // where ∆X = X1 - X0
        // and   ∆Y = Y1 - Y0
        // Çº is the angel
        
    // Load ΔY and ΔX onto the FPU stack
    mov                 r0, r7      // (Float) r0 = ΔY
    mov                 r1, r6      // (Float) r1 = ΔX
    bl                  vatan2      // Compute angle in radians r0 = Çº = ATAN2(∆X, ∆Y)
    mov                 r8, r0      // (Float) r8 = Çº = ATAN2(∆X, ∆Y)

    //mov     r0, r8
    //bl      printIEEE200B           // 0.291456794478 = 16.6992º  -2.530866689201

        // 4th: Draw Loop
        // using this angel we draw several point from radius 0 to radius max (length of line)
        //X = X0 + [r * cos(Çº)]
        //Y = Y0 + [r * sin(Çº)]
        // where X0,Y0 = center point (start of line)
        // and   Çº is the angel
        // r is the radius (change it from 0 to l)
        // l length of line

    // here is a cpu carbon emmision reducer by pre calculatin the sin and cos so the loop would be free of fpu
    mov                 r0, r8      // (Float) Load Çº r0 = .Çºb
    bl                  vcos        // Compute cos(Çº) r0 = cos(Çº)
    //bl      printIEEE300A
    mov                 r1, r0      // r1 = cos(Çº)
    
    mov                 r0, r8      // (Float) Load Çº r0 = .Çºb
    bl                  vsin        // Compute cos(Çº) r0 = sin(Çº)
    //bl      printIEEE300B
    mov                 r8, r0     // r11 = sin(Çº)
                                    

    mov                 r6, r2      // save X0 in r6 cause we would use r2 for drawing
    mov                 r7, r3      // save y0 in r7 cause we would use r3 for drawing

    mov                 r9, #0     // r9 = radius starts at 0

 .loopdrawb:
    // Load angle into FPU
    vmov.f32            s0, r1      // (Float) s0 = cos(Çº)
    vmov                s9, r9      // (INT)s9 = radius (start at 0)
    vcvt.f32.s32        s9, s9      // (Float) s9 = radius
    vmul.f32            s1, s9, s0  // s1 = r * cos(Çº)

    vmov                s2, r6      // (INT)s2 = X0
    vcvt.f32.s32        s2, s2      // Convert X0 Integer to Float
    vadd.f32            s2, s2, s1  // (INT) r2 = .newX = X0 + [r * cos(Çº)]
    vcvt.s32.f32        s2, s2      // Convert Float to Integer
    vmov                r2, s2      //(INT) r2 = .newX = X0 + [r * cos(Çº)]
    
    //mov         r0, r2
    //bl          printDec400A

    // Load angle again for sin(Ç)
    vmov.f32            s0, r8      // (Float) s0 = sin(Çº)
    vmov                s9, r9      // (INT)s1 = radius (start at 0)
    vcvt.f32.s32        s9, s9      // (Float) s1 = radius
    vmul.f32            s1, s9, s0  // s1 = r * sin(Çº)

    vmov                s3, r7      // (INT)s3 = Y0
    vcvt.f32.s32        s3, s3      // Convert Y0 Integer to Float
    vadd.f32            s3, s3, s1  // (INT) r3 = .newY = Y0 + [r * sin(Çº)]
    vcvt.s32.f32        s3, s3      // Convert Float to Integer
    vmov                r3, s3      //(INT) r3 = .newY = Y0 + [r * sin(Çº)]

    //mov         r0, r3
    //bl          printDec400B



        // Draw Point According to Thikness
    // r2: newX r3: newY r4: color r5: thikness
    bl                  draw_dot
 
    add                 r9, r9, #1      // inc .rad radius

    //bl      stopTillVolDown

    cmp                 r9, r10
    ble                 .loopdrawb  // else keep looping
    
    pop                 {r0-r10,pc}
    .ltorg


//-----------------------------
// Draw painted circle
//   Inputs
// [radius] =  Circle Radius
// [X0] = Circle center Point x Position
// [Y0] = Circle center Point y Position
// r0 = count of dots 60
// r4 = color
//-----------------------------
createDotsCircle:
    push        {r0-r10,lr}
    mov         r6, r0                      // Save r0 (Count)
    mov         r1, #0
.dotsLoop:
    ldr         r2, =ddStore
    str         r1, [r2]                    // starts from 0 then up to 59
    bl          sec2Loc                     // convert Seconds To x,y Locations
    
    ldr         r2, =X1
    ldr         r2, [r2]
    ldr         r3, =Y1
    ldr         r3, [r3]
    mov         r5, #2                      // Size small
    bl          draw_dot                    //draw_dot_6px
        
    // get a number that could get no fraction when devided over 5
    cmp         r1, #0
    bne         .not12
    b           .big_dot
.not12:
    @ Input: r1 = the number to check if divisible on 5
    @ Output: R0 = 0 if divisible by 5, else non-zero
    mov         r0, r1                      @ Keep a copy of the original number in R1
    ldr         r2, =0xCCCCCCCD             @ Load "magic number" (approx 4/5 * 2^32)
    umull       r3, r2, r0, r2              @ r2 = (r0 * 0xCCCCCCCD) >> 32 [roughly 4/5 of R1]
    mov         r2, r2, lsr #2              @ r2 = r2 >> 2 [Final quotient: R1 / 5]
    
    @ Calculate Remainder: Rem = Original - (Quotient * 5)
    mov         r3, #5                      @ Load constant 5
    mul         r2, r2, r3                  @ r2 = Quotient * 5
    subs        r0, r1, r2                  @ r0 = Original - (Quotient * 5)
    @ Result: R0 is the remainder.
    @ You can use 'CMP R0, #0' then 'BEQ' to branch if divisible.

    cmp         r0, #0                      // Compare r0 with 0
    bne         .fraction_found             // if r0 is 0, meaning no remainder/no fraction)

.big_dot:
    ldr         r2, =X1
    ldr         r2, [r2]
    ldr         r3, =Y1
    ldr         r3, [r3]
    mov         r5, #0                      // Size large
    bl          draw_dot                    //draw_filled_diamond_16px   // draw big dot

.fraction_found:
    mov         r0, r6                      // restore back r0 (count)
    add         r1, r1, #1
    cmp         r1, r0                      // cmp to the count
    blt         .dotsLoop

    pop         {r0-r10,pc}
    .ltorg

//----------------------------------------------------------------------------------------------
// Draw Filled circle Using legacy Line By Line Algorithm modulated for x64 (Faster on Emulator)
// r0 = radius
// r2 = StartX X0 (center X0)
// r3 = StartY Y0 (center Y0)
// r4 = Color
//-----------------------------------------------------------------------------------------------
draw_pie_a:

    // Circle Drawing Theory:
    // 1. Symmetry: Circles are symmetric. For any point '(x, y) on the circle,
    //    there are symmetrical points at '(-x, y), (x, -y), (-x, -y), & (y, x).
    //
    // 2. Radius and Extents: In the code, 'Ye' (vertical extent) increases from
    //    the center of the circle upward and downward, while 'Xe' (horizontal
    //    extent) decreases as you move further away from the center vertibly.
    //    The relationship between radius 'r', vertical extent 'Ye', and horizontal
    //    extent 'Xe' is based on the equation of a circle:' x² + y² = r².
    //    When you increment 'Ye', the corresponding 'Xe' should be reduced to
    //    maintain the circle`s shape, derived from ' Xe = √(r² - Ye²).
    //
    // 3. Why Reduce 'Xe'? As you go higher (or lower) from the center (increasing 'Ye'),
    //    the maximum horizontal extent 'Xe' decreases. Thus, when drawing the filled
    //    circle, after hitting certain vertical levels, the radius is adjusted
    //    downward, and the horizontal extent is reduced to fill the circle correctly.
    //
    // This method effectively utilizes the circle's geometry to ensure that as
    // you draw vertibly, you correctly adjust the horizontal extent to maintain
    // the filled circle shape.
    //
    //          0                   Xc - Xe
    //         ---------------------------------------------------------------------------  X
    //       0 |                  5  4  3  2  1      1  2  3  4  5
    //         |     🔲 🔲 🔲 🔲 🔲 🔲 🟨 🟨 🟩 ⬛️ ⬛️ 🔲 🔲 🔲 🔲 🔲 🔲  1) r:8 Xe:1 Ye:8 Pc:3 | 2)r:5 Xe:2 Ye:8 Pc:5 (2Xe + 1)
    //         |     🔲 🔲 🔲 🔲 🟨 🟨 🟩 🟩 🟩 🟩 🟩 ⬛️ ⬛️ 🔲 🔲 🔲 🔲  3) r:15 Xe:3 Ye:7 Pc:7 (2Xe+1) | 4) r:8 Xe:4 Ye:7 Pc:9 (2Xe+1)
    //         |     🔲 🔲 🔲 🟨 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲 🔲 🔲  5) r:12 Xe:5 Ye:6  Pc:11 (2Xe+1)
    // Yc - Ye |   5 🔲 🔲 🟪 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲 🔲  5) r:12 Xe:6 Ye:5  Pc:13 (2Xe+1)
    //         |   4 🔲 🟪 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲  4) r:8 Xe:7 Ye:4   Pc:15 (2Xe+1)
    //         |   3 🔲 🟪 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲  3) r:15 Xe:7 Ye:3  Pc:15 (2Xe+1)
    //         |   2 🟪 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️  2) r:5 Xe:8 Ye:2   Pc:17 (2Xe+1)
    //         |   1 🟪 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️  1) r:8 Xe:8 Ye:1   Pc:17 (2Xe+1)
    //         |   0 🟫 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟥 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️  0) r:8 Xe:8 Ye:0   Pc:17 (2Xe+1) <======= Start Here
    //         |   1 🟦 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️  1) r:8 Xe:8 Ye:-1  Pc:17 (2Xe+1)
    //         |   2 🟦 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️  2) r:5 Xe:8 Ye:-2  Pc:17 (2Xe+1)
    //         |   3 🔲 🟦 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲  3) r:15 Xe:7 Ye:-3 Pc:15 (2Xe+1)
    //         |   4 🔲 🟦 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲  4) r:8 Xe:7 Ye:-4  Pc:15 (2Xe+1)
    //         |   5 🔲 🔲 🟦 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲 🔲  5) r:12 Xe:6 Ye:-5  Pc:13 (2Xe+1)
    //         |     🔲 🔲 🔲 🟧 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲 🔲 🔲  5) r:12 Xe:5 Ye:-6  Pc:11 (2Xe+1)
    //         |     🔲 🔲 🔲 🔲 🟧 🟧 🟩 🟩 🟩 🟩 🟩 ⬛️ ⬛️ 🔲 🔲 🔲 🔲  3) r:15 Xe:3 Ye:-7 Pc:7 (2Xe+1) | 4) r:8 Xe:4 Ye:7 Pc:9 (2Xe+1)
    //         |     🔲 🔲 🔲 🔲 🔲 🔲 🟧 🟧 🟩 ⬛️ ⬛️ 🔲 🔲 🔲 🔲 🔲 🔲  1) r:8 Xe:1 Ye:-8 Pc:3 | 2)r:5 Xe:2 Ye:-8 Pc:5 (2Xe+1)
    //         |               5  4  3  2  1      1  2  3  4  5
    //         |
    //         |
    //         |
    //         Y
    //
    //
    //   Notes:
    //   - Start drawing point is Calculated as (Xc - Xe) & (Yc - Ye)
    //   - Each set is 4 rows, above and below start row then below and above top and bottom rows.
    //   - init row is a single row set and is always drawn alone before any other rows
    //   - After draw each set of lines we do this calculations:
    //           a) is (r - [(2 * Ye) + 1]) > (Ye + 1) and we change r = ( r - [(2 * Ye) + 1]) and Ye = (Ye + 1)
    //           b) if true do not reduce Xe next loop, if false change Xe and r before next set
    //           c) we change Xe and r like so r = (r + [(2 * Xe) - 1]) and Xe = (Xe - 1)
    //   - The length of each line Pc (Pixel count) Calculated as Pc = (2 * Xe) + 1
    //   - The drawing Should Stop when Xe < Ye So we need to check this in every loop so when it happen we return
    //   - Exact effect on r, Xe, Ye After drawing every set:
    //     after 1) r = 5 =>(8-[(2*1)+1]), Ye = 2 => (1+1), Xe = 8 => (5 > 2 so no change)
    //     after 2) r = 0 =>(5-[(2*2)+1]), Ye = 3 => (2+1), 0 < 3 => we will reduce Xe and change r
    //              r = 15 =>(0+[2*8]-1]), Xe = 7 => (8-1), Ye = 3 (as it was) (we start loop set 3 with those values)
    //     after 3) r = 8 =>(15-[(2*3)+1]), Ye = 4 => (3+1), Xe = 7 => (8 > 4 so no change)
    //     after 4) r = -1 =>(8-[(2*4)+1]), Ye = 5 => (4+1), -1 < 5 => we will reduce Xe and change r
    //              r = 12 =>((-1)+[2*7]-1]), Xe = 6 => (7-1), Ye = 5 (as it was) (we start loop set 5 with those values)
    //     after 5) r = 1 =>(12-[(2*5)+1]), Ye = 6 => (5+1), 1 < 5 => we will reduce Xe and change r
    //              r = 12 =>(1+[2*6]-1]), Xe = 5 => (6-1), Ye = 6 (as it was) (we do not draw anymore as Xe < Ye so we're done)
    //
    //    🟥 is the center Pixel of the Filled Circle (Your Start Point) Xc, Yc
    //    🟫 is the Start of Center Row (1st Row) initial row, not related to other 4 sets drawing rows
    //    🟪 is the Start of filled Row Upper Part
    //    🟦 is the Start of filled Row Lower Part
    //    🟨 is the Start of filled Row inverted Xe, Ye Upper Part
    //    🟧 is the Start of filled Row inverted Xe, Ye Lower Part
    //    🟩 is the rest of filled pixels
    //    ⬛️ is the end Point of each horizontal drawing line

    push    {r0-r10,lr}

        // 1st we draw Start Line Center line
    mov     r7, #0                                                  // Ye = 0 Ye = Yextent to draw line up and down
    mov     r6, r0                                                  // Xe = Radius Xe = Xextent to draw line left and right
    bl      .drawLine                                               // draw first Horizontal line in the center Y
                                                                    // Xe = Xextent to draw line left and right (r(99) till 1)
                                                                    // Ye = Yextent to draw line up and down (1 till r(99) )
                                                                    
    mov     r7, #1                                                  // start Ye from 1 till r(99)

 .loop:
        // we draw 4 lines (up,down,top,bottom) all start from left to right
    bl      .drawUpDown
    // ---- xchg r6, r7
    mov     r9, r6          // r6 = 0  r7 = 8                       // Flipped Xe, Ye  so r0 = Xe   r6 = Ye (to draw top ad bottom)
    mov     r6, r7
    mov     r7, r9
    bl      .drawUpDown
    
    // ---- xchg r6, r7  ---
    mov     r9, r6          // r6 = 8  r7 = 0                       // Flipped r0 = Ye   r6 = Xe (Back to original)
    mov     r6, r7
    mov     r7, r9
                                                                    // Ye = radius so every time we increase the Ye with 1
                                                                    // we change the r like this(r = r - (2 * Ye) + 1)
                                                                    // example this circle r = 8 - (2 * 1) + 1 = 5

    sub     r0, r0, r7      // 5 - 2 = 3  (Ex: after set 2)         // r = r - Ye
    add     r7, r7, #1      // r7 = 3                               // Ye += 1
    sub     r0, r0, r7      // r0 = 3 - 3 = 0                       // r = r - Ye => r = r - (2 * Ye) + 1
    cmp     r0, r7          // r0 = 0 r7 = 3  0 < 3                 // if r > Ye so it is not yet time to shorten Xe sp lets draw
                                                                    // 4 more lines with the same Xe extent
    bgt     .doNotChangeXe  // jg = bgt signed jump if greater than
    
        // we reduce the X extent (Xe) to draw next set with shorter drawing length
    add     r0, r6, r0      // 0 + 8 = 8 (Ex: after set 2)          // r = r + Xe
    sub     r6, r6, #1      // r6 = 7                               // Xe -= 1
    add     r0, r6, r0      // 8 + 7 = 15 (start draw set 3)        // r = r + Xe => r += Xe r = r + (2 * Xe) - 1
    
 .doNotChangeXe:
    cmp     r6, r7          // r6 = 7, r7 = 3 => 7 > 3              // Repeat do another 4 lines until Xe < Ye
    bhs     .loop           // jae = bhs unsigned jump if higher or same

    pop     {r0-r10,pc}
    .ltorg


//bls for the drawing of lines
 .drawUpDown:
    push    {r0-r10,lr}
    bl      .drawLine                                               // draw up
    rsb     r7, r7, #0                                              // neg r7 => draw Down (flip Yn value)
    bl      .drawLine

    pop     {r0-r10,pc}

 .drawLine: // IN r6 = Xe r7 = Ye
    push    {r0-r10,lr}
    
    sub     r2, r2, r6      //r2 = 400 - 240 = 160                  // X = Xc - Xe
    sub     r3, r3, r7      //r3 = 240 - 0  = 240                   // Y = Yc - Ye
    mov     r1, r6          //r1 = 240
    lsl     r1, r1, #1      // imul r1, r1, #2
    add     r1, r1, #1      // r1 = 481                             // Pc = (Xe * 2) + 1 (pixel count to make a row)
    bl      makeRow

    pop     {r0-r10,pc}

//-------------------------------------------------------------------------------------------------------------
// Draw A Filled Circle using FPU Triangility Algorithm ( slower on Emulator but fast on Real)
// first we draw a dot on the rim of circle around the center (X0, Y0) using the angle of segment = 1 and start r = 0
// X = X0 + [r * cos(Çº)]
// Y = Y0 + [r * sin(Çº)]
// repeat those dots increasing Çº from 0 by adding 1º = 0.01745329 till 2π 3.14 x 2 = 6.28318531 (from 0 till 360 degree)
// when done we increase the circle radius by 1px
// then we repeat thease steps untill radius we apply above desired radius
// [X0] = StartX X0 (center X0)
// [Y0] = StartY Y0 (center Y0)
// [radius] =  radius
// r4 = Color
//
// Disclaimer:
// this function has limits in radius, it will use any radius mor than or equal to 12 , if you use less than 12 for a radius
// it would loop forever and never end. for less radius try draw_pie_a function instead.
//
// Important Note:
// In ARM Assembly Do Not Put The Function Internal Data Buffers inside The Function But Rather inside the .data Section
// This Important cause we notice the data inside The Function is very Weak and Exposed to be used by the CPU as temp ram
// especially if the .ltorg is Used.
// More Safer Way is to Add The Data only in the .data Section even if its related to Certain Function
// and you are free to add a dot before lable and/or add a remark comment to know which data related to which function.
//--------------------------------------------------------------------------------------------------------------------------
draw_pie_b:
    push            {r0-r10,lr}
    
    ldr             r2, =X0
    ldr             r2, [r2]
    ldr             r3, =.X0p
    str             r2, [r3]
    ldr             r2, =Y0
    ldr             r2, [r2]
    ldr             r3, =.Y0p
    str             r2, [r3]
    ldr             r2, =radius
    ldr             r2, [r2]
    ldr             r3, =.ra
    str             r2, [r3]

        // 1st: Calculate the circumference (how many dots on the surface)
        // .cf = |r * 2π| + 1
    vldr.f32        s0, =two∏       // fld dword [two∏]              // load 2π in s0

    ldr             r2, =.ra
    vldr            s1, [r2]        // (INT) fild dword [.ra]           // load radius .ra in s1
    vcvt.f32.s32    s1, s1          // (FLOAT) Convert signed integer in s1 to 32-bit float
    vmul.f32        s2, s1, s0      // fmul
    vcvt.s32.f32    s2, s2          // Convert Float 2 signed integer
    vmov            r3, s2          // (INT) fistp dword [.cf]           // out as integer
    add             r3, r3, #1
    ldr             r2, =.cf
    str             r3, [r2]        // (INT) inc dword [.cf]
    
    //Chk Point .cf = 0x5e4 (1508)
    
        // 2nd get the segment angel (angel between line connects from center to surface)
        // .seg = 360 / .cf  and for best accurecy devide the number by 2
        // .seg = (360 / .cf) / 2

    vldr            s0, =360        // (Int)
    vcvt.f32.s32    s0, s0          // (FLOAT) Convert signed integer in s0 to 32-bit float
    ldr             r2, =.cf
    vldr            s1, [r2]        // (INT)
    vcvt.f32.s32    s1, s1          // (FLOAT) Convert signed integer in s1 to 32-bit float
    vdiv.f32        s2, s0, s1      // fdiv 360 / .cf
    vldr.f32        s0, =0x3f000000 //0.5        // s0 = 1/2
    vmul.f32        s1, s2, s0      // fmul (360 / .cf) * 1/2 Aka fdiv (360 / .cf)/2
    ldr             r2, =.segº
    vstr.f32        s1, [r2]        // (FLOAT) fstp dword [.segº]
        
    //Chk Point .segº = 0.1193634 (0x3DF474CC)
     
        // 3rd: circle Loop
        // using this angel we draw several point at radius 0 at angle 0 then we increase angle
        // X = X0 + [r * cos(Çº)]
        // Y = Y0 + [r * sin(Çº)]
        // where X0,Y0 = center point (start of line)
        // and Çº is the angel
        // r is the radius (change it from 0 to length)

    ldr             r2, =.ri        //(INT)
    mov             r3, #0
    str             r3, [r2]        //(INT) you need to keep it integer
    
.loop_circle:

    ldr             r2, =.Øº            //(INT)
    vldr.f32        s0, =0x00000000     //0.0        //(FLOAT
    vstr.f32        s0, [r2]            //(FLoat) //mov dword [.Øº], 0

 .loop_dots:
    // convert degree [.Øº] to radian [.Çºp] = Øº * (∏ / 180) = Øº * 57.29577951
    vldr.f32        s0, =∏d         // (FLOAT) fld dword [∏d]   // (∏ / 180) = 0.01745329
    ldr             r2, =.Øº        // (FLOAT) No need to be converted
    vldr.f32        s1, [r2]        // fld dword [.Øº] // push ∏d to s1 and load Øº to s0
    vmul.f32        s2, s1, s0
    ldr             r2, =.Çºp
    vstr.f32        s2, [r2]        // (Float) s2 = .Çºp fstp dword [.Çºp]
    
    // getting newX and newY
    ldr             r2, =.Çºp        // (Float)
    ldr             r0, [r2]        // (Float) // Load Çº r0
    bl              vcos            // Compute cos(Çº) r0 = cos(Çº) in and out are FLOAT
    vmov.f32        s0, r0          // (FLoat) s0 = cos(Çº)
    ldr             r2, =.ri        // (INT) need to be converted
    vldr            s1, [r2]        // fld dword [.ri]
    vcvt.f32.s32    s1, s1          // (FLOAT) Convert signed integer in s1 to 32-bit float
    vmul.f32        s2, s1, s0      // (Float) s2 = ri * cos(Çº)

    ldr             r2, =.X0p        // (INT) need to be converted even if its zero
    vldr            s1, [r2]        // fld dword [.ri]
    vcvt.f32.s32    s1, s1          // (FLOAT) Convert signed integer in s1 to 32-bit float
    vadd.f32        s0, s1, s2      // (FLOAT)s0 = X0 + [ri * cos(Çº)]
    vcvt.s32.f32    s0, s0          // (INT) Convert Float 2 signed integer
    ldr             r2, =.newXc
    vstr            s0, [r2]        // (INT) fistp dword [.newXc] Store X = X0 + [ri * cos(Çº)]


    // Load angle again for sin(Ç)
    ldr             r2, =.Çºp        // (Float)
    ldr             r0, [r2]        // (Float) // Load Çº r0
    bl              vsin            // Compute sin(Çº) r0 = sin(Çº) in and out are FLOAT
    vmov.f32        s0, r0          // (FLoat) s0 = sin(Çº)
    ldr             r2, =.ri        // (INT) need to be converted
    vldr            s1, [r2]        // (FLOAT)fld dword [.ri]
    vcvt.f32.s32    s1, s1          // (FLOAT) Convert signed integer in s1 to 32-bit float
    vmul.f32        s2, s1, s0      // (Float) s2 = ri * sin(Çº)
    
    ldr             r2, =.Y0p        // (INT) need to be converted even if its zero
    vldr            s1, [r2]        // (INT) fld dword [.ri]
    vcvt.f32.s32    s1, s1          // (FLOAT) Convert signed integer in s1 to 32-bit float
    vadd.f32        s0, s1, s2      // (FLOAT) s0 = X0 + [ri * cos(Çº)]
    vcvt.s32.f32    s0, s0          // (INT) Convert Float 2 signed integer
    ldr             r2, =.newYc
    vstr            s0, [r2]        // (INT) fistp dword [.newXc] Store X = X0 + [ri * cos(Çº)]

        // Draw Point
    ldr             r2, =.newXc
    ldr             r2, [r2]
    ldr             r3, =.newYc
    ldr             r3, [r3]
    bl              draw_point
    
    //inc dword [.Øº]
    ldr             r2, =.segº          // (FLOAT)
    vldr.f32        s0, [r2]            // (FLOAT)
    

    ldr             r2, =.Øº            // (FLOAT)
    vldr.f32        s1, [r2]            // (FLOAT)
    vadd.f32        s2, s1, s0          // Add Øº with segment angel
    ldr             r2, =.Øº            // (FLOAT)
    vstr.f32        s2, [r2]            // (Float) Save total in Øº
    
    vcvt.s32.f32    s2, s2              // (INT) Convert Float 2 signed integer
    ldr             r2, =.comparetor    // (INT)
    vstr            s2, [r2]            // (INT) Save As INT In .comparetor
                                        // integer for comparison you cannot compare floats
                                        // so we make an integer for the compare
    ldr             r2, [r2]            // Get .comparetor
    
    cmp             r2, #360            // if we complete 360º
    ble             .loop_dots
    
    ldr             r2, =.ri            // (INT)
    ldr             r3, [r2]
    add             r3, r3, #1          // inc dword [.ri]
    str             r3, [r2]            // add r + 1 get ready for next point
    
    ldr             r2, =.ra             // (INT)
    ldr             r1, [r2]
        
    cmp             r3, r1              // cmp [.ri], [ra] // check if radius above the length to stop the loop
    ble             .loop_circle        // else keep looping
    
    pop             {r0-r10,pc}
    .ltorg

//-------------------------------------
// r0 = Number
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
write_digit:
    push    {r0-r7,lr}
    
    and     r0, #0xFF
    cmp     r0, #0
    bne     .sp
    mov     r6, r4
    ldr     r4, =backgroundColor
    bl      seg_a
    bl      seg_b
    bl      seg_c
    bl      seg_d
    bl      seg_e
    bl      seg_f
    bl      seg_g
    bl      seg_a1
    bl      seg_a2
    bl      seg_d1
    bl      seg_d2
    bl      seg_g1
    bl      seg_g2
    bl      seg_j
    bl      seg_k
    bl      seg_l
    bl      seg_m
    bl      seg_h
    bl      seg_i
    bl      seg_dot0
    bl      seg_dot3
    mov     r4, r6
    b       .endn

.sp:
    cmp     r0, #0x0020
    bne     .ex
    b       .endn

.ex:
    cmp     r0, #0x0021
    bne     .dq
    bl      seg_h
    bl      seg_dot2
    b       .endn

.dq:
    cmp     r0, #0x0022
    bne     .hs
    bl      seg_h
    bl      seg_b
    b       .endn

.hs:
    cmp     r0, #0x0023
    bne     .ds
    bl      seg_h
    bl      seg_b
    bl      seg_c
    bl      seg_i
    bl      seg_g
    bl      seg_d
    b       .endn

.ds:
    cmp     r0, #0x0024
    bne     .pr
    bl      seg_a
    bl      seg_d
    bl      seg_f
    bl      seg_g
    bl      seg_c
    bl      seg_h
    bl      seg_i
    b       .endn

.pr:
    cmp     r0, #0x0025
    bne     .an
    bl      seg_a1
    bl      seg_d2
    bl      seg_f
    bl      seg_g1
    bl      seg_g2
    bl      seg_c
    bl      seg_h
    bl      seg_i
    bl      seg_k
    bl      seg_m
    b       .endn

.an:
    cmp     r0, #0x0026
    bne     .qt
    bl      seg_a1
    bl      seg_d
    bl      seg_j
    bl      seg_l
    bl      seg_h
    bl      seg_g1
    bl      seg_e
    b       .endn

.qt:
    cmp     r0, #0x0027
    bne     .b1
    bl      seg_h
    b       .endn

.b1:
    cmp     r0, #0x0028
    bne     .b2
    bl      seg_k
    bl      seg_l
    b       .endn

.b2:
    cmp     r0, #0x0029
    bne     .st
    bl      seg_j
    bl      seg_m
    b       .endn

.st:
    cmp     r0, #0x002A
    bne     .pl
    bl      seg_k
    bl      seg_l
    bl      seg_j
    bl      seg_m
    bl      seg_g1
    bl      seg_g2
    bl      seg_h
    bl      seg_i
    b       .endn

.pl:
    cmp     r0, #0x002B
    bne     .cm
    bl      seg_g1
    bl      seg_g2
    bl      seg_h
    bl      seg_i
    b       .endn

.cm:
    cmp     r0, #0x002C
    bne     .mi
    bl      seg_m
    b       .endn

.mi:
    cmp     r0, #0x002D
    bne     .dt
    bl      seg_g
    b       .endn

.dt:
    cmp     r0, #0x002E
    bne     .sl
    bl      seg_dot3
    b       .endn

.sl:
    cmp     r0, #0x002F
    bne     .0
    bl      seg_k
    bl      seg_m
    b       .endn
    
.0: cmp     r0, #0x0030
    bne     .1
    bl      seg_a
    bl      seg_b
    bl      seg_c
    bl      seg_d
    bl      seg_e
    bl      seg_f
    bl      seg_k
    bl      seg_m
    b       .endn

.1: cmp     r0, #0x0031
    bne     .2
    bl      seg_b
    bl      seg_c
    bl      seg_k
    b       .endn

.2: cmp     r0, #0x0032
    bne     .3
    bl      seg_a
    bl      seg_b
    bl      seg_d
    bl      seg_g
    bl      seg_e
    b       .endn

.3: cmp     r0, #0x0033
    bne     .4
    bl      seg_a
    bl      seg_b
    bl      seg_c
    bl      seg_d
    bl      seg_g
    b       .endn

.4: cmp     r0, #0x0034
    bne     .5
    bl      seg_b
    bl      seg_c
    bl      seg_g
    bl      seg_f
    b       .endn

.5: cmp     r0, #0x0035
    bne     .6
    bl      seg_a
    bl      seg_d
    bl      seg_f
    bl      seg_g
    bl      seg_c
    b       .endn

.6: cmp     r0, #0x0036
    bne     .7
    bl      seg_a
    bl      seg_c
    bl      seg_d
    bl      seg_e
    bl      seg_f
    bl      seg_g
    b       .endn
    
.7: cmp     r0, #0x0037
    bne     .8
    bl      seg_a
    bl      seg_b
    bl      seg_c
    b       .endn
    
.8: cmp     r0, #0x0038
    bne     .9
    bl      seg_a
    bl      seg_b
    bl      seg_c
    bl      seg_d
    bl      seg_e
    bl      seg_f
    bl      seg_g
    b       .endn

.9: cmp     r0, #0x0039
    bne     .2d
    bl      seg_a
    bl      seg_b
    bl      seg_c
    bl      seg_d
    bl      seg_f
    bl      seg_g
    b       .endn

.2d:
    cmp     r0, #0x003A
    bne     .sc
    bl      seg_dot1
    bl      seg_dot2
    b       .endn

.sc:
    cmp     r0, #0x003B
    bne     .gt
    bl      seg_m
    bl      seg_dot1
    b       .endn

.gt:
    cmp     r0, #0x003C
    bne     .eq
    bl      seg_g1
    bl      seg_k
    bl      seg_l
    b       .endn

.eq:
    cmp     r0, #0x003D
    bne     .lt
    bl      seg_g
    bl      seg_d
    b       .endn

.lt:
    cmp     r0, #0x003E
    bne     .qm
    bl      seg_g2
    bl      seg_j
    bl      seg_m
    b       .endn

.qm:
    cmp     r0, #0x003F
    bne     .at
    bl      seg_a
    bl      seg_b
    bl      seg_g2
    bl      seg_i
    bl      seg_dot3
    b       .endn

.at:
    cmp     r0, #0x0040
    bne     .A
    bl      seg_a
    bl      seg_b
    bl      seg_g2
    bl      seg_h
    bl      seg_d
    bl      seg_e
    bl      seg_f
    b       .endn

.A: cmp     r0, #0x0041
    bne     .B
    bl      seg_a
    bl      seg_b
    bl      seg_c
    bl      seg_f
    bl      seg_e
    bl      seg_g
    b       .endn

.B: cmp     r0, #0x0042
    bne     .C
    bl      seg_a1
    bl      seg_a2
    bl      seg_b
    bl      seg_c
    bl      seg_d1
    bl      seg_d2
    bl      seg_h
    bl      seg_i
    bl      seg_g2
    b       .endn

.C: cmp     r0, #0x0043
    bne     .D
    bl      seg_a
    bl      seg_d
    bl      seg_f
    bl      seg_e
    b       .endn

.D: cmp     r0, #0x0044
    bne     .E
    bl      seg_a1
    bl      seg_a2
    bl      seg_b
    bl      seg_c
    bl      seg_d1
    bl      seg_d2
    bl      seg_h
    bl      seg_i
    b       .endn

.E: cmp     r0, #0x0045
    bne     .F
    bl      seg_a
    bl      seg_d
    bl      seg_g1
    bl      seg_f
    bl      seg_e
    b       .endn

.F: cmp     r0, #0x0046
    bne     .G
    bl      seg_a
    bl      seg_g1
    bl      seg_f
    bl      seg_e
    b       .endn

.G: cmp     r0, #0x0047
    bne     .H
    bl      seg_a
    bl      seg_c
    bl      seg_d
    bl      seg_e
    bl      seg_f
    bl      seg_g2
    b       .endn

.H: cmp     r0, #0x0048
    bne     .I
    bl      seg_b
    bl      seg_c
    bl      seg_e
    bl      seg_f
    bl      seg_g
    b       .endn

.I: cmp     r0, #0x0049
    bne     .J
    bl      seg_h
    bl      seg_i
    bl      seg_a
    bl      seg_d
    b       .endn

.J: cmp     r0, #0x004A
    bne     .K
    bl      seg_b
    bl      seg_c
    bl      seg_d
    bl      seg_e
    b       .endn

.K: cmp     r0, #0x004B
    bne     .L
    bl      seg_k
    bl      seg_i
    bl      seg_g1
    bl      seg_e
    bl      seg_f
    b       .endn

.L: cmp     r0, #0x004C
    bne     .M
    bl      seg_d
    bl      seg_e
    bl      seg_f
    b       .endn

.M: cmp     r0, #0x004D
    bne     .N
    bl      seg_b
    bl      seg_c
    bl      seg_e
    bl      seg_f
    bl      seg_j
    bl      seg_k
    b       .endn

.N: cmp     r0, #0x004E
    bne     .O
    bl      seg_b
    bl      seg_c
    bl      seg_e
    bl      seg_f
    bl      seg_j
    bl      seg_l
    b       .endn

.O: cmp     r0, #0x004F
    bne     .P
    bl      seg_a
    bl      seg_b
    bl      seg_c
    bl      seg_d
    bl      seg_e
    bl      seg_f
    b       .endn

.P: cmp     r0, #0x0050
    bne     .Q
    bl      seg_a
    bl      seg_b
    bl      seg_e
    bl      seg_f
    bl      seg_g
    b       .endn

.Q: cmp     r0, #0x0051
    bne     .R
    bl      seg_a
    bl      seg_b
    bl      seg_c
    bl      seg_d
    bl      seg_e
    bl      seg_f
    bl      seg_l
    b       .endn

.R: cmp     r0, #0x0052
    bne     .S
    bl      seg_a
    bl      seg_b
    bl      seg_l
    bl      seg_f
    bl      seg_e
    bl      seg_g
    b       .endn

.S: cmp     r0, #0x0053
    bne     .T
    bl      seg_a
    bl      seg_c
    bl      seg_d
    bl      seg_j
    bl      seg_g2
    b       .endn

.T: cmp     r0, #0x0054
    bne     .U
    bl      seg_a
    bl      seg_h
    bl      seg_i
    b       .endn

.U: cmp     r0, #0x0055
    bne     .V
    bl      seg_b
    bl      seg_c
    bl      seg_d
    bl      seg_e
    bl      seg_f
    b       .endn

.V: cmp     r0, #0x0056
    bne     .W
    bl      seg_k
    bl      seg_m
    bl      seg_f
    bl      seg_e
    b       .endn

.W: cmp     r0, #0x0057
    bne     .X
    bl      seg_b
    bl      seg_c
    bl      seg_e
    bl      seg_f
    bl      seg_l
    bl      seg_m
    b       .endn

.X: cmp     r0, #0x0058
    bne     .Y
    bl      seg_j
    bl      seg_k
    bl      seg_l
    bl      seg_m
    b       .endn

.Y: cmp     r0, #0x0059
    bne     .Z
    bl      seg_b
    bl      seg_c
    bl      seg_d
    bl      seg_f
    bl      seg_g
    b       .endn

.Z: cmp     r0, #0x005A
    bne     .b3
    bl      seg_a
    bl      seg_k
    bl      seg_m
    bl      seg_d
    b       .endn

.b3:
    cmp     r0, #0x005B
    bne     .dh
    bl      seg_a2
    bl      seg_h
    bl      seg_i
    bl      seg_d2
    b       .endn

.dh:
    cmp     r0, #0x005C
    bne     .b4
    bl      seg_j
    bl      seg_l
    b       .endn

.b4:
    cmp     r0, #0x005D
    bne     .eb
    bl      seg_a1
    bl      seg_h
    bl      seg_i
    bl      seg_d1
    b       .endn

.eb:
    cmp     r0, #0x005E
    bne     .us
    bl      seg_l
    bl      seg_m
    b       .endn
.us:
    cmp     r0, #0x005F
    bne     .co
    bl      seg_d
    b       .endn

.co:
    cmp     r0, #0x0060
    bne     .a
    bl      seg_j
    b       .endn

.a: cmp     r0, #0x0061
    bne     .b
    bl      seg_i
    bl      seg_g1
    bl      seg_e
    bl      seg_d1
    bl      seg_d2
    b       .endn

.b: cmp     r0, #0x0062
    bne     .c
    bl      seg_f
    bl      seg_e
    bl      seg_g1
    bl      seg_d1
    bl      seg_i
    b       .endn

.c: cmp     r0, #0x0063
    bne     .d
    bl      seg_g1
    bl      seg_d1
    bl      seg_e
    b       .endn

.d: cmp     r0, #0x0064
    bne     .e
    bl      seg_b
    bl      seg_c
    bl      seg_g2
    bl      seg_d2
    bl      seg_i
    b       .endn

.e: cmp     r0, #0x0065
    bne     .f
    bl      seg_g1
    bl      seg_m
    bl      seg_e
    bl      seg_d1
    b       .endn

.f: cmp     r0, #0x0066
    bne     .g
    bl      seg_a2
    bl      seg_h
    bl      seg_i
    bl      seg_g1
    bl      seg_g2
    b       .endn

.g: cmp     r0, #0x0067
    bne     .h
    bl      seg_a1
    bl      seg_h
    bl      seg_i
    bl      seg_d1
    bl      seg_g1
    bl      seg_f
    b       .endn

.h: cmp     r0, #0x0068
    bne     .i
    bl      seg_i
    bl      seg_g1
    bl      seg_e
    bl      seg_f
    b       .endn

.i: cmp     r0, #0x0069
    bne     .j
    bl      seg_i
    bl      seg_dot1
    b       .endn

.j: cmp     r0, #0x006A
    bne     .k
    bl      seg_h
    bl      seg_i
    bl      seg_d1
    bl      seg_e
    bl      seg_dot0
    b       .endn

.k: cmp     r0, #0x006B
    bne     .l
    bl      seg_k
    bl      seg_l
    bl      seg_h
    bl      seg_i
    b       .endn

.l: cmp     r0, #0x006C
    bne     .m
    bl      seg_e
    bl      seg_f
    b       .endn

.m: cmp     r0, #0x006D
    bne     .n
    bl      seg_c
    bl      seg_e
    bl      seg_i
    bl      seg_g1
    bl      seg_g2
    b       .endn

.n: cmp     r0, #0x006E
    bne     .o
    bl      seg_e
    bl      seg_i
    bl      seg_g1
    b       .endn

.o: cmp     r0, #0x006F
    bne     .p
    bl      seg_e
    bl      seg_i
    bl      seg_g1
    bl      seg_d1
    b       .endn

.p: cmp     r0, #0x0070
    bne     .q
    bl      seg_a1
    bl      seg_h
    bl      seg_e
    bl      seg_f
    bl      seg_g1
    b       .endn

.q: cmp     r0, #0x0071
    bne     .r
    bl      seg_a1
    bl      seg_g1
    bl      seg_f
    bl      seg_h
    bl      seg_i
    b       .endn

.r: cmp     r0, #0x0072
    bne     .s
    bl      seg_g1
    bl      seg_e
    b       .endn

.s: cmp     r0, #0x0073
    bne     .t
    bl      seg_a1
    bl      seg_f
    bl      seg_d1
    bl      seg_i
    bl      seg_g1
    b       .endn

.t: cmp     r0, #0x0074
    bne     .u
    bl      seg_g1
    bl      seg_d1
    bl      seg_e
    bl      seg_f
    b       .endn

.u: cmp     r0, #0x0075
    bne     .v
    bl      seg_i
    bl      seg_d1
    bl      seg_e
    b       .endn

.v: cmp     r0, #0x0076
    bne     .w
    bl      seg_m
    bl      seg_e
    b       .endn

.w: cmp     r0, #0x0077
    bne     .x
    bl      seg_c
    bl      seg_e
    bl      seg_l
    bl      seg_m
    b       .endn

.x: cmp     r0, #0x0078
    bne     .y
    bl      seg_j
    bl      seg_k
    bl      seg_l
    bl      seg_m
    b       .endn

.y: cmp     r0, #0x0079
    bne     .z
    bl      seg_b
    bl      seg_c
    bl      seg_d2
    bl      seg_h
    bl      seg_g2
    b       .endn

.z: cmp     r0, #0x007A
    bne     .b5
    bl      seg_g1
    bl      seg_m
    bl      seg_d1
    b       .endn

.b5: cmp     r0, #0x007B
    bne     .br
    bl      seg_a2
    bl      seg_d2
    bl      seg_g1
    bl      seg_h
    bl      seg_i
    b       .endn

.br: cmp     r0, #0x007C
    bne     .b6
    bl      seg_h
    bl      seg_i
    b       .endn

.b6: cmp     r0, #0x007D
    bne     .wa
    bl      seg_a1
    bl      seg_d1
    bl      seg_g2
    bl      seg_h
    bl      seg_i
    b       .endn

.wa: cmp     r0, #0x007E
    bne     .noCanDo
    bl      seg_k
    bl      seg_g
    bl      seg_m
    b       .endn

.noCanDo:
    bl      seg_b
    bl      seg_c
    bl      seg_e
    bl      seg_f
    bl      seg_a
    bl      seg_d
    bl      seg_g
    bl      seg_h
    bl      seg_i
    bl      seg_j
    bl      seg_k
    bl      seg_l
    bl      seg_m
    
.endn:
    pop     {r0-r7,pc}
    .ltorg

//------------------------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//------------------------------------------------------
draw_dot:
    push    {r0-r7,lr}

    mov     r1, #3              // length of the V Segment
    lsr     r1, r1, r5
    cmp     r5, #1
    bllt    makeColumn

    add     r2, r2, #1          // go to next column X
    sub     r3, r3, #1          // make sure you start abit up
    add     r1, r1, #2          // mov     r1, #5              // length of the V Segment
    cmp     r5, #2
    bllt    makeColumn

    add     r2, r2, #1          // go to next column X
    sub     r3, r3, #1          // make sure you start more up
    add     r1, r1, #2          // mov     r1, #7              // length of the V Segment
    cmp     r5, #2
    subeq   r1, r1, #3
    bl      makeColumn

    add     r2, r2, #1          // go to next column X
    add     r3, r3, #1          // make sure you start abit down
    sub     r1, r1, #2          // mov     r1, #5              // length of the V Segment
    cmp     r5, #2
    bllt    makeColumn

    add     r2, r2, #1          // go to next column X
    add     r3, r3, #1          // urn to original Y Position
    sub     r1, r1, #2          // mov     r1, #3              // length of the V Segment
    cmp     r5, #1
    bllt    makeColumn

    pop     {r0-r7,pc}
    .ltorg


//------------------------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//------------------------------------------------------
two_dots:
    push    {r0-r7,lr}

    mov     r6, #19
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 19
    cmp     r5, #0
    addne   r2, r2, r5
    addne   r2, r2, r5
    mov     r7, #15
    lsr     r7, r7, r5
    add     r3, r3, r7          // Y += 60
    cmp     r5, #2
    addeq   r3, r3, r5
    bl      draw_dot


    mov     r7, #35
    lsr     r7, r7, r5
    add     r3, r3, r7          // Y += 60
    cmp     r5, #0
    addne   r3, r3, #3
    cmp     r5, #2
    addeq   r3, r3, #2
    bl      draw_dot

    pop     {r0-r7,pc}
    .ltorg


//------------------------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//------------------------------------------------------
seg_dot0:
    push    {r0-r7,lr}

    mov     r6, #19
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 19
    cmp     r5, #0
    addne   r2, r2, r5
    addne   r2, r2, r5
    sub     r3, r3, #6          // Y -= 6
    cmp     r5, #0
    addne   r3, r3, r5
    cmp     r5, #2
    addeq   r3, r3, #1
    bl      draw_dot
    
    pop     {r0-r7,pc}
    .ltorg

//------------------------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//------------------------------------------------------
seg_dot1:
    push    {r0-r7,lr}

    mov     r6, #19
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 19
    cmp     r5, #0
    addne   r2, r2, r5
    addne   r2, r2, r5
    mov     r7, #15
    lsr     r7, r7, r5
    add     r3, r3, r7          // Y += 60
    cmp     r5, #2
    addeq   r3, r3, r5
    bl      draw_dot

    pop     {r0-r7,pc}
    .ltorg

//------------------------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//------------------------------------------------------
seg_dot2:
    push    {r0-r7,lr}

    mov     r6, #19
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 19
    cmp     r5, #0
    addne   r2, r2, r5
    addne   r2, r2, r5
    mov     r7, #35
    lsr     r7, r7, r5
    add     r3, r3, r7          // Y += 60
    cmp     r5, #0
    addne   r3, r3, #10
    bl      draw_dot

    pop     {r0-r7,pc}
    .ltorg

//------------------------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//------------------------------------------------------
seg_dot3:
    push    {r0-r7,lr}

    mov     r6, #19
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 19
    cmp     r5, #0
    addne   r2, r2, r5
    addne   r2, r2, r5
    mov     r7, #70
    lsr     r7, r7, r5
    add     r3, r3, r7          // Y += 60
    cmp     r5, #0
    addne   r3, r3, #4
    cmp     r5, #2
    addeq   r3, r3, #5
    bl      draw_dot
    
    pop     {r0-r7,pc}
    .ltorg

//------------------------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//------------------------------------------------------
seg_a:
    push    {r0-r7,lr}

    add     r2, r2, #6          // X += 6
    sub     r3, r3, #6          // Y -= 6
    bl      draw_seg_h
    
    pop     {r0-r7,pc}
    .ltorg

//-------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_b:
    push    {r0-r7,lr}

    mov     r6, #38
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 35 + 3
    cmp     r5, #0              // Visual Fine Tuning
    addne   r2, r2, r5
    addne   r2, r2, r5
    addne   r2, r2, r5
    bl      draw_seg_v
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_c:
    push    {r0-r7,lr}

    mov     r6, #38
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 35 + 3
    cmp     r5, #0              // Visual Fine Tuning
    addne   r2, r2, r5
    addne   r2, r2, r5
    addne   r2, r2, r5
    mov     r7, #37
    lsr     r7, r7, r5
    add     r3, r3, r7          // Y += 37
    cmp     r5, #0              // Visual Fine Tuning
    addne   r3, r3, r5
    addne   r3, r3, r5
    bl      draw_seg_v
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_d:
    push    {r0-r7,lr}

    add     r2, r2, #6          // X += 6
    mov     r7, #68
    lsr     r7, r7, r5
    add     r3, r3, r7          // Y += 33 * 2
    cmp     r5, #0              // Visual Fine Tuning
    addne   r3, r3, r5
    addne   r3, r3, r5
    bl      draw_seg_h
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_e:
    push    {r0-r7,lr}

    mov     r7, #37
    lsr     r7, r7, r5
    add     r3, r3, r7          // Y += 37
    cmp     r5, #0              // Visual Fine Tuning
    addne   r3, r3, r5
    addne   r3, r3, r5
    bl      draw_seg_v
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_f:
    push    {r0-r7,lr}

    bl      draw_seg_v

    pop     {r0-r7,pc}
    .ltorg

//-------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
//-------------------------------------
seg_g:
    push    {r0-r7,lr}

    add     r2, r2, #6          // X += 6
    mov     r7, #31
    lsr     r7, r7, r5
    add     r3, r3, r7         // Y += 34 - 3
    bl      draw_seg_h
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 16 Segment Module (from left)
// r3 = StartY for the 16 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_a1:
    push    {r0-r7,lr}

    add     r2, r2, #6          // X += 6
    sub     r3, r3, #6          // Y -= 6
    bl      draw_half_seg_h
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 16 Segment Module (from left)
// r3 = StartY for the 16 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_a2:
    push    {r0-r7,lr}


    mov     r6, #25
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 25
    cmp     r5, #0              // Visual Fine Tuning
    addne   r2, r2, r5
    addne   r2, r2, r5
    addne   r2, r2, r5
    sub     r3, r3, #6          // Y -= 6
    bl      draw_half_seg_h
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 16 Segment Module (from left)
// r3 = StartY for the 16 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_d1:
    push    {r0-r7,lr}

    add     r2, r2, #6          // X += 6
    mov     r7, #68
    lsr     r7, r7, r5
    add     r3, r3, r7          // Y += 33 * 2
    cmp     r5, #0              // Visual Fine Tuning
    addne   r3, r3, r5
    addne   r3, r3, r5
    bl      draw_half_seg_h
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 16 Segment Module (from left)
// r3 = StartY for the 16 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_d2:
    push    {r0-r7,lr}

    mov     r6, #25
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 25
    cmp     r5, #0              // Visual Fine Tuning
    addne   r2, r2, r5
    addne   r2, r2, r5
    addne   r2, r2, r5
    mov     r7, #68
    lsr     r7, r7, r5
    add     r3, r3, r7          // Y += 33 * 2
    cmp     r5, #0              // Visual Fine Tuning
    addne   r3, r3, r5
    addne   r3, r3, r5
    bl      draw_half_seg_h
    
    pop     {r0-r7,pc}
    .ltorg



//-------------------------------------
// r2 = StartX for the 16 Segment Module (from left)
// r3 = StartY for the 16 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_g1:
    push    {r0-r7,lr}

    add     r2, r2, #6          // X += 6
    mov     r7, #31
    lsr     r7, r7, r5
    add     r3, r3, r7         // Y += 31 - 3
    bl      draw_half_seg_h
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 16 Segment Module (from left)
// r3 = StartY for the 16 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_g2:
    push    {r0-r7,lr}

    mov     r6, #25
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 25
    cmp     r5, #0              // Visual Fine Tuning
    addne   r2, r2, r5
    addne   r2, r2, r5
    addne   r2, r2, r5
    mov     r7, #31
    lsr     r7, r7, r5
    add     r3, r3, r7         // Y += 31 - 3
    bl      draw_half_seg_h
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_h:
    push    {r0-r7,lr}
    
    mov     r6, #19
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 19
    cmp     r5, #0              // Visual Fine Tuning
    addne   r2, r2, r5
    addne   r2, r2, r5
    bl      draw_seg_v
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_i:
    push    {r0-r7,lr}

    mov     r6, #19
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 19
    cmp     r5, #0              // Visual Fine Tuning
    addne   r2, r2, r5
    addne   r2, r2, r5
    mov     r7, #37
    lsr     r7, r7, r5
    add     r3, r3, r7         // Y += 37
    cmp     r5, #0              // Visual Fine Tuning
    addne   r3, r3, r5
    addne   r3, r3, r5
    bl      draw_seg_v
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 7 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_j:
    push    {r0-r7,lr}

    add     r2, r2, #6          // X += 6
    bl      draw_seg_t1         // Draw Tilt Segment type 1
    
    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 16 Segment Module (from left)
// r3 = StartY for the 7 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_k:
    push    {r0-r7,lr}

    mov     r6, #33
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 33
    cmp     r5, #0              // Visual Fine Tuning
    addne   r2, r2, r5
    addne   r2, r2, r5
    addne   r2, r2, r5
    bl      draw_seg_t2         // Draw Tilt Segment type 2

    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 16 Segment Module (from left)
// r3 = StartY for the 16 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_l:
    push    {r0-r7,lr}

    mov     r6, #25
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 25
    cmp     r5, #0              // Visual Fine Tuning
    addne   r2, r2, r5
    addne   r2, r2, r5
    cmp     r5, #1
    subeq   r2, r2, #1
    cmp     r5, #2
    addeq   r2, r2, r5
    mov     r7, #37
    lsr     r7, r7, r5
    add     r3, r3, r7         // Y += 37
    cmp     r5, #1
    subeq   r3, r3, r5
    cmp     r5, #2
    addeq   r3, r3, #3
    bl      draw_seg_t1         // Draw Tilt Segment type 1

    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX for the 16 Segment Module (from left)
// r3 = StartY for the 16 Segment Module (from top)
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
seg_m:
    push    {r0-r7,lr}

    mov     r6, #14
    lsr     r6, r6, r5
    add     r2, r2, r6          // X += 14
    cmp     r5, #0              // Visual Fine Tuning
    addne   r2, r2, r5
    addne   r2, r2, #1
    addne   r2, r2, #1
    addne   r2, r2, #1
    cmp     r5, #1
    addeq   r2, r2, #1
    mov     r7, #37
    lsr     r7, r7, r5
    add     r3, r3, r7         // Y += 37
    cmp     r5, #1
    subeq   r3, r3, r5
    cmp     r5, #2
    addeq   r3, r3, #3
    bl      draw_seg_t2         // Draw Tilt Segment type 2

    pop     {r0-r7,pc}
    .ltorg



//-------------------------------------
// r2 = StartX
// r3 = StartY
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
draw_seg_v:
    push    {r0-r7,lr}

    mov     r1, #30         // length of the V Segment
    lsr     r1, r1, r5
    cmp     r5, #1
    bllt    makeColumn

    add     r2, r2, #1      // go to next column X
    sub     r3, r3, #1      // make sure you start abit up
    add     r1, r1, #2      //mov     r1, #32         // length of the V Segment
    cmp     r5, #2
    bllt    makeColumn

    add     r2, r2, #1      // go to next column X
    sub     r3, r3, #1      // make sure you start more up
    add     r1, r1, #2      //mov     r1, #34         // length of the V Segment
    bl      makeColumn

    add     r2, r2, #1      // go to next column X
    add     r3, r3, #1      // make sure you start abit down
    sub     r1, r1, #2      //mov     r1, #32          // length of the V Segment
    cmp     r5, #2
    bllt    makeColumn

    add     r2, r2, #1      // go to next column X
    add     r3, r3, #1      // urn to original Y Position
    sub     r1, r1, #2      //mov     r1, #30          // length of the V Segment
    cmp     r5, #1
    bllt    makeColumn

    pop     {r0-r7,pc}
    .ltorg



//-------------------------------------
// r2 = StartX
// r3 = StartY
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
draw_seg_h:
    push    {r0-r7,lr}

    mov     r1, #31         // length of the H Segment
    lsr     r1, r1, r5      // Divide length by size 2⁰, 2¹, 2² aka length / (1/2/4)
    cmp     r5, #1
    bllt    makeRow

    add     r3, r3, #1      // go to next row Y
    sub     r2, r2, #1      // make sure you start abit before
    add     r1, r1, #2      //mov     r1, #33         // length of the H Segment
    cmp     r5, #2
    bllt    makeRow

    add     r3, r3, #1      // go to next row Y
    sub     r2, r2, #1      // make sure you start more before
    add     r1, r1, #2      //mov     r1, #35  // length of the H Segment
    bl      makeRow

    add     r3, r3, #1      // go to next row Y
    add     r2, r2, #1      // make sure you start abit before
    sub     r1, r1, #2      // mov     r1, #33         // length of the H Segment
    cmp     r5, #2
    bllt    makeRow

    add     r3, r3, #1      // go to next row Y
    add     r2, r2, #1      // urn to original X Position
    sub     r1, r1, #2      // mov     r1, #31         // length of the H Segment
    cmp     r5, #1
    bllt    makeRow

    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX
// r3 = StartY
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
draw_half_seg_h:
    push    {r0-r7,lr}

    mov     r1, #12         // length of the H Segment
    lsr     r1, r1, r5      // Divide length by size 2⁰, 2¹, 2² aka length / (1/2/4)
    cmp     r5, #1
    bllt    makeRow

    add     r3, r3, #1      // go to next row Y
    sub     r2, r2, #1      // make sure you start abit before
    add     r1, r1, #2      //mov     r1, #14         // length of the H Segment
    cmp     r5, #2
    bllt    makeRow

    add     r3, r3, #1      // go to next row Y
    sub     r2, r2, #1      // make sure you start more before
    add     r1, r1, #2      //mov     r1, #16         // length of the H Segment
    bl      makeRow

    add     r3, r3, #1      // go to next row Y
    add     r2, r2, #1      // make sure you start abit before
    sub     r1, r1, #2      //mov     r1, #14         // length of the H Segment
    cmp     r5, #2
    bllt    makeRow

    add     r3, r3, #1      // go to next row Y
    add     r2, r2, #1      // urn to original X Position
    sub     r1, r1, #2      //mov     r1, #12         // length of the H Segment
    cmp     r5, #1
    bllt    makeRow

    pop     {r0-r7,pc}
    .ltorg


//-------------------------------------
// r2 = StartX
// r3 = StartY
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
draw_seg_t1:
    push    {r0-r10,lr}
    
    cmp     r5, #0
    subne   r2, r2, #1

    mov     r8, #5
.loopT1:
    mov     r1, #4          // length of the H Segment
    lsr     r1, r1, r5      // Divide length by size 2⁰, 2¹, 2² aka length / (1/2/4)
    cmp     r5, #1
    bllt    makeRow

    cmp     r5, #1
    subeq   r3, r3, #2      // fix for the scale 1/2 and 1/4
    cmp     r5, #2
    addlt   r3, r3, #1      // go to next row Y
    bllt    makeRow

    cmp     r5, #2
    subeq   r3, r3, #2      // fix for the scale 1/2 and 1/4
    add     r3, r3, #1      // go to next row Y
    bl      makeRow

    add     r3, r3, #1      // go to next row Y
    bl      makeRow

    cmp     r5, #2
    addlt   r3, r3, #1      // go to next row Y
    bllt    makeRow

    cmp     r5, #1
    addlt   r3, r3, #1      // go to next row Y
    bllt    makeRow

    add     r2, r2, #1
    cmp     r5, #2
    addlt   r2, r2, #1
    add     r3, r3, #1
    cmp     r5, #0
    addne   r3, r3, #1
    subs    r8, r8, #1
    bne     .loopT1

    pop     {r0-r10,pc}
    .ltorg


//-------------------------------------
// r2 = StartX
// r3 = StartY
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//-------------------------------------
draw_seg_t2:
    push    {r0-r10,lr}

    cmp     r5, #0
    addne   r2, r2, #1

    mov     r8, #5
.loopT2:
    mov     r1, #4  // length of the H Segment
    lsr     r1, r1, r5      // Divide length by size 2⁰, 2¹, 2² aka length / (1/2/4)
    cmp     r5, #1
    bllt    makeRow

    cmp     r5, #1
    subeq   r3, r3, #2      // fix for the scale 1/2 and 1/4
    cmp     r5, #2
    addlt   r3, r3, #1      // go to next row Y
    bllt    makeRow

    cmp     r5, #2
    subeq   r3, r3, #2      // fix for the scale 1/2 and 1/4
    add     r3, r3, #1      // go to next row Y
    bl      makeRow

    add     r3, r3, #1      // go to next row Y
    bl      makeRow

    cmp     r5, #2
    addlt   r3, r3, #1      // go to next row Y
    bllt    makeRow

    cmp     r5, #1
    addlt   r3, r3, #1      // go to next row Y
    bllt    makeRow

    sub     r2, r2, #1
    cmp     r5, #2
    sublt   r2, r2, #1
    add     r3, r3, #1
    cmp     r5, #0
    addne   r3, r3, #1
    subs    r8, r8, #1
    bne     .loopT2

    pop     {r0-r10,pc}
    .ltorg

//-------------------------------------
// r2 = StartX
// r3 = StartY
// r1 = length of column
// r4 = Color
//-------------------------------------
makeColumn:
    push    {r0-r7,lr}

.doColumn:
    bl      draw_point
    add     r3, r3, #1
    subs    r1, r1, #1
    bne     .doColumn

    pop     {r0-r7,pc}
    .ltorg

//-------------------------------------
// r2 = StartX
// r3 = StartY
// r1 = length of row
// r4 = Color
//-------------------------------------
makeRow:
    push    {r0-r7,lr}

.doRow:
    bl      draw_point
    add     r2, r2, #1
    subs    r1, r1, #1
    bne     .doRow

    pop     {r0-r7,pc}
    .ltorg

//-------------------------------------
// Assume r0 contains the 32 bits to convert (0 - 4294967295) (0x00 - 0xffffffff)
// Destination buffer for 40-bytes UTF16 string: 'result_buffer' (40 UTF16)
//   Input:
// r0 = 4 bytes 32 bit
//   Output:
// [outputDec] = UTF-16
//-------------------------------------
Dec2UTF32:
    push    {r0-r7,lr}

    //ldr     r0, =1234056789       //Was For Test
    // empty the output buffer
    ldr     r1, =outputDec
    ldr     r2, =0x00000030       @ Four ASCII '0's (0x30 each)

    str     r2, [r1, #0x0]          @ Store first 4 bytes ("0000")
    str     r2, [r1, #0x4]          @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0x8]          @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0xC]          @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0x10]         @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0x14]         @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0x18]         @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0x1C]         @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0x20]         @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0x24]         @ Store next 4 bytes  ("0000")

    add     r1, r1, #0x28         // Put r1 index at the last digit in the out buffer
.conv_loop:
    @ --- FAST DIVISION BY 10 (r0 / 10) ---
    @ Logic: (r0 * 0xCCCCCCCD) >> 35
    ldr     r2, =0xCCCCCCCD
    umull   r4, r5, r0, r2      @ r5 = High 32 bits of (r0 * 0xCCCCCCCD)
    mov     r4, r5, lsr #3      @ r4 = Quotient (r0 / 10)

    @ --- CALCULATE REMAINDER (r0 % 10) ---
    @ Remainder = r0 - (Quotient * 10)
    mov     r2, #10
    mls     r3, r4, r2, r0     @ r3 = Digit (0-9)
    mov     r0, r4             @ Update r0 with quotient for next loop

    @ --- STORE AS UTF-16 ---
    add     r3, r3, #0x30       @ Convert 0-9 to ASCII '0'-'9' (0x30-0x39)
    strb    r3, [r1]            @ Store 16-bit value and decrement pointer by 2
    sub     r1, r1, #4
    
    cmp     r0, #0
    bne     .conv_loop
    
    pop     {r0-r7,pc}
    .ltorg


//----------------------------------------------------------------
// Assume r0 contains the 32-bit hexadecimal value (0x00 - 0xffffffff)
// Destination buffer for 32-bytes UTF16 string: 'result_buffer' (16 UTF16)
// Input: r0
// Output: [outputHex]       as utf-16 not utf-8 Destination buffer for 64-bytes UTF16 string: 'result_buffer' (16 UTF16)
//----------------------------------------------------------------
Hex2UTF32:
    push    {r0-r7,lr}

    // empty the output buffer
    //ldr     r0, =0x12345678       //Was For Test
    ldr     r1, =outputHex
    ldr     r2, =0x00000030       @ Four ASCII '0's (0x30 each)
    
    str     r2, [r1, #0x0]          @ Store first 4 bytes ("0000")
    str     r2, [r1, #0x4]          @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0x8]          @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0xC]         @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0x10]          @ Store first 4 bytes ("0000")
    str     r2, [r1, #0x14]          @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0x18]          @ Store next 4 bytes  ("0000")
    str     r2, [r1, #0x1C]         @ Store next 4 bytes  ("0000")
    
    add     r1, r1, #0x20           // Put r1 index at the last digit in the out buffer
    mov     r2, #8                @ Counter: 8 nibbles in a 32-bit word
.loopH2U:
    and     r3, r0, #0xF            @ Mask to get only the current nibble (0x1)
    lsr     r0, r0, #4              // to be ready for next loop
    
    cmp     r3, #10                 @ Is it 0-9 or A-F?
    addlt   r3, r3, #0x30         @ If 0-9: add 0x30
    addge   r3, r3, #0x37         @ If A-F: add 0x37

    strb    r3, [r1]              @ Store ASCII byte then increase pointer by 2
    sub     r1, r1, #4             @ Decrement counter
    subs    r2, r2, #1             @ Decrement counter
    bne     .loopH2U               @ Repeat until all 8 digits are done

    pop     {r0-r7,pc}
    .ltorg


//========================================================================
// Function: float_to_utf32
// Converts float IEEE754 in r0 to a null-terminated UTF-32 string in "outputIEEE"
// Output Format: Each char is 4 bytes (0x000000XX)
// input:
// r0 : IEEE754 Float Value
// output:
// outputIEEE
//========================================================================
Float2UTF32:
    push                {r0-r7, lr}
    
    //ldr    r0, =0x4996b439          //0x4996b439 => (1234567.123456) for test

    vmov                s0, r0                 // Move input to VFP
    ldr                 r4, =outputIEEE         // Pointer to output buffer

    // 1. Handle Sign
    vcmpe.f32           s0, #0
    vmrs                apsr_nzcv, fpscr
    bpl                 .positive
    mov                 r5, #'-'
    str                 r5, [r4], #4
    vneg.f32            s0, s0
.positive:

    // 2. Extract Integer Part
    vcvt.s32.f32        s1, s0
    vmov                r5, s1                 // r5 = integer part
    vcvt.f32.s32        s1, s1
    vsub.f32            s2, s0, s1         // s2 = fractional part

    // 3. Convert Integer Part to UTF-32
    mov                 r0, r5
    mov                 r1, r4
    bl                  int_to_utf32             // Use the fixed helper below
    mov                 r4, r0                  // Update pointer to end of integer

    // 4. Add Decimal Point
    mov                 r5, #'.'
    str                 r5, [r4], #4

    // 5. Convert Fractional Part (Fixed 6 digits)
    mov                 r6, #6
.frac_loop:
    vldr                s3, =0x41200000        //10.0              // Load 10.0 for FPU multiplication
    vmul.f32            s2, s2, s3
    vcvt.s32.f32        s4, s2
    vmov                r5, s4
    add                 r5, r5, #'0'
    str                 r5, [r4], #4
    vcvt.f32.s32        s4, s4
    vsub.f32            s2, s2, s4
    subs                r6, r6, #1
    bne                 .frac_loop

    // 6. Null Terminate
    mov                 r5, #0
    str                 r5, [r4]
    pop                 {r0-r7, pc}
    .ltorg
    
// Helper: int_to_utf32 (Cortex-A8 Optimized)
// r0: integer to convert, r1: buffer pointer
// Returns: r0: updated buffer pointer
int_to_utf32:
    push                {r1-r7, lr}
    mov                 r2, r1                  // r2 = Start of string
    ldr                 r3, =0xCCCCCCCD         // Magic number for dividing by 10

.int_loop:
    // This block replaces 'udiv' for ARMv7-A
    umull               r5, r4, r0, r3        // 64-bit multiply: (r0 * 0xCCCCCCCD) -> r4:r5
    mov                 r4, r4, lsr #3          // r4 = Quotient (r0 / 10)

    // Calculate remainder: r5 = r0 - (r4 * 10)
    mov                 r6, #10
    mls                 r5, r4, r6, r0          // r5 = remainder
    
    add                 r5, r5, #'0'            // Convert digit to ASCII
    push                {r5}                   // Push digit to stack
    add                 r2, r2, #4              // Increment buffer length tracker
    
    mov                 r0, r4                  // Set r0 to quotient for next iteration
    cmp                 r0, #0
    bne                 .int_loop
    
    mov                 r0, r2                  // Return the end-of-string pointer in r0
.int_reverse:                   // Reverse digits from stack into buffer
    pop                 {r5}
    str                 r5, [r1], #4            // Store 32-bit UTF-32 char
    cmp                 r1, r2
    bne                 .int_reverse
    pop                 {r1-r7, pc}
    .ltorg

//----------------------------------------------------------------
// Convert Decimal 3 bits 0-7 to Week Days 2 letters
// Input:
// r0: Dec Value (0-7)
// Output:
// r0: First Character
// r1: Second Character
//----------------------------------------------------------------
Dec2WeekDay:
    push    {r2-r10,lr}
    
    cmp     r0, #0
    bne     .monday
    mov     r5, #'S'
    mov     r6, #'u'
    b       .endD2W
.monday:
    cmp     r0, #1
    bne     .tuesday
    mov     r5, #'M'
    mov     r6, #'o'
    b       .endD2W
.tuesday:
    cmp     r0, #2
    bne     .wednesday
    mov     r5, #'T'
    mov     r6, #'u'
    b       .endD2W
.wednesday:
    cmp     r0, #3
    bne     .thursday
    mov     r5, #'W'
    mov     r6, #'d'
    b       .endD2W
.thursday:
    cmp     r0, #4
    bne     .friday
    mov     r5, #'T'
    mov     r6, #'h'
    b       .endD2W
.friday:
    cmp     r0, #5
    bne     .saturday
    mov     r5, #'F'
    mov     r6, #'r'
    b       .endD2W
.saturday:
    cmp     r0, #6
    bne     .endD2W
    mov     r5, #'S'
    mov     r6, #'t'
    b       .endD2W

.endD2W:
    mov     r0, r5
    mov     r1, r6
    
    pop     {r2-r10,pc}
    .ltorg


//----------------------------------------------------------------
// Convert Decimal 3 bits 0-7 to Week Days 2 letters
// Input:
// r0: Dec Value (0-7)
// Output:
// r0: First Character
// r1: Second Character
// r2: Third Character
//----------------------------------------------------------------
Dec2Month:
    push    {r3-r10,lr}
    
    cmp     r0, #1
    bne     .feb2
    mov     r5, #'J'
    mov     r6, #'a'
    mov     r7, #'n'
    b       .endD2M
.feb2:
    cmp     r0, #2
    bne     .mar3
    mov     r5, #'F'
    mov     r6, #'e'
    mov     r7, #'b'
    b       .endD2M
.mar3:
    cmp     r0, #3
    bne     .apr4
    mov     r5, #'M'
    mov     r6, #'a'
    mov     r7, #'r'
    b       .endD2M
.apr4:
    cmp     r0, #4
    bne     .may5
    mov     r5, #'A'
    mov     r6, #'p'
    mov     r7, #'r'
    b       .endD2M
.may5:
    cmp     r0, #5
    bne     .jun6
    mov     r5, #'M'
    mov     r6, #'a'
    mov     r7, #'y'
    b       .endD2M
.jun6:
    cmp     r0, #6
    bne     .jul7
    mov     r5, #'J'
    mov     r6, #'u'
    mov     r7, #'n'
    b       .endD2M
.jul7:
    cmp     r0, #7
    bne     .aug8
    mov     r5, #'J'
    mov     r6, #'u'
    mov     r7, #'l'
    b       .endD2M
.aug8:
    cmp     r0, #8
    bne     .sep9
    mov     r5, #'A'
    mov     r6, #'u'
    mov     r7, #'g'
    b       .endD2M
.sep9:
    cmp     r0, 9
    bne     .oct10
    mov     r5, #'S'
    mov     r6, #'e'
    mov     r7, #'p'
    b       .endD2M
.oct10:
    cmp     r0, #10
    bne     .nov11
    mov     r5, #'O'
    mov     r6, #'c'
    mov     r7, #'t'
    b       .endD2M
.nov11:
    cmp     r0, #11
    bne     .dec12
    mov     r5, #'N'
    mov     r6, #'o'
    mov     r7, #'v'
    b       .endD2M
.dec12:
    cmp     r0, #12
    bne     .endD2M
    mov     r5, #'D'
    mov     r6, #'e'
    mov     r7, #'c'
    b       .endD2M

.endD2M:
    mov     r0, r5
    mov     r1, r6
    mov     r2, r7
    
    pop     {r3-r10,pc}
    .ltorg


//----------------------------------------------------------------
// Print UTF-32 String
// Source buffer is UTF32 string: ended with 0x00000000 for end of string
// Input:
// r0: address of the String
// r2: X Start
// r3: Y Start
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//----------------------------------------------------------------
printString:
    push    {r0-r10,lr}
    
    sub     r0, r0, #48                 // this to adjust the unknown 48 bytes shift when compiling data as string
    
    cmp     r5, #0
    moveq   r8, #50
    moveq   r6, #80
    movne   r8, #72
    lsrne   r8, r8, r5
    movne   r6, #120
    lsrne   r6, r6, r5
    mov     r1, r0
.loopmeeem:
    ldr     r0, [r1], #4
    bl      write_digit            @ Call your character writer
    add     r2, r2, r8
    cmp     r2, #760
    addge   r3, r3, r6
    movge   r2, #20
    ldr     r7, [r1]                // test last zero
    cmp     r7, #0
    bne     .loopmeeem

    pop     {r0-r10,pc}
    .ltorg

//----------------------------------------------------------------
// Assume r0 contains the 32-bit hexadecimal value (0x00 - 0xffffffff)
// Destination buffer for 32-bytes UTF16 string: 'result_buffer' (16 UTF16)
// Input:
// r0: Hex Value
// r2: X
// r3: Y
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//----------------------------------------------------------------
printRegHex:
    push    {r0-r10,lr}

    bl      Hex2UTF32
    
    mov     r8, 72                          // Nominal Spacing
    lsr     r8, r8, r5                      // Adjust Spacing
    
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =outputHex
    ldr     r0, [r0, #0x0]                  // Print 0
    bl      write_digit
    
    add     r2, r2, r8                     // Print X
    mov     r0, #'x'
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =outputHex
    ldr     r0, [r0, #0x4]                // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =outputHex
    ldr     r0, [r0, #0x8]                // digit
    bl      write_digit

    add     r2, r2, r8
    mov     r0, #':'
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                           // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputHex
    ldr     r0, [r0, #0xC]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                  // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputHex
    ldr     r0, [r0, #0x10]                        // digit
    bl      write_digit

    add     r2, r2, r8
    mov     r0, #':'
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                 // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputHex
    ldr     r0, [r0, #0x14]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputHex
    ldr     r0, [r0, #0x18]                // digit
    bl      write_digit

    add     r2, r2, r8
    mov     r0, #':'
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                 // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputHex
    ldr     r0, [r0, #0x1C]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputHex
    ldr     r0, [r0, #0x20]                // digit
    bl      write_digit

    pop     {r0-r10,pc}
    .ltorg

//----------------------------------------------------------------
// printHexAtCursor
// print Hex in white with Small Font At Specific Cursor
// And Update Cursor for next print
// Input:
// r0: Hex Value
// r4: Color
// [cursor_x]: X
// [cursor_y]: Y
//----------------------------------------------------------------
printHexAtCursor:
    push    {r0-r10,lr}

    @ ---- Print ----
    ldr     r2, =cursor_x
    ldr     r2, [r2]             // set X Start
    ldr     r3, =cursor_y
    ldr     r3, [r3]             // set X Start
    //ldr     r4, =COLOR_WHITE
    mov     r5, 2
    bl      printRegHex
    add     r2, r2, #260
    cmp     r2, #800
    addge   r3, r3, #30         // next Line
    movge   r2, #20

    ldr     r7, =cursor_x
    str     r2, [r7]                        // update X
    ldr     r7, =cursor_y
    str     r3, [r7]                        // update Y

    pop     {r0-r10,pc}
    .ltorg


//----------------------------------------------------------------
// printLeastHexAtCursor
// print least Hex from 32bit Value At Specific Cursor
// example if input = 0x9283FE4D output = 4D
// And Update Cursor for next print
// Input:
// r0: Hex Value
// r4: Color
// [cursor_x]: X
// [cursor_y]: Y
//----------------------------------------------------------------
printLeastHexAtCursor:
    push    {r0-r10,lr}

    @ ---- Print ----
    ldr     r2, =cursor_x
    ldr     r2, [r2]             // set X Start
    ldr     r3, =cursor_y
    ldr     r3, [r3]             // set X Start
    //ldr     r4, =COLOR_WHITE
    mov     r5, 2
    bl      printRegLeastHex
    add     r2, r2, #48
    mov     r6, #788
    cmp     r2, r6
    addge   r3, r3, #30         // next Line
    movge   r2, #20

    ldr     r7, =cursor_x
    str     r2, [r7]                        // update X
    ldr     r7, =cursor_y
    str     r3, [r7]                        // update Y

    pop     {r0-r10,pc}
    .ltorg

//----------------------------------------------------------------
// Assume r0 contains the 32-bit hexadecimal value (0x00 - 0xffffffff)
// Destination buffer for 32-bytes UTF16 string: 'result_buffer' (16 UTF16)
// Input:
// r0: Hex Value
// r2: X
// r3: Y
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//----------------------------------------------------------------
printRegLeastHex:
    push    {r0-r10,lr}

    bl      Hex2UTF32
    
    mov     r8, 72                          // Nominal Spacing
    lsr     r8, r8, r5                      // Adjust Spacing
    
    mov     r0, #0                 // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputHex
    ldr     r0, [r0, #0x1C]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputHex
    ldr     r0, [r0, #0x20]                // digit
    bl      write_digit

    pop     {r0-r10,pc}
    .ltorg


//----------------------------------------------------------------
// printBinAtCursor
// print 32bit Binary in white with Small Font At Specific Cursor
// And Update Cursor for next print
// Input:
// r0: Hex Value
// r4: Color
// [cursor_x]: X
// [cursor_y]: Y
//----------------------------------------------------------------
printBinAtCursor:
    push    {r0-r10,lr}

    @ ---- Print ----
    ldr     r2, =cursor_x
    ldr     r2, [r2]             // set X Start
    ldr     r3, =cursor_y
    ldr     r3, [r3]             // set X Start
    //ldr     r4, =COLOR_WHITE
    mov     r5, 2
    bl      printRegBin
    add     r3, r3, #30         // next Line
    mov     r2, #20

    ldr     r7, =cursor_x
    str     r2, [r7]                        // update X
    ldr     r7, =cursor_y
    str     r3, [r7]                        // update Y

    pop     {r0-r10,pc}
    .ltorg

//----------------------------------------------------------------
// Assume r0 contains the 32-bit hexadecimal value (0x00 - 0xffffffff)
// Destination buffer for 128-bytes UTF16 string: 'result_buffer' (32 UTF32)
// Input:
// r0: Hex Value
// r2: X
// r3: Y
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//----------------------------------------------------------------
printRegBin:
    push    {r0-r10,lr}

    mov     r9, r0
    mov     r7, #32
    mov     r6, #4

    mov     r8, 72                          // Nominal Spacing
    lsr     r8, r8, r5                      // Adjust Spacing

.nextbit:
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    
    sub     r10, r7, #1                     // r10 = r7 -1 (counter -1)
    mov     r0, r9, lsr r10                 // shift to the desired bit
    and     r0, r0, #1                      // Make sure we get 1 bit only
    add     r0, r0, #0x30                   // Convert to UTF32
    bl      write_digit                     // Print
    add     r2, r2, r8
    
    subs    r6, r6, #1
    addeq   r2, r2, r8
    moveq   r6, #4
    
    subs    r7, r7, #1
    bne     .nextbit
    
    pop     {r0-r10,pc}
    .ltorg

//----------------------------------------------------------------
// Assume r0 contains the 32-bit hexadecimal value (0x00 - 0xffffffff)
// Destination buffer for 32-bytes UTF16 string: 'result_buffer' (16 UTF16)
// Input:
// r0: Hex Value
// r2: X
// r3: Y
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//----------------------------------------------------------------
printRegDec:
    push    {r0-r10,lr}

    bl      Dec2UTF32

    mov     r8, 72                          // Nominal Spacing
    lsr     r8, r8, r5                      // Adjust Spacing

    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =outputDec
    ldr     r0, [r0, #0x4]                // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =outputDec
    ldr     r0, [r0, #0x8]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                           // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputDec
    ldr     r0, [r0, #0xC]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                  // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputDec
    ldr     r0, [r0, #0x10]                        // digit
    bl      write_digit
    
    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                 // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputDec
    ldr     r0, [r0, #0x14]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputDec
    ldr     r0, [r0, #0x18]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                 // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputDec
    ldr     r0, [r0, #0x1C]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputDec
    ldr     r0, [r0, #0x20]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                 // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputDec
    ldr     r0, [r0, #0x24]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputDec
    ldr     r0, [r0, #0x28]                // digit
    bl      write_digit

    pop     {r0-r10,pc}
    .ltorg


//----------------------------------------------------------------
// Assume r0 contains the 32-bit hexadecimal value (0x00 - 0xffffffff)
// Destination buffer for 32-bytes UTF16 string: 'result_buffer' (16 UTF16)
// It Do Print 7 Digits Integer Max and 6 digits Fraction
// Input:
// r0: IEEE Float Value
// r2: X
// r3: Y
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//----------------------------------------------------------------
printRegIEEE:
    push    {r0-r10,lr}

    bl      Float2UTF32

    mov     r8, 72                          // Nominal Spacing
    lsr     r8, r8, r5                      // Adjust Spacing

    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x0]                // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x4]                // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit                     // empty digit in this position
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x8]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                           // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0xC]                        // digit
    bl      write_digit

    add     r2, r2, r8                     // Shifting x position
    mov     r0, #0                  // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x10]                        // digit
    bl      write_digit
    
    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                 // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x14]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x18]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                 // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x1C]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x20]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                 // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x24]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x28]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                 // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x2C]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x30]                // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                 // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputIEEE
    ldr     r0, [r0, #0x34]                // digit
    bl      write_digit
    
    pop     {r0-r10,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printBin:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #400
    ldr     r4, =COLOR_LIGHT_CYAN
    mov     r5, #2
    bl      printRegBin
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printHex:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #400
    ldr     r4, =COLOR_LIGHT_CYAN
    mov     r5, #1
    bl      printRegHex
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Dec With Purple Color
// Input:
// r0: Dec Value
//----------------------------------------------------------------
printDec:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #100
    ldr     r4, =COLOR_LIGHT_PURPLE
    mov     r5, #1
    bl      printRegDec
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printIEEE:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #20
    ldr     r4, =COLOR_LIGHT_GREEN
    mov     r5, #1
    bl      printRegIEEE
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Dec With Purple Color
// Input:
// r0: Dec Value
// r1: Battery Condition
//      bit[0]:Battery is Low Temperature
//      bit[1]:Battery is Over Temperature
//      bit[2]:Battery Charging Complete
//      bit[3]:Battery Charging State
//      bit[4]:Battery Exit activation mode
//      bit[5]:Battery Started activation charge mode
//      bit[6]:Battery is Removed
//      bit[7]:Battery is Connected
//----------------------------------------------------------------
printBattery:
    push    {r0-r10,lr}

    and     r3, r1, #0b10                    @ test Charging Condition (bit 1)
    cmp     r3, #0b10
    bne     .notOverheat                    @ if zero loop
    ldr     r7, =COLOR_RED
    b       .batterycont
.notOverheat:
    and     r3, r1, #0b100                   @ test Charging Condition (bit 2)
    cmp     r3, #0b100
    bne     .notFull                        @ if zero loop
    ldr     r7, =COLOR_LIGHT_CYAN
    b       .batterycont
.notFull:
    and     r3, r1, #0b1000                   @ test Charging Condition (bit 3)
    cmp     r3, #0b1000
    bne     .notCharging                    @ if zero loop
    ldr     r7, =COLOR_LIGHT_PURPLE
    b       .batterycont
.notCharging:
    cmp     r0, #30
    bgt     .morethan30
    ldr     r7, =COLOR_LIGHT_RED
    b       .batterycont
.morethan30:
    cmp     r0, #70
    bgt     .morethan70
    ldr     r7, =COLOR_LIGHT_YELLOW
    b       .batterycont
.morethan70:
    cmp     r0, #99
    bgt     .morethan99
    ldr     r7, =COLOR_LIGHT_GREEN
    b       .batterycont
.morethan99:
    ldr     r7, =COLOR_LIGHT_BLUE

.batterycont:
    mov     r9, r0                          // Save r0 inside r9 (battery value)


    bl      Dec2UTF32                       // Convert r0 to UTF-32

    mov     r4, r7
    mov     r0, r9                          // restore Battery Value
    mov     r2, #680
    mov     r3, #10
    bl      draw_battery_block

    mov     r4, r7
    mov     r2, #580
    mov     r3, #15
    mov     r5, #2
    mov     r8, #80
    lsr     r8, r8, r5

    ldr     r6, =batteryMode
    ldr     r6, [r6]
    cmp     r6, #1                          // 0: graphics battery only 1: gfx + numeric
    bne     .gfxOnlyShow                     // if zero quit

    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputDec
    ldr     r0, [r0, #0x20]                 // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputDec
    ldr     r0, [r0, #0x24]                 // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    ldr     r0, =outputDec
    ldr     r0, [r0, #0x28]                 // digit
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit
    mov     r0, #'%'
    bl      write_digit
    b       .endbatshow
    
.gfxOnlyShow:
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit

    add     r2, r2, r8                      // Shifting x position
    mov     r0, #0                          // code for clear 7 segment
    bl      write_digit


.endbatshow:
    pop     {r0-r10,pc}
    .ltorg

//----------------------------------------------------------------
// draw_battery_block
// Input:
//  r0: Dec Value
//  r2: X
//  r3: Y
//  r4: Block Color
//----------------------------------------------------------------
draw_battery_block:
    push    {r0-r10,lr}

    mov     r9, r4                      // Save the Color
    mov     r7, r2                      // Save X
    mov     r8, r3                      // Save Y
    
    //-- Draw Battery Frame --
    ldr     r4, =COLOR_WHITE            // Frame Color
    mov     r1, #101
    bl      makeRow
    
    mov     r1, #30
    bl      makeColumn
    
    add     r3, r3, #30
    mov     r1, #101
    bl      makeRow
    
    sub     r3, r3, #30
    add     r2, r2, #101
    mov     r1, #10
    bl      makeColumn
    
    add     r3, r3, #10
    mov     r1, #10
    bl      makeRow
    
    add     r2, r2, #10
    mov     r1, #10
    bl      makeColumn
    
    add     r3, r3, #10
    sub     r2, r2, #10
    mov     r1, #10
    bl      makeRow
    
    mov     r1, #10
    bl      makeColumn

    //-- Draw Battery Cap ---
    ldr     r4, =COLOR_WHITE
    sub     r2, r2, #1
    sub     r3, r3, #9
    mov     r10, #10
.batcaploop:
    add     r2, r2, #1
    mov     r1, #9
    bl      makeColumn
    subs    r10, r10, #1
    bne     .batcaploop

    //-- Draw Battery Filling ---
    mov     r4, r9                  // Restore Inner Color
    mov     r2, r7
    mov     r3, r8
    mov     r10, r0                 // Battery level as a counter
    add     r3, r3, #1
.batloop:
    add     r2, r2, #1
    mov     r1, #29
    bl      makeColumn
    subs    r10, r10, #1
    bne     .batloop

    //-- Complete Battery Empty Filling ---
    ldr     r4, =COLOR_BLACK
    rsb     r10, r0, #100           // Empty Part to clear
    cmp     r10, #0
    ble     .endbat
.batclearloop:
    add     r2, r2, #1
    mov     r1, #29
    bl      makeColumn
    subs    r10, r10, #1
    bne     .batclearloop

.endbat:

    pop     {r0-r10,pc}
    .ltorg


//-------------------------------------------------------------------------------------
// Error Show 7 Segnmant
//-------------------------------------------------------------------------------------
err:
    push    {r0-r7,lr}
    
    mov     r0, #'E'
    mov     r2, #300                     // Starting x position
    mov     r3, #200                     // Starting y position
    ldr     r4, =COLOR_MAGENTA
    mov     r5, #1
    bl      write_digit

    mov     r0, #'r'
    add     r2, #32
    bl      write_digit

    mov     r0, #'r'
    add     r2, #32
    bl      write_digit

    mov     r0, #'o'
    add     r2, #32
    bl      write_digit

    mov     r0, #'r'
    add     r2, #32
    bl      write_digit

.errhere:
    b       .errhere
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printHex400A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #407
    ldr     r4, =COLOR_LIGHT_CYAN
    mov     r5, #1
    bl      printRegHex
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printHex400B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #453
    ldr     r4, =COLOR_LIGHT_CYAN
    mov     r5, #2
    bl      printRegHex
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Dec With Purple Color
// Input:
// r0: Dec Value
//----------------------------------------------------------------
printDec400A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #407
    ldr     r4, =COLOR_LIGHT_PURPLE
    mov     r5, #1
    bl      printRegDec
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Dec With Purple Color
// Input:
// r0: Dec Value
//----------------------------------------------------------------
printDec400B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #453
    ldr     r4, =COLOR_LIGHT_PURPLE
    mov     r5, #2
    bl      printRegDec
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printIEEE400A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #407
    ldr     r4, =COLOR_LIGHT_GREEN
    mov     r5, #1
    bl      printRegIEEE
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printIEEE400B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #453
    ldr     r4, =COLOR_LIGHT_GREEN
    mov     r5, #2
    bl      printRegIEEE
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printHex300A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #307
    ldr     r4, =COLOR_LIGHT_CYAN
    mov     r5, #1
    bl      printRegHex
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printHex300B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #357
    ldr     r4, =COLOR_LIGHT_CYAN
    mov     r5, #1
    bl      printRegHex
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Dec With Purple Color
// Input:
// r0: Dec Value
//----------------------------------------------------------------
printDec300A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #307
    ldr     r4, =COLOR_LIGHT_PURPLE
    mov     r5, #1
    bl      printRegDec
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Dec With Purple Color
// Input:
// r0: Dec Value
//----------------------------------------------------------------
printDec300B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #357
    ldr     r4, =COLOR_LIGHT_PURPLE
    mov     r5, #1
    bl      printRegDec
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printIEEE300A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #307
    ldr     r4, =COLOR_LIGHT_GREEN
    mov     r5, #1
    bl      printRegIEEE
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printIEEE300B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #357
    ldr     r4, =COLOR_LIGHT_GREEN
    mov     r5, #1
    bl      printRegIEEE
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printHex200A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #207
    ldr     r4, =COLOR_LIGHT_CYAN
    mov     r5, #1
    bl      printRegHex
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printHex200B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #257
    ldr     r4, =COLOR_LIGHT_CYAN
    mov     r5, #1
    bl      printRegHex
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Dec With Purple Color
// Input:
// r0: Dec Value
//----------------------------------------------------------------
printDec200A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #207
    ldr     r4, =COLOR_LIGHT_PURPLE
    mov     r5, #1
    bl      printRegDec
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Dec With Purple Color
// Input:
// r0: Dec Value
//----------------------------------------------------------------
printDec200B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #257
    ldr     r4, =COLOR_LIGHT_PURPLE
    mov     r5, #1
    bl      printRegDec
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printIEEE200A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #207
    ldr     r4, =COLOR_LIGHT_GREEN
    mov     r5, #1
    bl      printRegIEEE
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printIEEE200B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #257
    ldr     r4, =COLOR_LIGHT_GREEN
    mov     r5, #1
    bl      printRegIEEE
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printHex100A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #107
    ldr     r4, =COLOR_LIGHT_CYAN
    mov     r5, #1
    bl      printRegHex
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printHex100B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #157
    ldr     r4, =COLOR_LIGHT_CYAN
    mov     r5, #1
    bl      printRegHex
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Dec With Purple Color
// Input:
// r0: Dec Value
//----------------------------------------------------------------
printDec100A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #107
    ldr     r4, =COLOR_LIGHT_PURPLE
    mov     r5, #1
    bl      printRegDec
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Dec With Purple Color
// Input:
// r0: Dec Value
//----------------------------------------------------------------
printDec100B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #157
    ldr     r4, =COLOR_LIGHT_PURPLE
    mov     r5, #1
    bl      printRegDec
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printIEEE100A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #107
    ldr     r4, =COLOR_LIGHT_GREEN
    mov     r5, #1
    bl      printRegIEEE
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printIEEE100B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #157
    ldr     r4, =COLOR_LIGHT_GREEN
    mov     r5, #1
    bl      printRegIEEE
    
    pop     {r0-r7,pc}
    .ltorg


//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printHex00A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #7
    ldr     r4, =COLOR_LIGHT_CYAN
    mov     r5, #1
    bl      printRegHex
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printHex00B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #57
    ldr     r4, =COLOR_LIGHT_CYAN
    mov     r5, #1
    bl      printRegHex
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Dec With Purple Color
// Input:
// r0: Dec Value
//----------------------------------------------------------------
printDec00A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #7
    ldr     r4, =COLOR_LIGHT_PURPLE
    mov     r5, #1
    bl      printRegDec
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Dec With Purple Color
// Input:
// r0: Dec Value
//----------------------------------------------------------------
printDec00B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #57
    ldr     r4, =COLOR_LIGHT_PURPLE
    mov     r5, #1
    bl      printRegDec
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printIEEE00A:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #7
    ldr     r4, =COLOR_LIGHT_GREEN
    mov     r5, #1
    bl      printRegIEEE
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Print Value At r0 At Buttom of Screen in Hex With Cyan Color
// Input:
// r0: Hex Value
//----------------------------------------------------------------
printIEEE00B:
    push    {r0-r7,lr}
    
    mov     r2, #20
    mov     r3, #57
    ldr     r4, =COLOR_LIGHT_GREEN
    mov     r5, #1
    bl      printRegIEEE
    
    pop     {r0-r7,pc}
    .ltorg

//----------------------------------------------------------------
// Test 5 radian Values At r0 by getting the sin(x)
// Input:
// r0: float radian from 0 - 6.28318531
//----------------------------------------------------------------
vsin_tester:

    ldr     r0, =0x3e8a3d71          //0.27 => cos = 0.9637709 sin = 0.26673144
    bl      vsin
    bl      printIEEE00A
    ldr     r0, =0x3fd9999a          //1.7 => cos = -0.12884449 sin = 0.99166481
    bl      vsin
    bl      printIEEE100A
    ldr     r0, =0x4039999a          //2.9 => cos = -0.97095817 sin = 0.23924933
    bl      vsin
    bl      printIEEE200A
    ldr     r0, =0x40a00000          //5 => cos = 0.28366219 sin = -0.95892427
    bl      vsin
    bl      printIEEE300A
    ldr     r0, =0x40c33333          //6.1 => cos = 0.98326844 sin = -0.1821625
    bl      vsin
    bl      printIEEE400A
    b       end
    bx      lr

//----------------------------------------------------------------
// Test 5 radian Values At r0 by getting the cos(x)
// Input:
// r0: float radian from 0 - 6.28318531
//----------------------------------------------------------------
vcos_tester:

    ldr     r0, =0x3e8a3d71          //0.27 => cos = 0.9637709 sin = 0.26673144
    bl      vcos
    bl      printIEEE00A
    ldr     r0, =0x3fd9999a          //1.7 => cos = -0.12884449 sin = 0.99166481
    bl      vcos
    bl      printIEEE100A
    ldr     r0, =0x4039999a          //2.9 => cos = -0.97095817 sin = 0.23924933
    bl      vcos
    bl      printIEEE200A
    ldr     r0, =0x40a00000          //5 => cos = 0.28366219 sin = -0.95892427
    bl      vcos
    bl      printIEEE300A
    ldr     r0, =0x40c33333          //6.1 => cos = 0.98326844 sin = -0.1821625
    bl      vcos
    bl      printIEEE400A
    b       end
    bx      lr

//----------------------------------------------------------------
// Test 5 radian Values At r0 by getting the tan(x)
// Input:
// r0: float radian from 0 - 6.28318531
//----------------------------------------------------------------
vtan_tester:

    ldr     r0, =0x3e8a3d71          //0.27 => cos = 0.9637709 sin = 0.26673144 tan = 0.27675814
    bl      vtan
    bl      printIEEE00A
    ldr     r0, =0x3fd9999a          //1.7 => cos = -0.12884449 sin = 0.99166481 tan = -7.69660214
    bl      vtan
    bl      printIEEE100A
    ldr     r0, =0x4039999a          //2.9 => cos = -0.97095817 sin = 0.23924933 tan = -0.24640539
    bl      vtan
    bl      printIEEE200A
    ldr     r0, =0x40a00000          //5 => cos = 0.28366219 sin = -0.95892427 tan = -3.38051501
    bl      vtan
    bl      printIEEE300A
    ldr     r0, =0x40c33333          //6.1 => cos = 0.98326844 sin = -0.1821625 tan = -0.18526223
    bl      vtan
    bl      printIEEE400A
    b       end
    bx      lr

//----------------------------------------------------------------
// Test 5 radian Values At r0 by getting the tan(x)
// Input:
// r0: float radian from 0 - 6.28318531
//----------------------------------------------------------------
vatan2_tester:

    ldr     r0, =0x41400000          //12.0 Y
    ldr     r1, =0x41100000          //9.0 X
    bl      vatan2                   // =>  0.927295218002
    bl      printIEEE00A
    ldr     r0, =0x432a0000          //170.0
    ldr     r1, =0x42b00000          //88.0
    bl      vatan2                   // => 1.093130944432
    bl      printIEEE100A
    ldr     r0, =0x435b0000          //219.0
    ldr     r1, =0x3f800000          //1.0
    bl      vatan2                   // =>  1.566230148484
    bl      printIEEE200A
    ldr     r0, =0x44070000          //540.0
    ldr     r1, =0x44480000          //800.0
    bl      vatan2                   // =>  0.593749666711
    bl      printIEEE300A
    ldr     r0, =0x00000000          //0.0
    ldr     r1, =0x41800000          //16.0
    bl      vatan2                   // => 0.000000
    bl      printIEEE400A
    b       end
    bx      lr

//----------------------------------------------------------------
// Test Print All Characters
// Input:
// r0: address of the String
// r2: X Start
// r3: Y Start
// r4 = Color
// r5 = Size Div
//  0: 2⁰ x / 1 (no change aka Max Size)
//  1: 2¹ x / 2 (half Size)
//  2: 2² x / 4 (Quarter Size)
//----------------------------------------------------------------
printAll:
    push    {r0-r10,lr}
    
    cmp     r5, #0
    moveq   r8, #50
    moveq   r6, #80
    movne   r8, #72
    lsrne   r8, r8, r5
    movne   r6, #120
    lsrne   r6, r6, r5
    mov     r1, r0
    mov     r0, #0x20
.loopmeeemtest:
    add     r0, r0, #1
    bl      write_digit            @ Call your character writer
    add     r2, r2, r8
    cmp     r2, #760
    addge   r3, r3, r6
    movge   r2, #20
    cmp     r0, #0x7E
    ble     .loopmeeemtest

    pop     {r0-r10,pc}
    .ltorg



//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
//
// Here are a Special Functions Calling a ready Made Subroutines From Android Boot Kernel,
// Tweaked to match the Clock Original Functions inputs/outputs requirements
//
//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


//========================================================================
// Read Date & Time To RTC Calender
// Input:
// Output:
// r0 = Weekday | Hours |Min | Sec.
//      bits[0-5] Second
//      bits[8-13] Minute
//      bits[16-20] Hour
//      bits[29-31] Week Day
// r1 = Year | Months | Days.
//      bits[0-4] Day
//      bits[8-11] Month
//      bits[16-23] Year
//      bit[31] Leap Year Bit 0:365 Days 1: 366 Days
//========================================================================
RTC_Read:
    push    {r2-r10, lr}
    
    bl      HYM8563_Read                    // Read time to time structure

    ldr     r4, =Time_Structure             // time buffer

    // -- Get Seconds --
    ldr     r0, [r4]                        // seconds
    and     r0, r0, #0x3F                   // Clear Bit[6-31] has 6 bits Only
    mov     r8, r0                          // Save Seconds bits[0-5] (bin size 6 bits) r8 = sec
    
    // -- Get Minutes --
    ldr     r0, [r4, #0x4]                  // minutes
    and     r0, r0, #0x7F                   // Clear Bits[6-31] has 6 bits Only
    lsl     r0, r0, #8                      // Shift To the Location Of Minutes bits[8-13] (bin size 6 bits)
    orr     r8, r0, r8                      // Save Minutes (r8 = Min | Sec)

    // -- Get Hours --
    ldr     r0, [r4, #0x8]                  // Hours
    and     r0, r0, #0x1F                   // Clear Bits[5-31] has 5 bits only
    lsl     r0, r0, #16                     // Shift To the Location Of Hours bits[16-20] (bin size 5 bits)
    orr     r8, r0, r8                      // Save Hours (r8 =  Hours |Min | Sec )

    // -- Get Days --
    ldr     r0, [r4, #0xC]                  // Day
    and     r0, r0, #0x1F                   // Clear Bits[5-31] has 5 bits only
    mov     r9, r0                              // Save Days bits[0-4] (bin size 5 bits) r9 = Days

    // -- Get Weekday --
    ldr     r0, [r4, #0x18]                 // Week Day
    and     r0, r0, #0x7                    // Clear Bits[3-31] has 3 bits only
    lsl     r0, r0, #29                     // Shift To the Location Of Week bits[29-31] (size 3 bits)
    orr     r8, r0, r8                      // Weekday (r8 =  Weekday | Hours |Min | Sec )

    // -- Get Months --
    ldr     r0, [r4, #0x10]                 // Month
    and     r0, r0, #0xF                    // Clear Bits[4-31] has 4 bits only
    add     r0, r0, #1                      // Adjust Months to start from 1 not 0
    lsl     r0, r0, #8                      // Shift To the Location Of Months bits[8-11] (bin size 4 bits)
    orr     r9, r0, r9                      // Save Months (r9 = Months | Days)
        
    // -- Get Years --
    ldr     r0, [r4, #0x24]                 // Year
    and     r0, r0, #0x7F                   // Clear Bits[7-31] has 7 bits
    lsl     r0, r0, #16                     // Shift To the Location Of Years bits[16-23] (bin size 8 bits)
    orr     r9, r9, r0                      // Save Years (r9 = Year | Months | Days)

    lsr     r0, r9, #16
    and     r0, r0, #0xFF
    bl      get_leap_year                       // return r0: leap year bit 0: 365 1: 366
    lsl     r0, r0, #31                         // Shift To the Location Of Leap Year bit[31]
    orr     r9, r0, r9                          // Save Leap Year (r9 = LY | Year | Months | Days)
    mov     r0, r8
    mov     r1, r9

    pop     {r2-r10, pc}
    .ltorg

//========================================================================
// Write Date & Time To RTC Calender
// Input:
// r0 = value
// r1 = Type
//      0x0: Seconds
//      0x1: Minutes
//      0x2: Hours
//      0x3: Days
//      0x4: WeekDay
//      0x5: Months
//      0x6: Year
//      0x7: Minute_alarm
//      0x8: Hour_alarm
//      0x9: Day_alarm
//      0xA: Weekday_alarm
// Output:
//
//========================================================================
RTC_Write:
    push    {r2-r10, lr}
    
    ldr     r4, =Time_Structure           // time buffer

    cmp     r1, #0x0
    bne     .chkMin
    
    // -- Set Seconds --
    str     r0, [r4]                        // seconds
    b       .apply_rtc_write
    
.chkMin:
    cmp     r1, #0x1
    bne     .chkHor
    
    // -- Set Minutes --
    str     r0, [r4, #0x4]                  // minutes
    b       .apply_rtc_write

.chkHor:
    cmp     r1, #0x2
    bne     .chkDay

    // -- Set Hours --
    str     r0, [r4, #0x8]                  // Hours
    b       .apply_rtc_write

.chkDay:
    cmp     r1, #0x3
    bne     .chkWek

    // -- Set Days --
    str     r0, [r4, #0xC]                  // Day
    b       .apply_rtc_write

.chkWek:
    cmp     r1, #0x4
    bne     .chkMon

    // -- Set Weekday --
    str     r0, [r4, #0x18]                 // Week Day
    b       .apply_rtc_write

.chkMon:
    cmp     r1, #0x5
    bne     .chkYer

    // -- Set Months --
    sub     r0, r0, #1                      // This Specially For RockChip Cause The Function Adds 1 to month automatically
    str     r0, [r4, #0x10]                 // Month
    b       .apply_rtc_write

.chkYer:
    cmp     r1, #0x6
    bne     .rtc_write_end

    // -- Set Years --
    str     r0, [r4, #0x24]                 // Year
    str     r0, [r4, #0x14]                 // Year

.apply_rtc_write:
    bl      HYM8563_Write                   // Set Time From Time_Structure

.rtc_write_end:
    pop     {r2-r10, pc}
    .ltorg


// =============== S U B R O U T I N E =======================================
// HYM8563_Read
// Inouts:
// Output:
// Current Time: Time_Structure = 0xD903DEC0
//========================================================================
HYM8563_Read:
    push    {r0-r2, lr}

    // get the RTC (Real Time Clock)
    // Get_Time Kernel Function = 0xC0774E7C
    // r0: RTC_Device_Driver = 0xD9066A00
    // r1: Time_Structure = 0xD903DEC0

    ldr     r1, =Time_Structure           // time structure
    ldr     r0, =RTC_Device_Driver          // RTC instance
    ldr     r2, =Get_Time
    blx     r2

    pop     {r0-r2, pc}
    .ltorg

// =============== S U B R O U T I N E =======================================
// HYM8563_Write
// Inouts:
// Current Time: Time_Structure = 0xD903DEC0
// Output:
//========================================================================
HYM8563_Write:
    push    {r0-r2, lr}

    // set the RTC (Real Time Clock)
    // Set_Time Kernel Function = 0xC0774BEC
    // r0: RTC_Device_Driver = 0xD9066A00
    // r1: Time_Structure = 0xD903DEC0

    ldr     r1, =Time_Structure           // time structure
    ldr     r0, =RTC_Device_Driver          // RTC instance
    ldr     r2, =Set_Time
    blx     r2

    pop     {r0-r2, pc}
    .ltorg


//========================================================================
// Read Power Switch
// Input:
// Output:
// r0 = Power Switch Condition
//      2: Released
//      3: Long Click
//========================================================================
PWR_SW_Read:

    ldr     r0, =Power_Button
    ldr     r0, [r0]

    bx      lr


//========================================================================
// Read Battery Meter
// Input:
// Output:
// r0 = Battery Percentage From 0-100
// r1 = Battery Condition Default (00)
//      bit[0]:Battery is Low Temperature
//      bit[1]:Battery is Over Temperature
//      bit[2]:Battery Charging Complete
//      bit[3]:Battery Charging State
//      bit[4]:Battery Exit activation mode
//      bit[5]:Battery Started activation charge mode
//      bit[6]:Battery is Removed
//      bit[7]:Battery is Connected
//========================================================================
Battery_Read:
    push    {r2-r10, lr}
    
    bl      Battery_Read_Status
    mov     r1, r0
    
    bl      Battery_Fuel_Read
    
    pop     {r2-r10, pc}
    .ltorg

//========================================================================
// Read Battery Status
// Input:
// Output:
// r0 = Battery Condition Default (00)
//      bit[0]:Battery is Low Temperature
//      bit[1]:Battery is Over Temperature
//      bit[2]:Battery Charging Complete
//      bit[3]:Battery Charging State
//      bit[4]:Battery Exit activation mode
//      bit[5]:Battery Started activation charge mode
//      bit[6]:Battery is Removed
//      bit[7]:Battery is Connected
//========================================================================
Battery_Read_Status:
    push    {r1-r10, lr}

    ldr     r0, =Battery_Charging_State
    ldr     r0, [r0]
    lsl     r0, r0, #0x3

    pop     {r1-r10, pc}
    .ltorg

//========================================================================
// Read Battery Meter
// Input:
// Output:
// r0 = Battery Percentage From 0-100 0x0 - 0x64
//========================================================================
Battery_Fuel_Read:
    push    {r1-r10, lr}

    ldr     r0, =Battery_Percentage
    ldr     r0, [r0]

    pop     {r1-r10, pc}
    .ltorg

//###############################################################################################################
//########################################## Keys Input Functions ###############################################
//###############################################################################################################
// =============== S U B R O U T I N E =======================================
// input:
// output:
// r0: State for Keys
//      0x3f: Nothing Pressed (Default)
//      0x05: Vol-Up Pressed
//      0x0B: Vol-Down Pressed
// Note:
//  if you press both together the Vol-Up is the one would Take Over
//  so the result would be 0x05.
// ===========================================================================
Get_Keys_State:

    mov     r0, #0
    bx      lr
 
/*
// =============== S U B R O U T I N E =======================================
// input:
// output:
// r0: State for Keys
//      0x3f: Nothing Pressed (Default)
//      0x05: Vol Pressed
//
// Note:
//  if you press both together the Vol-Up is the one would Take Over
//  so the result would be 0x05.
// ===========================================================================
Get_Keys_State_Expermental:

     push    {r1,r2,lr}

    ldr     r1, =KEY_COUNTER       @ r1 = key counter VA
    ldr     r2, [r1]               @ r2 = old value of key counter

.loopPoll:
    ldr     r0, [r1]               @ r0 = current counter
    cmp     r0, r2
    beq     .skip                   @ no change → continue polling

    @ --- counter changed, check power button to ignore ---
    ldr     r3, =POWER_BUTTON
    ldr     r4, [r3]               @ r4 = power button value
    tst     r4, #(0b1 << 4)        @ bit4 = 1:Released, 0:Pressed
    beq     .skip                   @ power button pressed → ignore

    @ --- volume key detected ---
    mov     r2, r0                  @ update old counter
    @ --- do something here: e.g., call printhex or set a flag ---
    bl      printVolumeKeyDetected  @ user-defined function

.skip:
    b       .loopPoll

    pop     {r1,r2,lr}
*/

@ -------------------------------------------------
@ Read_SARADC (This Wont Work When KERNEL Takes Over_
@ Input:
@   r0 = channel code (7,6,5,4)
@ Returns:
@   r0 = 10-bit ADC value
@ -------------------------------------------------
Read_SARADC:

    PUSH    {r1,r2,r3,r4,lr}

    LDR     r1, =SARADC_BASE

    @ --- Step 1: Power down ADC ---
    LDR     r2, [r1, #SARADC_CTRL]
    BIC     r2, r2, #(0b1 << 3)         @ clear bit3
    STR     r2, [r1, #SARADC_CTRL]

    @ optional small delay after power-down
    MOV     r4, #2000
delay1:
    SUBS    r4, r4, #1
    BNE     delay1

    @ --- Step 2: Power up + select channel + preserve interrupt bit ---
    LDR     r2, [r1, #SARADC_CTRL]     @ read current value
    BIC     r2, r2, #0x7               @ clear bits[2:0] channel
    ORR     r2, r2, r0                 @ set channel from r0
    ORR     r2, r2, #(0b1 << 3)        @ power up
    STR     r2, [r1, #SARADC_CTRL]

    @ --- optional: configure delay if desired ---
    MOV     r3, #0x8                    @ default delay
    STR     r3, [r1, #SARADC_DLY_PU_SOC]

    @ --- Step 3: Wait for conversion ---
wait_loop:
    LDR     r2, [r1, #SARADC_STAS]     @ read STAS
    TST     r2, #1                     @ bit0 = conversion in progress
    BNE     wait_loop                   @ loop while busy

    @ --- Step 4: Read ADC result ---
    LDR     r0, [r1, #SARADC_DATA]

    POP     {r1,r2,r3,r4,pc}
  
  
@ -------------------------------------------------
@ read_SARADC_Full_Debug
@ Input:
@   r0 = channel code (7,6,5,4)
@ Returns:
@   r0 = 10-bit ADC value
@ -------------------------------------------------

read_SARADC_Full_Debug:

    push    {r1,r2,r3,r4,lr}

    ldr     r1, =SARADC_BASE           @ SARADC base

    @ --- Step 1: Power down ADC ---
    ldr     r2, [r1, #SARADC_CTRL]
    bic     r2, r2, #(0b1 << 3)       @ clear bit3 = power down
    str     r2, [r1, #SARADC_CTRL]

    @ small delay after power-down
    mov     r4, #200
.repeatFromDelay:
    subs    r4, r4, #1
    bne     .repeatFromDelay

    @ --- Step 2: Power up + select channel + enable interrupt ---
    ldr     r2, [r1, #SARADC_CTRL]    @ read current CTRL
    bic     r2, r2, #0x7              @ clear bits[2:0] = old channel
    orr     r2, r2, r0                @ set channel = r0
    orr     r2, r2, #(0b1 << 3)       @ set bit3 = power up
    orr     r2, r2, #(0b1 << 5)       @ set bit5 = interrupt enable
    str     r2, [r1, #SARADC_CTRL]

    @ --- Step 3: Configure power-up delay (optional) ---
    mov     r3, #0x8
    str     r3, [r1, #SARADC_DLY_PU_SOC]

    @ --- Step 4: Clear pending interrupt status (bit6) ---
    ldr     r2, [r1, #SARADC_CTRL]
    bic     r2, r2, #(0b1 << 6)       @ clear bit6
    str     r2, [r1, #SARADC_CTRL]

    @ --- Step 5: Wait for interrupt status (bit6) ---
.waitForInterrupt:
    ldr     r2, [r1, #SARADC_CTRL]
    tst     r2, #(0b1 << 6)           @ test bit6 = interrupt status
    beq     .waitForInterrupt          @ loop while not set

    @ --- Step 6: Read full 32-bit ADC DATA ---
    ldr     r0, [r1, #SARADC_DATA]    @ raw 32-bit value (unmasked)

    pop     {r1,r2,r3,r4,pc}

    
//###############################################################################################################
//######################## Gyroscope And Accelerometer Input Functions ##########################################
//###############################################################################################################
// =============== S U B R O U T I N E =======================================
// input:
// output:
// r0: State for Gyroscope And Accelerometer
// Accelerometer bits[0-11]
// Yaw bits[16-19] 0b1111: Horizontal  0b1010: Tilt Right 0b0000: Tilt Left
// Roll bit[20] 0:LCD 90º Facing you 1:LCD Facing up
// Accelerometer bits[0-1
// ===========================================================================
Get_Gyro_State:

    ldr     r0, =Gyroscope_Control
    ldr     r0, [r0]
    //bl      printBin
    bx      lr
    
    
//###############################################################################################################
//########################################## Backlight Functions ###############################################
//###############################################################################################################

// =============== S U B R O U T I N E =======================================
// Control LCD Back Light
// Input: r0 = brigtness (0x0-0xF)  0x0 = 100%, 0x8 = 50%, 0xF = 0%
//============================================================================

BCK_L_CTRL:
    push    {r0-r7, lr}
    
    // ------ 1: Set the period and duty cycle registers.
    // PWM_Output_Freq = PWM_Input_Freq ÷ PWM_Prescaler ÷ PWM_Period
    // 10,000 = 24,000,000 ÷ 240 ÷ 10
    // Let's use a period of 10 and a duty cycle of 5 for 50% brightness.
    // Alsoo Notice that PWM_DUTY_CYCLE is inverted 0: 100% brightness 10: 0% brightness (max duty = period)
    // and why it is inverted because this board has inverted pwm polarity as in script.fex lcd_pwm_pol = 1
    ldr     r3, =PWM0_BASE
    ldr     r1, [r3, #PWM0_HRC]         // AKA PWM0_Duty 0x9196 => Default
    bic     r1, r1, #0xFFFFFFFF         // Clear all bits
    mov     r0, r0, lsl#12              // prepare the input shift to correct positiom
    orr     r1, r1, r0      //#(5 << 0) // Set Bits [0:15] PWM_Duty_Cycle 5 is half the PWM_Period so 50% brightness
    str     r1, [r3, #PWM0_HRC]
    
    ldr     r1, [r3, #PWM0_LRC]         // AKA PWM0_Period 0x1220A => Default
    bic     r1, r1, #0xFFFFFFFF         // Clear all bits
    ldr     r1, =0x1220A
    str     r1, [r3, #PWM0_LRC]

    // ------ 2: Enable PWM output
    // In the PWM0_CTRL register:
    // Bit 0 enables PWM0.
    ldr     r3, =PWM0_BASE
    ldr     r1, [r3, #PWM0_CTRL]        // 0x9 => Default
    bic     r1, r1, #0xFFFFFFFF         // Clear all bits
    orr     r1, r1, #(0b1 << 0)         // Set bit[0] pwm_timer_en 0 = Disable 1 = Enable
    orr     r1, r1, #(0b1 << 3)         // set bit[3] pwm_output_en 0: disable 1: Enable (Output Enable = 1)
    bic     r1, r1, #(0b1 << 4)         // Clear bit[4] single_cnt_mode 0: cycle mode, 1: pulse mode
    bic     r1, r1, #(0b0000 << 9)      // Clear bit[9-12] prescale_factor (default is 0b0000 => 1/2)
                                        // 0000: 1/2 0001: 1/4
                                        // 0010: 1/8 0011: 1/16
                                        // 0100: 1/32 0101: 1/64
                                        // 0110: 1/128 0111: 1/256
                                        // 1000: 1/512 1001: 1/1024
                                        // 1010: 1/2048 1011: 1/4096
                                        // 1100: 1/8192 1101: 1/16384
                                        // 1110: 1/32768 1111: 1/65536
    str     r1, [r3, #PWM0_CTRL]

    pop     {r0-r7, pc}
    .ltorg


//###############################################################################################################
//############################### TTBR0 & TTBR1 L1 & L2 Functions ###############################################
//###############################################################################################################

// =============== S U B R O U T I N E =======================================
// get_TTBR0 then add the Delta 0x60000000
// output:
// r0 : TTBR0  0xC0404000
//========================================================================
get_TTBR0:
        // Get TTBR0 MMU Remapping Table Address
    push    {r1-r2,lr}
    
    mrc     p15, 0, r0, c2, c0, 0   // TTBR0
    mov     r2, #0x3FFF
    bic     r0, r0, r2           // clear first 13 bits
    mov     r1, #0x600
    mov     r1, r1, lsl #20         // now r1 has the delta 0x60000000
    add     r0, r0, r1              // TBR0 = 0x60404059 and we AND  0x60404059 with 0xFFFFC000 to clear least 13 bits
                                            // So it is 0x60404000 then we add the delta to get the address 0x60404000 + 0x60000000
                                            // So TBR0 = 0xC0404000
    pop     {r1-r2,pc}

// =============== S U B R O U T I N E =======================================
// get_TTBR1 then add the Delta 0x60000000
// output:
// r0 : TTBR1  0xC0404000
//========================================================================
get_TTBR1:
        // Get TTBR0 MMU Remapping Table Address
    push    {r1-r2,lr}
    
    mrc     p15, 0, r0, c2, c0, 1   // TTBR1
    mov     r2, #0x3FFF
    bic     r0, r0, r2           // clear first 13 bits
    mov     r1, #0x600
    mov     r1, r1, lsl #20         // now r1 has the delta 0x60000000
    add     r0, r0, r1              // TBR0 = 0x60404059 and we AND  0x60404059 with 0xFFFFC000 to clear least 13 bits
                                            // So it is 0x60404000 then we add the delta to get the address 0x60404000 + 0x60000000
                                            // So TBR0 = 0xC0404000
    pop     {r1-r2,pc}


// =============== S U B R O U T I N E =======================================
// get_GIC (General Interrupt Controller) Get GIC Base Address
// output:
// r0 : GIC  0x1013C000
//========================================================================
get_GIC:
        // Get TTBR0 MMU Remapping Table Address
    mrc     p15, 4, r0, c15, c0, 0  @ Read Configuration Base Address Register (CBAR)
    @ r0 now contains the REAL physical base of the GIC
    bx      lr

// =============== S U B R O U T I N E =======================================
// TTBR0_PA_VA (Updated with 20-bit Offset)
// input:
// r0: PA
// output:
// r0: VA
// r1: the PA With Attributes
// note: if output r0 = PA, No Mapping or it is remapped as is.
//========================================================================
TTBR0_PA_VA:
    push    {r2-r4,lr}
    mov     r5, r0              @ Store original PA in r5 to keep the offset

    mov     r0, r0, lsr #20     // get the most 12 bits of Desired PA

    ldr     r2, =TTBR0
    mov     r3, #0x4000
    add     r4, r2, r3          // Max Size of the TTBR0 is 16kb (16,383) => 0x3FF
    sub     r2, r2, #4
.nextOne:
    add     r2, r2, #4
    cmp     r2, r4
    bge     .no_map_found
    
    ldr     r1, [r2]
    mov     r1, r1, lsr #20     // get the most 12 bits of inspected PA
    cmp     r1, r0
    bne     .nextOne
    
    @ --- FOUND MATCH ---
    ldr     r3, =TTBR0
    sub     r0, r2, r3          // Offset = TTBR0_Address - TTBR0_Base
    mov     r0, r0, lsr #2      // Devide offset by 4
    mov     r0, r0, lsl #20     @ (Offset/4) << 20 = VA Section Base
    
    @ --- APPLY THE 20-BIT OFFSET ---
    ldr     r1, =0x000FFFFF
    and     r5, r5, r1          @ Isolate lower 20 bits of original PA
    add     r0, r0, r5          @ VA = VA_Base + Offset
    
    ldr     r1, [r2]            // return also the full PA with the mapping attributes in R1
    b       .done_pava

.no_map_found:
    mov     r0, r5              @ If no mapping found, return original PA (Identity Map assumption)

.done_pava:
    pop     {r2-r4,pc}

// =============== S U B R O U T I N E =======================================
// TTBR0_VA_PA
// input:
// r0: VA
// output:
// r0: PA
//========================================================================
TTBR0_VA_PA:
    push    {r1-r2,lr}
 
    mov     r0, r0, lsr #20     // get the most 12 bits of Desired VA
    mov     r0, r0, lsl #2      // Multiply Times 4
    
    ldr     r2, =TTBR0
    add     r2, r2, r0
    ldr     r0, [r2]
    mov     r0, r0, lsr #20     // get the most 12 bits of Target PA
    mov     r0, r0, lsl #20     // get the Full PA address

    pop     {r1-r2,pc}

// =============== S U B R O U T I N E ===================================
// Force_Identity_Map_Registers
// Maps PA 0x20000000 to VA 0x20000000 (1MB Section)
// Maps PA 0x10000000 to VA 0x10000000 (1MB Section)
// Maps PA 0x10100000 to VA 0x10100000 (1MB Section)
// Maps PA 0x7F000000 to VA 0xB0000000 (1MB Section)
//========================================================================
Force_Identity_Map_Registers:
    push    {r0-r3, lr}
    
    @ 1. Get the Writable Virtual Address of the TTBR0
    @ while the TTBR0 is 0xC0404000 but we just make sure we get it everytime to avoid conflict
    bl      get_TTBR0               @ Returns r0 = 0xC0404000 (VA)

    @ 2. --- Map Private Data Section (VA 0xB00xxxxx) ---
    @ Virtual 0xB0000000 maps to Physical 0x7F000000
    @ C=1, B=1, AP=11 (Normal Cached Memory, Full Access)
    ldr     r1, =0x7F000C0E
    mov     r3, #0x2C00
    str     r1, [r0, r3]       @ Offset: 0xB00 * 4 = 11,264 bytes

    @ Calculate L1 Entry for VA 0x20000000
    @ Create Section Descriptor:
    @ Bits [31:20] = 0x100/0x101/0x200 (Physical Base)
    @ Bit [18]     = 0     (Section, not Supersection)
    @ Bits [11:10] = 11    (AP: Full Access)
    @ Bits [8:5]   = 0000  (Domain 0)
    @ Bit [4]      = 1     (Must be 1)
    @ Bits [3:2]   = 01    (C=0, B=1 -> Sharable device)
    @ Bits [1:0]   = 10    (Section Descriptor Type)

    @ 3. Map Internal Block (0x100xxxxx)
    ldr     r1, =0x10000C02         @ PA=0x10000000, AP=11 (RW), Type=Section
    str     r1, [r0, #0x400]        @ Inject into TTBR0 + 400 => Index = 0x100. Table Offset = 0x100 * 4 = 0x400.

    @ 4. Map Internal Block (0x101xxxxx)
    ldr     r1, =0x10100C02         @ PA=0x10100000, AP=11 (RW), Type=Section
    str     r1, [r0, #0x404]        @ Inject into TTBR0 + 404 => Index = 0x101. Table Offset = 0x101 * 4 = 0x404.

    @ 5. Map Peripheral Block (0x200xxxxx)
    ldr     r1, =0x20000C02      @ Resulting hex for the entry
    str     r1, [r0, #0x800]     @ Inject into TTBR0 + 800 => Index = 0x200. Offset = 0x200 * 4 = 0x800 bytes.

    @ --- THE CLEANUP (Required for the CPU to "see" the change) ---
    mov     r3, #0
    mcr     p15, 0, r3, c7, c10, 4 @ DSB: Wait for write to finish
    mcr     p15, 0, r3, c8, c7, 0   @ Invalidate TLB: Forget old mappings
    mcr     p15, 0, r3, c7, c5, 0   @ Invalidate Instruction Cache
    isb                            @ Barrier: Start fresh from here

    pop     {r0-r3, pc}
 
 
// =============== S U B R O U T I N E =======================================
// Dump_Device_Sections
// Scans entire 16KB L1 table and prints all Device sections
//========================================================================
Dump_Device_Sections:
    push    {r0-r11, lr}

    ldr     r4, =TTBR0          @ L1 table VA base
    mov     r5, #0              @ index = 0

    add     r6, r4, #0x4000     @ end = base + 16KB

.loop_d:
    cmp     r4, r6
    bhs     .done_d

    ldr     r0, [r4]            @ r0 = L1 entry

    @ --- Check descriptor type ---
    and     r1, r0, #3
    cmp     r1, #2              @ section?
    bne     .next_d

    // the device attribute can be either
    // TEX[2:0] = 0b000 C = 0 B = 1   => Shareable Device
    // TEX[2:0] = 0b010 C = 0 B = 0   => Non-Shareable Device

    // i dunno if i may take Strongly Ordered but anyway here it is
    // TEX[2:0] = 0b000 C = 0 B = 0   => Strongly Ordered

    @ --- Extract TEX[14:12] ---
    ubfx    r7, r0, #12, #3
    ubfx    r3, r0, #2, #2     @ B & C in one step

    mov     r7, r7, lsl #2
    orr     r2, r3, r7        @ combined attribute

    mov     r11, #00

    @ --- Check Device type ---
    cmp     r2, #0x1                @ aka 0b1 TEX[2:0] = 0b000 C = 0 B = 1   => Shareable Device
    moveq   r11, #01                @ set type
    beq     .success_d

    cmp     r2, #0x8                @ aka 0b01000 TEX[2:0] = 0b010 C = 0 B = 0   => Non-Shareable Device
    moveq   r11, #02                @ set type
    beq     .success_d

    cmp     r2, #0x0                @ aka 0b0 TEX[2:0] = 0b000 C = 0 B = 0   => Strongly Ordered
    moveq   r11, #03                @ set type
    beq     .success_d

    b       .next_d
.success_d:
    @ --- Compute VA = index << 20 ---
    mov     r8, r5
    mov     r8, r8, lsl #20

    @ --- Compute PA = entry & 0xFFF00000 ---
    ldr     r10,=0x000FFFFF
    bic     r9, r0, r10

    @ --- Print VA ---
    mov     r0, r8
    bl      printHex00A

    @ --- Print PA ---
    mov     r0, r9
    bl      printHex00B

    @ --- Print Full Descriptor ---
    ldr     r0, [r4]
    bl      printHex100A

    @ --- Print Type Device ---
    mov     r0, r11
    bl      printHex100B

    //b       .done_d
    @ ---- 30 second pause here ----
    bl      delay_10s

.next_d:
    add     r4, r4, #4          @ next L1 entry
    add     r5, r5, #1          @ index++
    b       .loop_d

.done_d:
    pop     {r0-r11, pc}


// =============== S U B R O U T I N E =======================================
// Dump_L2_Tables
// Finds all L1 entries that point to L2 tables
//========================================================================
Dump_L2_Tables:
    push    {r0-r10, lr}

    mov     r3, #7      //Y
    ldr     r4, =COLOR_LIGHT_CYAN       //Color
    mov     r5, #2                      // Font Very Small this can fit 3 Hex 32 bits Characters Per line
    
    @ ---- Print Header ----
    mov     r2, #20                     // set X Start
    ldr     r1, =RAM_Injection_Start
    ldr     r0, =header_P                // " VA Base       L2 PA          L2 VA"
    add     r0, r0, r1                  // add the injection start address to the header address to correctly point to the string
    bl      printString

    add     r3, r3, #36         // next Line
    ldr     r2, =cursor_y
    str     r3, [r2]
    mov     r2, #20
    ldr     r3, =cursor_x
    str     r2, [r3]

    ldr     r4, =TTBR0          @ L1 base VA
    mov     r5, #0              @ L1 index
    add     r6, r4, #0x4000     @ end of L1

.loop_l1:
    cmp     r4, r6
    bhs     .done_l1

    ldr     r0, [r4]            @ L1 entry

    and     r1, r0, #3
    cmp     r1, #1              @ coarse page table? bits [0-1] Has to Be 0xb01
    bne     .next_l1

    @ Compute VA base of this 1MB region
    mov     r8, r5
    mov     r8, r8, lsl #20     @ VA_base = index << 20

    @ --- L2 Page Table Found ---
    mov     r1, #0x3FF
    bic     r7, r0, r1          @ r7 = bits [10-31] L2 Page Table Base Address (Physical Address)

    @ Convert L2 PA → VA using your function
    mov     r0, r7              @ r7 = L2 Physical Address (e.g., 0x797FB800)
    bl      TTBR0_PA_VA         @ Returns Section VA Base (e.g., 0xBFE00000)
    mov     r10, r0             @ r10 = L2_VA

    @ ---- Print ----
    mov     r0, r8              @ VA base
    bl      printHexAtCursor

    mov     r0, r7
    bl      printHexAtCursor     @ L2 PA

    mov     r0, r10              @ L2 VA
    bl      printHexAtCursor
    
    add     r3, r3, #30

    ldr     r2, =450
    cmp     r3, r2
    blgt    delay_10s

.next_l1:
    add     r4, r4, #4
    add     r5, r5, #1
    b       .loop_l1

.done_l1:
    pop     {r0-r10, pc}
    
// =============== S U B R O U T I N E =======================================
// Walk_L2_Table
// Input:
//   r6 = L1 index
//   r7 = L2 VA base
//========================================================================
Walk_L2_Table:
    push    {r0-r12, lr}
    mov     r0, r6
    
    mov     r3, #7      //Y
    ldr     r4, =COLOR_LIGHT_CYAN       //Color
    mov     r5, #2                      // Font Very Small this can fit 3 Hex 32 bits Characters Per line
    
    @ ---- Print Header ----
    mov     r2, #20                     // set X Start
    ldr     r1, =RAM_Injection_Start
    ldr     r0, =header                 // " Full VA       PA Base        L2 Entry"
    add     r0, r0, r1                  // add the injection start address to the header address to correctly point to the string
    bl      printString

    add     r3, r3, #36         // next Line
    ldr     r2, =cursor_y
    str     r3, [r2]
    mov     r2, #20

    // This Code Allow you To Read Even From The Blocked Addresses
    ldr     r0, =0xFFFFFFFF     @ Set all 16 domains to 0b11 (Manager mode)
    mcr     p15, 0, r0, c3, c0, 0 @ Write to DACR
    isb                         @ Instruction Barrier

    mov     r8, #0              @ L2 index
    add     r9, r7, #0x400      @ 256 entries * 4 bytes

.loop_Lev2:
    cmp     r7, r9
    bhs     .done_Lev2

    ldr     r10, [r7]            @ L2 entry

    and     r11, r10, #3
    cmp     r11, #2              @ small page executable
    beq     .cont_Lev2
    cmp     r11, #3              @ small page non-executable
    beq     .cont_Lev2
    
    b     .next_Lev2

.cont_Lev2:
    @ ---- Extract attributes (small page) ----
    ubfx    r11, r10, #6, #3     @ TEX[8:6]
    ubfx    r12, r10, #2, #2     @ B & C in one step

    mov     r11, r11, lsl #2
    orr     r11, r12, r11        @ combined attribute

    @ Check device types
    cmp     r11, #0x01          @ shareable device
    beq     .device_found

    cmp     r11, #0x08          @ non-shareable device
    beq     .device_found

    cmp     r11, #0x00          @ strongly ordered
    bne     .next_Lev2

.device_found:

    @ Compute full VA:
    @ VA = (L1_index << 20) | (L2_index << 12)
    mov     r12, r8, lsl #12

    orr     r11, r6, r12          @ full VA

    @ Compute PA base
    ldr     r12, =0xFFFFF000
    and     r12, r10, r12

    @ ---- Print ----
    mov     r0, r11              @ Full VA
    bl      printHexAtCursor

    mov     r0, r12
    bl      printHexAtCursor         @ PA Base

    mov     r0, r10              @ L2 Entry
    bl      printHexAtCursor
    
    add     r3, r3, #30         // next Line

    mov     r2, #450
    cmp     r3, r2
    blgt    delay_10s

.next_Lev2:
    add     r7, r7, #4
    add     r8, r8, #1
    b       .loop_Lev2

.done_Lev2:
    pop     {r0-r12, pc}


//###############################################################################################################
//########################################## Tools Functions ######################################################
//###############################################################################################################
//========================================================================
// dumpMem
// This function Dump the 32 bit Hex's from memory addresses
// Example if i dump start [0xD90020C0] => 0x12345678 showing 0x12345678
// Then next would be [0xD90020C4] => 0x14F5009E showing 0x14F5009E to fill 192 Hex Numbers per page
// and after 10sec next page
// starting from certain address showing a 3 x 16 hex words (8 hex digits) per page
// this is like 3 x 16 x 4 = 192 (0xC0) per page
// next page comes after 10 seconds and so on
// Input
//  r0 = Address to start from
//  r1: loop/stop state 0 = loop 1 = stop
// Output:
//========================================================================
dumpMem:
    push    {r0-r10, lr}
    
    // to do check
    //0xD900F000   ==> 0xD900F220 this address reflects from the keys
    //0xD901C800
    
    mov     r5, r0
    mov     r6, #0
.letsdoitagain_h:
    bl      blackout
    add     r0, r6, r5
    bl      printHex00A
    bl      delay_1s
    bl      blackout
    
    cmp     r1, #1
    ldreq   r9, =0x80000000
    ldrne   r9, =0x200                  // count of loops before checking next page 0x800 = around 10 sec
    mov     r2, r9
                                        // to stop the flip pages put this to 0x80000 useful to check single page
.fromstart_h:
    mov     r4, #20
    ldr     r3, =cursor_x
    str     r4, [r3]                        // reset cursors
    mov     r4, #7
    ldr     r3, =cursor_y
    str     r4, [r3]                        // reset cursors

    ldr     r11, =Temp_Data

    add     r7, r6, r5      @ ADC Base
    mov     r10, #0x30
.showmore_h:
    ldr     r0, [r7]
    ldr     r8, [r11]
    ldr     r4, =COLOR_WHITE     @ IF EQUAL:   Set color to WHITE

    
    @ --- The Register Comparison ---
    cmp     r9, r2
    beq     .skipFirstLoop_h
    cmp     r0, r8                      @ Compare Live Word to the value in R11
    ldrne   r4, =COLOR_GREEN            @ IF CHANGED: Set different color
    bne     .doNotSave_h

.skipFirstLoop_h:
    str     r0, [r11]            @ Update R11 with the new "Last Value"

.doNotSave_h:
    bl      printHexAtCursor
    add     r7, r7, #0x4
    add     r11, r11, #0x4
    subs    r10, r10, #1
    bne     .showmore_h
    subs    r9, r9, #1
    bne     .fromstart_h
    mov     r2, #0xC0
    add     r6, r6, r2                      // add next page (1024)
    b       .letsdoitagain_h

    pop {r0-r10, pc}



//========================================================================
// dumpleastHexMem
// This function Dump the Least Hex's from 32bit words
// Example if i dump start [0xD90020C0] => 0x12345678 showing 78
// Then next would be [0xD90020C4] => 0x14F5009E showing 9E to fill 1024 bytes page and after 10sec next page
// starting from certain address showing a 16 x 16 hex bytes (2 hex digits) per page
// this is like 16 x 16 x 4 = 1024 (0x400) per page
// next page comes after 10 seconds and so on
// Input
//  r0 = Address to start from
//  r1: loop/stop state 0 = loop 1 = stop
// Output:
//========================================================================
dumpleastHexMem:
    push    {r0-r11, lr}
    
    // to do check
    //0xD900F000   ==> 0xD900F220 this address reflects from the keys
    //0xD901C800
    mov     r5, r0
    mov     r6, #0
.letsdoitagain:
    bl      blackout
    add     r0, r6, r5
    bl      printHex00A
    bl      delay_1s
    bl      blackout

    cmp     r1, #1
    ldreq   r9, =0x80000000             // large enough not to change page
    ldrne   r9, =0x200                  // count of loops before checking next page 0x800 = around 10 sec
    mov     r2, r9

                                        // to stop the flip pages put this to 0x80000 useful to check single page
.fromstart:
    mov     r4, #20
    ldr     r3, =cursor_x
    str     r4, [r3]                        // reset cursors
    mov     r4, #7
    ldr     r3, =cursor_y
    str     r4, [r3]                        // reset cursors

    ldr     r11, =Temp_Data

    add     r7, r6, r5      @ ADC Base
    mov     r10, #0x100
.showmore:
    ldr     r0, [r7]
    ldr     r8, [r11]
    ldr     r4, =COLOR_WHITE     @ IF EQUAL:   Set color to WHITE
    
    @ --- The Register Comparison ---
    cmp     r9, r2
    beq     .skipFirstLoop
    cmp     r0, r8                      @ Compare Live Word to the value in R11
    ldrne   r4, =COLOR_GREEN            @ IF CHANGED: Set different color
    bne     .doNotSave

.skipFirstLoop:
    str     r0, [r11]            @ Update R11 with the new "Last Value"

.doNotSave:
    and     r12, r0, #0xFF      // Check For 0x3F Specially As this is the ADC Release Vol Keys
    cmp     r12, #0x3F
    ldreq   r4, =COLOR_PINK
    
    bl      printLeastHexAtCursor
    
    add     r7, r7, #0x4
    add     r11, r11, #0x4
    subs    r10, r10, #1
    bne     .showmore
    subs    r9, r9, #1
    bne     .fromstart
    mov     r2, #0x400
    add     r6, r6, r2                      // add next page (1024)
    b       .letsdoitagain

    pop {r0-r11, pc}

//========================================================================
// dumpBinMem
// This function Dump the 32 bit Hex's from memory addresses
// Example if i dump start [0xD90020C0] => 0x12345678 showing 0x12345678 in binary 32 bits
// Then next would be [0xD90020C4] => 0x14F5009E showing 0x14F5009E to fill 16 Hex Numbers per page
// and after 10sec next page
// starting from certain address showing a 16 x 32 binary (8 hex digits) per page
// this is like 16 x 4 = 64 (0x40) per page
// next page comes after 10 seconds and so on
// Input
//  r0 = Address to start from
//  r1: loop/stop state 0 = loop 1 = stop
// Output:
//========================================================================
dumpBinMem:
    push    {r0-r10, lr}
    
    // to do check
    //0xD900F000   ==> 0xD900F220 this address reflects from the keys
    //0xD901C800
    
    mov     r5, r0
    mov     r6, #0
.letsdoitagain_b:
    bl      blackout
    add     r0, r6, r5
    bl      printHex00A
    bl      delay_1s
    bl      blackout
    
    cmp     r1, #1
    ldreq   r9, =0x80000000
    ldrne   r9, =0x400                  // count of loops before checking next page 0x800 = around 10 sec
    mov     r2, r9
                                        // to stop the flip pages put this to 0x80000 useful to check single page
.fromstart_b:
    mov     r4, #20
    ldr     r3, =cursor_x
    str     r4, [r3]                        // reset cursors
    mov     r4, #7
    ldr     r3, =cursor_y
    str     r4, [r3]                        // reset cursors

    ldr     r11, =Temp_Data

    add     r7, r6, r5      @ ADC Base
    mov     r10, #0x10
.showmore_b:
    ldr     r0, [r7]
    ldr     r8, [r11]
    ldr     r4, =COLOR_WHITE     @ IF EQUAL:   Set color to WHITE

    
    @ --- The Register Comparison ---
    cmp     r9, r2
    beq     .skipFirstLoop_b
    cmp     r0, r8                      @ Compare Live Word to the value in R11
    ldrne   r4, =COLOR_GREEN            @ IF CHANGED: Set different color
    bne     .doNotSave_b

.skipFirstLoop_b:
    str     r0, [r11]            @ Update R11 with the new "Last Value"

.doNotSave_b:
    bl      printBinAtCursor
    add     r7, r7, #0x4
    add     r11, r11, #0x4
    subs    r10, r10, #1
    bne     .showmore_b
    subs    r9, r9, #1
    bne     .fromstart_b
    mov     r2, #0x40
    add     r6, r6, r2                      // add next page (192)
    b       .letsdoitagain_b

    pop {r0-r10, pc}


//========================================================================
// get_leap_year function
// Input
//  r0 = Year Byte 0-99 Two Digits
// Output:
//  r0: leap year bit
//      0: 365
//      1: 366
//========================================================================
get_leap_year:
    tst     r0, #3              // Bitwise AND with 3 (binary 11) to check remainder of /4
    moveq   r0, #1              // If result is 0 (Z flag set), year is divisible by 4
    movne   r0, #0              // If result is not 0, year is not divisible by 4
    bx      lr

//========================================================================
// bcd_to_bin function
// Input
//  r0 = BCD
// Output:
//  r0: BIN
//========================================================================
bcd_to_bin:
    /* r0 = bcd -> returns binary in r0 */
    mov     r1, r0              // r1 = the bcd
    and     r0, r0, #0x0F       // r0 = get lsb of the byte
    lsrs    r1, r1, #4          // r1 = gwt msb of the byte
    and     r1, r1, #0x0F       // make sure its 4 bits only
    mov     r2, #10
    mul     r1, r2, r1
    add     r0, r0, r1
    bx      lr

//========================================================================
// bin_to_bcd function
// Input
//  r0 = BIN
// Output:
//  r0: BCD
//========================================================================
bin_to_bcd:
    /* r0 = binary -> returns BCD in r0 */
    mov     r1, #0
.loopb2b:
    cmp     r0, #10
    blt     .doneb2b
    subs    r0, r0, #10
    add     r1, r1, #1
    b       .loopb2b
.doneb2b:
    lsl     r1, r1, #4
    orr     r0, r0, r1
    bx      lr

//========================================================================
// Function: vsin
// High-precision sin(x) for any x in Radians
// Formula: x - x³/6 + x⁵/120 - x⁷/5040
// Input:
//  r0: (32-bit Float)
// Output:
//  r0: (32-bit Float)
// Note: if you going to use Sine And Cosine from a calculator to check the
// results make sure you change the mode to rad when you apply a radian number
// and switch to deg when you apply a degreesº (we normally use radian in assembly)
//========================================================================
vsin:
    push                {r1-r4, lr}            // Save standard registers

    vmov.f32            s0, r0              // s0 = input x
    
    // 1. Full Circle Reduction: x = x % 2PI
    vldr.f32            s1, =0x40c90fdb       // 6.28318531     // 2PI
    vdiv.f32            s2, s0, s1
    vcvt.u32.f32        s2, s2
    vcvt.f32.u32        s2, s2
    vmls.f32            s0, s2, s1          // s0 = remainder [0, 2PI]

    // 2. Load Constants
    vldr.f32            s1, =0x3fc90fdb     //1.57079633     // PI/2
    vldr.f32            s2, =0x40490fdb     //3.14159265     // PI
    vldr.f32            s3, =0x4096cbe4     //4.71238898     // 3PI/2
    mov                 r1, #1              // Sign multiplier (Default +)

    // 3. Quadrant Reduction to [0, PI/2]
    vcmpe.f32           s0, s3              // Q4 (> 3PI/2)
    vmrs                apsr_nzcv, fpscr
    bgt                 .q4_reduce_sin

    vcmpe.f32           s0, s2              // Q3 (> PI)
    vmrs                apsr_nzcv, fpscr
    bgt                 .q3_reduce_sin

    vcmpe.f32           s0, s1              // Q2 (> PI/2)
    vmrs                apsr_nzcv, fpscr
    bgt                 .q2_reduce_sin
    b                   .calculate_sin      // Q1

.q4_reduce_sin:
    vldr.f32            s4, =0x40c90fdb       // 6.28318531
    vsub.f32            s0, s4, s0          // x = 2PI - x
    mov                 r1, #-1             // sin is neg in Q4
    b                   .calculate_sin

.q3_reduce_sin:
    vsub.f32            s0, s0, s2          // x = x - PI
    mov                 r1, #-1             // sin is neg in Q3
    b                   .calculate_sin

.q2_reduce_sin:
    vsub.f32            s0, s2, s0          // x = PI - x (Sign is + in Q2)

.calculate_sin:
    // 4. Enhanced Sine Polynomial Math (s0 is [0, PI/2])
    vmul.f32            s1, s0, s0          // s1 = x²
    vmul.f32            s2, s1, s0          // s2 = x³
    
    // Term 1 & 2: x - x³/6
    vldr.f32            s3, =0x3e2aaaab     // 1/6 (0.16666667)
    vmls.f32            s0, s2, s3          // s0 = x - (x³ * 1/6)

    // Term 3: + x⁵/120
    vmul.f32            s2, s2, s1          // s2 = x⁵
    vldr.f32            s3, =0x3c088889     // 1/120 (0.00833333)
    vmla.f32            s0, s2, s3          // s0 = s0 + (x⁵ * 1/120)

    // Term 4: - x⁷/5040 (The "Fine-Tune" term)
    vmul.f32            s2, s2, s1          // s2 = x⁷
    vldr.f32            s3, =0x39228514     // 1/5040 (0.00019841)
    vmls.f32            s0, s2, s3          // s0 = s0 - (x⁷ * 1/5040)

    // 5. Finalize Sign
    vmov                s1, r1
    vcvt.f32.s32        s1, s1
    vmul.f32            s0, s0, s1          // Apply +/-
    
    vmov.f32            r0, s0
    
    pop                 {r1-r4, lr}
    bx                  lr
//========================================================================
// Function: vcos
// High-precision cos(x) using 4-term polynomial + Quadrant Reduction
// Formula: 1 - x²/2 + x⁴/24 - x⁶/720
// Input:
//  r0: (32-bit Float)
// Output:
//  r0: (32-bit Float)
//========================================================================
vcos:
    push                {r1-r4, lr}            // Save standard registers
    
    vmov.f32            s0, r0              // s0 = input x
    
    // 1. Full Circle Reduction: x = x % 2PI
    vldr.f32            s1, =0x40c90fdb       // 6.28318531     // 2PI
    vdiv.f32            s2, s0, s1
    vcvt.u32.f32        s2, s2
    vcvt.f32.u32        s2, s2
    vmls.f32            s0, s2, s1          // s0 = remainder [0, 2PI]

    // 2. Load Constants
    vldr.f32            s1, =0x3fc90fdb     //1.57079633     // PI/2
    vldr.f32            s2, =0x40490fdb     //3.14159265     // PI
    vldr.f32            s3, =0x4096cbe4     //4.71238898     // 3PI/2
    mov                 r1, #1              // Sign multiplier (Default +)

    // 3. Quadrant Reduction to [0, PI/2]
    vcmpe.f32           s0, s3
    vmrs                apsr_nzcv, fpscr
    bgt                 .q4_reduce

    vcmpe.f32           s0, s2
    vmrs                apsr_nzcv, fpscr
    bgt                 .q3_reduce

    vcmpe.f32           s0, s1
    vmrs                apsr_nzcv, fpscr
    bgt                 .q2_reduce
    b                   .calculate

.q4_reduce:
    vldr.f32            s4, =0x40c90fdb       // 6.28318531
    vsub.f32            s0, s4, s0          // x = 2PI - x
    b                   .calculate

.q3_reduce:
    vsub.f32            s0, s0, s2          // x = x - PI
    mov                 r1, #-1
    b                   .calculate

.q2_reduce:
    vsub.f32            s0, s2, s0          // x = PI - x
    mov                 r1, #-1

.calculate:
    // 4. Enhanced Polynomial Math
    vmul.f32            s1, s0, s0          // s1 = x²
    
    // Term 1 & 2: 1.0 - x²/2
    vmov.f32            s2, #1.0
    vmov.f32            s3, #0.5
    vmls.f32            s2, s1, s3          // s2 = 1 - 0.5x²

    // Term 3: + x⁴/24
    vmul.f32            s4, s1, s1          // s4 = x⁴
    vldr.f32            s3, =0x3d2aaaab     // 1/24 (0.04166667)
    vmla.f32            s2, s4, s3          // s2 = s2 + (x⁴ * 1/24)

    // Term 4: - x⁶/720 (The "Fine-Tune" term)
    vmul.f32            s4, s4, s1          // s4 = x⁶
    vldr.f32            s3, =0x3ab60b61     // 1/720 (0.00138889)
    vmls.f32            s2, s4, s3          // s2 = s2 - (x⁶ * 1/720)

    // 5. Finalize Sign
    vmov                s0, r1
    vcvt.f32.s32        s0, s0
    vmul.f32            s2, s2, s0          // Apply +/-
    
    vmov.f32            r0, s2
    
    pop                 {r1-r4, lr}
    bx                  lr

//========================================================================
// Function: vtan_universal
// Calculates tan(x) using sin(x) / cos(x)
// Input: r0 (Float Radians)
// Output: r0 (Float Result)
//========================================================================
vtan:
    push                {r1-r4, lr}            // Save standard registers
    vpush               {s16, s17}          // Save VFP registers to stack (Very important!)
    
    mov                 r4, r0             // Store original x in s16
    
    // 1. Get Sine
    bl                  vsin                // Result r0 = sin(x)
    vmov.f32            s17, r0            // Move sin(x) to s17
    
    // 2. Get Cosine
    mov                 r0, r4             // Restore original x to s0
    bl                  vcos                // Result r0 = cos(x)
    vmov.f32            s1, r0             // Move cos(x) to s1
    
    // 3. Perform Division
    vmov.f32            s0, s17            // s0 = sin(x)
    vdiv.f32            s2, s0, s1         // s0 = sin(x) / cos(x)
    
    vmov.f32            r0, s2             // Move result back to r0
    
    vpop                {s16, s17}          // Restore VFP registers
    pop                 {r1-r4, pc}            // Return

//========================================================================
// Function: vatan2_fine_tuned
// Inputs: r0 = y (Float), r1 = x (Float)
// Output: r0 = result (Radians Float)
// Accuracy: ~4-5 decimal places
//========================================================================
vatan2:
    push                {r1-r4, lr}
    vpush               {s16-s21}
    vmov                s0, r0              // s0 = y
    vmov                s1, r1              // s1 = x

    vabs.f32            s2, s0             // s2 = |y|
    vabs.f32            s3, s1             // s3 = |x|

    // 1. Range Reduction: Ensure z is in [0, 1]
    vcmpe.f32           s3, s2            // Compare |x| and |y|
    vmrs                apsr_nzcv, fpscr
    bge                 .x_greater_than_y

    // Case: |y| > |x|
    vdiv.f32            s4, s3, s2         // z = |x| / |y|
    mov                 r2, #1              // Flag: y_was_greater
    b                   .poly_start

.x_greater_than_y:
    // Case: |x| >= |y|
    vdiv.f32            s4, s2, s3         // z = |y| / |x|
    mov                 r2, #0              // Flag: x_was_greater

.poly_start:
    // 2. High-Precision Polynomial for atan(z) on [0, 1]
    // Result = z - z^3/3 + z^5/5 - z^7/7 + z^9/9
    vmul.f32            s5, s4, s4         // s5 = z^2
    vmul.f32            s6, s5, s4         // s6 = z^3
    
    // Start Accumulation
    vmov.f32            s7, s4             // Result = z
    
    // Term -z^3/3
    vldr.f32            s8, =0x3eaaaaab    // 1/3
    vmls.f32            s7, s6, s8
    
    // Term +z^5/5
    vmul.f32            s6, s6, s5         // s6 = z^5
    vldr.f32            s8, =0x3e4ccccd    // 1/5
    vmla.f32            s7, s6, s8
    
    // Term -z^7/7
    vmul.f32            s6, s6, s5         // s6 = z^7
    vldr.f32            s8, =0x3e124925    // 1/7
    vmls.f32            s7, s6, s8
    
    // Term +z^9/9
    vmul.f32            s6, s6, s5         // s6 = z^9
    vldr.f32            s8, =0x3de38e39    // 1/9
    vmla.f32            s7, s6, s8         // s7 = final atan(z)

    // 3. Quadrant Adjustment
    cmp                 r2, #1
    it                  eq
    vldreq.f32          s8, =0x3fc90fdb  //1.57079633  // PI/2
    it                  eq
    vsubeq.f32          s7, s8, s7       // If |y|>|x|, angle = PI/2 - atan(z)

    // Check x sign
    vcmpe.f32           s1, #0            // x < 0?
    vmrs                apsr_nzcv, fpscr
    bge                 .check_y_sign

    // If x < 0, angle = PI - angle
    vldr.f32            s8, =0x40490fdb    //3.14159265    // PI
    vsub.f32            s7, s8, s7

.check_y_sign:
    // Check y sign
    vcmpe.f32           s0, #0            // y < 0?
    vmrs                apsr_nzcv, fpscr
    it                  lt
    vneglt.f32          s7, s7           // If y < 0, angle = -angle

    vmov                r0, s7              // Final result to r0
    vpop                {s16-s21}
    pop                 {r1-r4, lr}
    
    bx                  lr


//========================================================================
// delay function
// Input r0 = Delay In Seconds (0-1431 seconds, max = 23 min)
//========================================================================
delay:
    push    {r0-r1, lr}
    
    cmp     r0, #0
    bgt     .do_delay
    mov     r0, #1
.do_delay:
    ldr     r1, =ONE_SEC_DELAY
    mul     r1, r0, r1
.rep_delay:
    subs    r1, r1, #1
    bne     .rep_delay

    pop     {r0-r1, pc}
    .ltorg

// ========================================================================
// delay in Milliseconds
// input: r0 = delay in ms
// Uses: r0,r1
// ITER_PER_MS = 0x3A980 (240000) (conservative for A13@1.2GHz)
// ========================================================================
delay_ms:
    cmp     r0, #1000            @ optional cap to 1000 ms
    movgt   r0, #1000

    movw    r1, #0xA980          @ low 16 bits of 0x0003A980 (240000)
    movt    r1, #0x0003          @ high 16 bits -> r1 = 0x0003A980 (240000)

    mul     r0, r1, r0           @ r0 = ms * ITER_PER_MS  (total iterations)

    mov     r1, #0               @ counter = 0
    b       .continueItMS

.loopItMS:
    add     r1, r1, #1           @ r1 += 1

.continueItMS:
    cmp     r1, r0
    bcc     .loopItMS
    bx      lr

// =============== S U B R O U T I N E =======================================
// input:
// r0 = Delay Value
// output:
// ===========================================================================
Delay_By_r0:
    mov     r1, #0              // counter = 0
    b       .continueIt               // r2 = counter 0 till 0x64 (100)
.loopIt:
    add     r1, r1, #1              // r1 += 1
.continueIt:
    cmp     r1, r0                  // r1 - r0 0 - 0x64 = -0x64 do carry flag clear
    bcc     .loopIt
    bx      lr
// End of function Delay_By_r0

// =============== S U B R O U T I N E =======================================
// delay_10s
// (rough, adjust constant if needed)
//========================================================================
delay_10s:
    push    {r0-r2, lr}

    ldr     r0, =0x200000     @ adjust experimentally

.outer:
    ldr     r1, =0x1000
.inner:
    subs    r1, r1, #1
    bne     .inner

    subs    r0, r0, #1
    bne     .outer

    pop     {r0-r2, pc}

// =============== S U B R O U T I N E =======================================
// delay_1s
// (rough, adjust constant if needed)
//========================================================================
delay_1s:
    push    {r0-r2, lr}

    ldr     r0, =0x50000     @ adjust experimentally

.outer_1:
    ldr     r1, =0x1000
.inner_1:
    subs    r1, r1, #1
    bne     .inner_1

    subs    r0, r0, #1
    bne     .outer_1

    pop     {r0-r2, pc}








    //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    // Put your Data Variables Here
    //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

.equ GFX_Base_Address_Location, 0xC0000800
.equ GFX_VA_Address_Location,   0xC0000804
.equ GFX_PA_Address_Location,   0xC0000808
.equ GFX_Bytes_Length_Location, 0xC000080C
.equ GFX_WIDTH,                 800
.equ GFX_Height,                480

.equ COLOR_BLACK,               0x0000   //Black
.equ COLOR_WHITE,               0xFFFF   //White
.equ COLOR_RED,                 0xF800   //Red
.equ COLOR_GREEN,               0x07E0   //Green
.equ COLOR_BLUE,                0x001F   //Blue
.equ COLOR_YELLOW,              0xFFE0   //Yellow
.equ COLOR_CYAN,                0x07FF   //Cyan
.equ COLOR_MAGENTA,             0xF81F   //Magenta
.equ COLOR_LIGHT_RED,           0xFD0B   //Light Red
.equ COLOR_LIGHT_GREEN,         0x87F0   //light Green
.equ COLOR_LIGHT_BLUE,          0x841F   //Light Blue
.equ COLOR_LIGHT_YELLOW,        0xFFF8   //light Yellow
.equ COLOR_LIGHT_CYAN,          0xE7FF   //Light Cyan
.equ COLOR_LIGHT_PURPLE,        0xCC39   //light Purple
.equ COLOR_LIGHT_AMBER,         0xFDC9   //light Amber
.equ COLOR_OLIVE_GREEN,         0x8400   //Olive Green
.equ COLOR_PINK,                0x8010   //Pink
.equ COLOR_TURQUOISE,           0x471A   //Turquoise

.equ backgroundColor,           COLOR_BLACK
.equ clockColor,                COLOR_BLACK
.equ dotsColor,                 COLOR_WHITE
.equ secondsColor,              COLOR_RED
.equ minsColor,                 COLOR_LIGHT_GREEN
.equ hoursColor,                COLOR_LIGHT_AMBER
.equ digiClockColor,            COLOR_GREEN
.equ digiClockColor2,           COLOR_LIGHT_CYAN
.equ centerColor,               COLOR_LIGHT_BLUE
.equ amColor,                   COLOR_LIGHT_CYAN
.equ pmColor,                   COLOR_RED
.equ editColor,                 COLOR_LIGHT_BLUE
.equ testColor,                 COLOR_TURQUOISE


// FPU
.equ ∏,                         0x40490FDB      // 3.14159265359 IEEE-754 single-precision bit pattern for Pi ()
.equ d∏,                        0x42652EE1      // 57.29577951      // 180 / ∏ ===> fit for radian to degree
.equ ∏d,                        0x3C8EFA35      // 0.01745329       // ∏ / 180 ===> fit for degree to radian
.equ two∏,                      0x40C90FDB      // 6.28318531       // 2 * ∏
.equ sAngle,                    0x3DD638D1      // 0.10471976    // 6º * (pi /180)  360º/60 = 6º


.equ ONE_SEC_DELAY,             3500000        // for 1hz SPµs = [1,000,000/ (1 * 4)] = 250,000µs
                                               // ONE_SEC_DELAY = (250,000µs * 1,200) / 100 = 3,000,000
                                               // but this is not so precice so with trial and error i reached to
                                               // 3,500,000


//####################################################################################################################
//
//                              Data Buffers R/W
//
// Here Starts the Data Buffers But Since the MMU Blocks Writing on the Area Where Logo Is We Divert it to R/W Address
// You Need to know that in ARM all buffers definations are zero no predefined numbers unless .equ
// so you need to str the numbers in the buffers in order to define it
//####################################################################################################################

.equ HEX_S,                     Data_BASE + 0x00        // .word    0x00000000
.equ HEX_M,                     Data_BASE + 0x04        // .word    0x00000000
.equ HEX_H,                     Data_BASE + 0x08        // .word    0x00000000
.equ HEX_W,                     Data_BASE + 0x0C        // .word    0x00000000
.equ HEX_D,                     Data_BASE + 0x10        // .word    0x00000000
.equ HEX_N,                     Data_BASE + 0x14        // .word    0x00000000
.equ HEX_Y,                     Data_BASE + 0x18        // .word    0x00000000
.equ HEX_L,                     Data_BASE + 0x1C        // .word    0x00000000

.equ prev_S,                    Data_BASE + 0x20        // .word    0x00000000
.equ currentS0,                 Data_BASE + 0x24        // .word    0x00000000
.equ currentS1,                 Data_BASE + 0x28        // .word    0x00000000
.equ currentM0,                 Data_BASE + 0x2C        // .word    0x00000000
.equ currentM1,                 Data_BASE + 0x30        // .word    0x00000000
.equ currentH0,                 Data_BASE + 0x34        // .word    0x00000000
.equ currentH1,                 Data_BASE + 0x38        // .word    0x00000000
.equ currentW0,                 Data_BASE + 0x3C        // .word    0x00000000

.equ currentW1,                 Data_BASE + 0x40        // .word    0x00000000
.equ currentD0,                 Data_BASE + 0x44        // .word    0x00000000
.equ currentD1,                 Data_BASE + 0x48        // .word    0x00000000
.equ currentN0,                 Data_BASE + 0x4C        // .word    0x00000000
.equ currentN1,                 Data_BASE + 0x50        // .word    0x00000000
.equ currentT0,                 Data_BASE + 0x54        // .word    0x00000000
.equ currentT1,                 Data_BASE + 0x58        // .word    0x00000000
.equ currentT2,                 Data_BASE + 0x5C        // .word    0x00000000

.equ currentY0,                 Data_BASE + 0x60        // .word    0x00000000
.equ currentY1,                 Data_BASE + 0x64        // .word    0x00000000
.equ currentY2,                 Data_BASE + 0x68        // .word    0x00000000
.equ currentY3,                 Data_BASE + 0x6C        // .word    0x00000000
.equ counter,                   Data_BASE + 0x70        // .word    0x00000000
.equ index,                     Data_BASE + 0x74        // .word    0x00000000
.equ ampm,                      Data_BASE + 0x78        // .word    0x00000000
.equ monthMode,                 Data_BASE + 0x7C        // .word    0x00000000

.equ batteryMode,               Data_BASE + 0x80        // .word    0x00000000
.equ prevHEX_S,                 Data_BASE + 0x84        // .word    0x00000000
.equ prevHEX_M,                 Data_BASE + 0x88        // .word    0x00000000
.equ prevHEX_H,                 Data_BASE + 0x8C        // .word    0x00000000
.equ prevDistSecX,              Data_BASE + 0x90        // .word    0x00000000
.equ prevDistSecY,              Data_BASE + 0x94        // .word    0x00000000
.equ prevDistMinX,              Data_BASE + 0x98        // .word    0x00000000
.equ prevDistMinY,              Data_BASE + 0x9C        // .word    0x00000000

.equ prevDistHorX,              Data_BASE + 0xA0        // .word    0x00000000
.equ prevDistHorY,              Data_BASE + 0xA4        // .word    0x00000000
.equ X0,                        Data_BASE + 0xA8        // .word    0x00000000
.equ Y0,                        Data_BASE + 0xAC        // .word    0x00000000
.equ X1,                        Data_BASE + 0xB0        // .word    0x00000000
.equ Y1,                        Data_BASE + 0xB4        // .word    0x00000000
.equ .ct,                       Data_BASE + 0xB8        // .word    0x00000000
.equ .newXa,                    Data_BASE + 0xBC        // .word    0x00000000

.equ .newYa,                    Data_BASE + 0xC0        // .word    0x00000000
.equ .Sl,                       Data_BASE + 0xC4        // .word    0x00000000
.equ .X0b,                      Data_BASE + 0xC8        // .word    0x00000000
.equ .Y0b,                      Data_BASE + 0xCC        // .word    0x00000000
.equ .Çºb,                      Data_BASE + 0xD0        // .word    0x00000000
.equ .X1,                       Data_BASE + 0xD4        // .word    0x00000000
.equ .Y1,                       Data_BASE + 0xD8        // .word    0x00000000
.equ .∆X,                       Data_BASE + 0xDC        // .word    0x00000000

.equ .∆Y,                       Data_BASE + 0xE0        // .word    0x00000000
.equ .rad,                      Data_BASE + 0xE4        // .word    0x00000000
.equ .len,                      Data_BASE + 0xE8        // .word    0x00000000
.equ .newXb,                    Data_BASE + 0xEC        // .word    0x00000000
.equ .newYb,                    Data_BASE + 0xF0        // .word    0x00000000
.equ .X0p,                      Data_BASE + 0xF4        // .word    0x00000000
.equ .Y0p,                      Data_BASE + 0xF8        // .word    0x00000000
.equ .Çºp,                      Data_BASE + 0xFC        // .word    0x00000000

.equ .Øº,                       Data_BASE + 0x100       // .word    0x00000000
.equ .ra,                       Data_BASE + 0x104       // .word    0x00000000
.equ .ri,                       Data_BASE + 0x108       // .word    0x00000000
.equ .newXc,                    Data_BASE + 0x10C       // .word    0x00000000
.equ .newYc,                    Data_BASE + 0x110       // .word    0x00000000
.equ .cf,                       Data_BASE + 0x114       // .word    0x00000000
.equ .segº,                     Data_BASE + 0x118       // .word    0x00000000
.equ .comparetor,               Data_BASE + 0x11C       // .word    0x00000000

.equ cResult,                   Data_BASE + 0x120       // .word    0x00000000
.equ radius,                    Data_BASE + 0x124       // .word    0x00000000
.equ fResult,                   Data_BASE + 0x128       // .word    0x00000000
.equ ddStore,                   Data_BASE + 0x12C       // .word    0x00000000
.equ dwStore,                   Data_BASE + 0x130       // .word    0x00000000
.equ dbStore,                   Data_BASE + 0x134       // .word    0x00000000

.equ outputDec,                 Data_BASE + 0x138       // 60 (0x3C) Words
.equ outputHex,                 Data_BASE + 0x174       // 40 (0x28) Words
.equ outputIEEE,                Data_BASE + 0x19C       // 128 (0x80) Words
// Read Only Section Could Be Strings

Empty:                                              //128 Words
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
            .word               0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000

hello:
            .string32           "Hello World!"      // notice .string32 added the 0x0 at the end automatiucally

header:
            .string32           " Full VA       PA Base        L2 Entry"     // notice .string32 added the 0x0 at the end automatiucally

header_P:
            .string32           " VA Base       L2 PA          L2 VA"     // notice .string32 added the 0x0 at the end automatiucally

    //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    // End of Boot Section 0x2000FFFF
    //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    .word 0xFFFF0020                          // 2000FFFF

    //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    // Pad the file to exactly 24576 bytes - 32 for the data section
    // Note the file size have to be divisible on 512 less than 32k
    // we can use 28672 (28k)
    //>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    //.space (24576 - (. - _start)) - 32          // 24K

    .space (28672 - (. - _start)) - 32            // 28K  +304 boot1 difference


    // Warning :actual codes without .space line is 23,168 so far so we have like 5504 bytes left
    // it is better to try to separate files into boot1 and boot0.


