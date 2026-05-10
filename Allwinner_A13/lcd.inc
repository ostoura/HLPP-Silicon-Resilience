
// ========================================================================
// Bare-metal configuration for Allwinner A13
// Assembly for ARM Cortex-A8
//
// Reference for Cross Platform Conversion
//
//---------------------------------
// ARM      |X64/86 |  M1   |
//---------------------------------
// r0       | rax   |  X0   |
// r1       | rbx   |  X1   |
// r2       | rcx   |  X2   |
// r3       | rdx   |  X3   |
// r4       | any   |  X4   |
// r5       | any   |  X5   |
// r6       | rsi   |  X6   |
// r7       | rdi   |  X7   |
// r8       | r8    |  X8   |
// r9       | r9    |  X9   |
// r10      | r10   |  X10  |
// r11      | rbp   |  X11  |
// r12      | r12   |  X12  |
// r13/SP   | rsp   |  X13  |
// r14/LR   | ---   |  X14  |
// r15/PC   | rip   |  X15  |

//  x64 Register (64-bit)     ARMv7 Register (32-bit)    Common Functional Role
//  RAX    R0    Return value from functions; primary accumulator
//  RCX    R0 (or R1-R3)    1st function argument (Windows x64) / Counter
//  RDX    R1 (or R2)    2nd function argument / High-order result bits
//  RBX    R4 – R8    Callee-saved general-purpose storage (Non-volatile)
//  RSP    R13 (SP)    Stack Pointer
//  RBP    R11 (FP)    Frame Pointer (Base pointer for local stack frame)
//  RSI / RDI    R4 – R10    Source/Destination indices (often just general storage in ARM)
//  RIP    R15 (PC)    Program Counter (points to next instruction)
//  RFLAGS    CPSR / APSR    Status/Condition flags (Zero, Carry, Overflow, etc.)
//  (None)    R14 (LR)    Link Register: Stores return address (x64 uses the stack instead)
//
//  Key Differences to Note
//  Register Width:
//      x64 registers are 64-bit, whereas ARMv7 registers are 32-bit.
//      To store a 64-bit value in ARMv7, you typically use a register pair (e.g., R0 and R1).
//  Return Addresses:
//      ARMv7 uses a dedicated Link Register (R14) to hold the return address after a branch.
//      x64 pushes the return address directly onto the stack.
//  Argument Passing:
//  x64 (Windows):
//      Uses RCX, RDX, R8, R9 for the first four arguments.
//  x64 (Linux/System V):
//      Uses RDI, RSI, RDX, RCX, R8, R9.
//  ARMv7: Consistently uses R0 through R3 for the first four arguments.
//      Program Counter Access: On ARMv7, the PC (R15) is directly accessible and can be used in many instructions.
//      On x64, RIP cannot be directly modified by most instructions; you must use branches or RIP-relative addressing.
//
//  Condition                   ARM (Branch)        x86 (Jump)          Flag Condition Tested
// ----------------------------------------------------------------------------------------------------------
//  Equal / Zero                BEQ                 JE / JZ                 Z == 1
//  Not Equal / Not Zero        BNE                 JNE / JNZ               Z == 0
//  Unsigned Higher or Same     BHS (or BCS)        JAE / JNB / JNC         C == 1
//  Unsigned Lower              BLO (or BCC)        JB / JNAE / JC          C == 0
//  Unsigned Higher             BHI                 JA / JNBE               C == 1 AND Z == 0
//  Unsigned Lower or Same      BLS                 JBE / JNA               C == 0 OR Z == 1
//  Signed Greater or Equal     BGE                 JGE / JNL               N == V (ARM) / SF == OF (x86)
//  Signed Less Than            BLT                 JL / JNGE               N != V (ARM) / SF != OF (x86)
//  Signed Greater Than         BGT                 JG / JNLE               Z == 0 AND N == V
//  Signed Less or Equal        BLE                 JLE / JNG               Z == 1 OR N != V            
//
// Important Note:
// In ARM Assembly Do Not Put The Function Internal Data Buffers inside The Function it self But Rather inside the .data Section
// This is very crucial cause we notice that the data inside The Function is very Weak and Exposed to be used by the CPU as temp. RAM
// specially if the .ltorg is Used.
// More Safer Way is to Add The Data only in the .data Section even if its related to Certain Function
// and you are free to add a dot before lable and/or add a remark comment to know which data related to which function.
//
//
//
//
// Legend As From Firmware Coding:
//
//>>>>>>>>>>>>>>>>>>>>>>>>>> REGISTERS CODES <<<<<<<<<<<<<<<<<<<<<<<<<<<<
// 0x21 => LCD_CH0_CFG_REG set bit[31] turn on clk inCode Label: h_lcd0ch0mclk0
// 0x1C => BE_CFG_REG bits[0-31] inCode Label: h_debe0mclk
// 0x1E => FE_CFG_REG bits[0-31] inCode Label: h_defe0mclk
// 0x88 => DRAM_SCLK_CFG_REG => BE Dclk Gatting bit[26] inCode Label: h_debe0dramclk
// 0x86 => DRAM_SCLK_CFG_REG => FE Dclk Gatting bit[25] inCode Label: h_defe0dramclk
// 0x62 => AHB_GATING_REG1 => BE_AHB_GATING bit[12] inCode Label: h_debe0ahbclk
// 0x64 => AHB_GATING_REG1 => FE_AHB_GATING bit[14] inCode Label: h_defe0ahbclk
// 0x5D => AHB_GATING_REG1 => LCD_AHB_GATING bit[4] inCode Label: h_lcd0ahbclk
//
//>>>>>>>>>>>>>>>>>>>>>>>>>> PLLs CODES <<<<<<<<<<<<<<<<<<<<<<<<<<<<
// 0x6 => PLL3 (in Frequency 3mhz out Frequency Set to 297mhz M = 0x63(99) Fraction = 0)
// 0xD => PLL7 (in Frequency 3mhz out Frequency Set to 297mhz M = 0x63(99) Fraction = 0)
// 0x7 => PLL3x2
// 0xE => PLL7x2
// 0x9 => PLL5
// 0x5 => PLL6 (in Frequency 48mhz out Frequency Set to 321mhz M = 0x6(6) Fraction = 33mhz)
//
//>>>>>>>>>>>>>>>>>>>>>>>>>> STEP By STEP <<<<<<<<<<<<<<<<<<<<<<<<<<<<
// 1- Power_Management_Engines_Init
//  a) TWI0_Init        For PMU (LCD Power, Backlight, Battery Charge LED Etc.)
//  b) LED_Slow_Flash
// 2- Display_Engines_Init                                                      inCode Sub: BSP_disp_init
//  a) Sets PLL3 & PLL7 Frequency To 297mhz By Setting M to (0x63)99 AKA Default    inCode Sub: disp_pll_init VIMP
//      i> Detect The Correct M Value By deviding Desired / Source 297mhz/3mhz
//      ii> PLLx_Enable Set bit[31] 0:En & Set bits[0-6] 0x63(99): PLLx_Factor_M
//      iii> Make Sure All is 0x8010D063 (P.S. Default is 0x0010D063)
//  b) Init FE NC.                                                                  inCode Label: Scaler_Init NC.
//      i> Init FE Clock NC.                                                            inCode Sub: scaler_clk_init
//          - FE_CFG_REG Clear bit[30] 0:Assert(reset valid)                                inCode Label: h_defe0mclk
//          - FE_CFG_REG Set bits[24-25] 0b10:PLL7 Set FE to PLL7 (297mhz|99|0)             inCode Label: h_defe0mclk
//          - FE_CFG_REG Set bits[0-3] 0:CLK_DIV_RATIO_M make sure no devider               inCode Label: h_defe0mclk
//          - FE_AHB_GATING Set bit[14] 1:Pass                                              inCode Label: h_defe0ahbclk
//          - FE_CFG_REG Set bit[31] 1:Enable       ????                                    inCode Label: h_defe0mclk
//          - FE_CFG_REG Set bit[31] 0:Disable      ????                                    inCode Label: h_defe0mclk
//          - FE Dclk Gatting Set bit[25] 1:Pass    ????                                    inCode Label: h_defe0dramclk
//          - FE Dclk Gatting Set bit[25] 0:Mask    ????                                    inCode Label: h_defe0dramclk
//  c) Init BE VIMP.                                                                inCode Label: Image_init
//      i> Init BE Clock                                                                inCode Sub: image_clk_init
//          - BE_CFG_REG Clear bit[30] 1:Deassert                                           inCode Label: h_debe0mclk
//          - BE_CFG_REG Set bits[24-25] 0b00:PLL3 Set BE to PLL3 (297mhz|99|0)             inCode Label: h_debe0mclk
//          - Check Frequency NC.       it gives zero in BE But it is Ok in code
//          - BE_CFG_REG Set bits[0-3] 0:CLK_DIV_RATIO_M make sure no devider               inCode Label: h_debe0mclk
//          - BE_AHB_GATING Set bit[12] 1:Pass                                              inCode Label: h_debe0ahbclk
//          - BE Dclk Gatting Set bit[26] 1:Pass                                            inCode Label: h_debe0dramclk
//          - BE Dclk Gatting Set bit[26] 0:Mask                                            inCode Label: h_debe0dramclk
//          - BE_CFG_REG Set bit[31] 1:Enable                                               inCode Label: h_debe0mclk
//      ii> Turn On BE Clock                                                            inCode Sub: image_clk_on
//      iii> Clean BE Registers All BE Registers Have To Be Zero before proceed (Bug)   inCode Sub: DE_BE_Reg_Init
//      iv> Clean Display Sprite I guess this is when you clean the Video Memory        inCode Sub: BSP_disp_sprite_init
//      v> Search for The Script FEX that has LCD Data (Already Hard Coded)             inCode Sub: BSP_disp_set_output_csc
//      vi> Turn On And Start BE Using DEBE_MODCTL_REG                                  inCode Sub: Image_open
//          - START_CTL Set bit[1] 1:Start                                              inCode Sub: DE_BE_Enable
//          - DEBE_EN Set bit[0] 1:Enable                                               inCode Sub: DE_BE_Enable
//  d) Init TCON VIMP.                                                              inCode Label: Disp_lcdc_init
//      i> Init TCON Clock                                                              inCode Sub: lcdc_clk_init
//          - LCD_CH0_CFG_REG Set bits[24-25] 0b00:PLL3 Set BE to PLL3 (297mhz|99|0)        inCode Label: h_lcd0ch0mclk0
//          - LCD_CH0_CFG_REG Clear bit[30] 1:Deassert                                      inCode Label: h_lcd0ch0mclk0
//          - LCD_CH0_AHB_GATING Set bit[4] 1:Pass                                          inCode Label: h_lcd0ahbclk
//          - LCD_CH0_CFG_REG Set bit[31] 1:Enable                                          inCode Label: h_lcd0ch0mclk0
//          - LCD_CH0_CFG_REG Set bit[31] 0:Disable                                         inCode Label: h_lcd0ch0mclk0
//      ii> Turn On TCON Clock                                                          inCode Sub: lcdc_clk_on
//          - LCD_CH0_CFG_REG Set bit[31] 1:Enable                                          inCode Label: h_lcd0ch0mclk0
//      iii> Init LCD Controller                                                        inCode Sub: LCDC_init
//          - Close TCON0 ((Disable TCON0 And Set TCON0_IO_TRI_REG Default)                 inCode Sub: TCON0_close
//              #TCON0_CTL_REG Clear Bit[31] TCON_EN 0:Disable
//              #TCON0_IO_TRI_REG Set Bit[0-31] 0xFFFFFFFF (Default)
//          - Enable Interrupts                                                             inCode Sub: LCDC_enable_int
//              #TCON_GINT0_REG Set bit[31] get current and orr to 0x80000000
//              #TCON_GINT0_REG Set bit[30] get current and orr to 0x40000000
//              #TCON_GINT0_REG Set bit[29] get current and orr to 0x20000000
//              #TCON_GINT0_REG Set bit[28] get current and orr to 0x10000000
//          - Select Source                                                                inCode Sub: BSP_disp_set_output_csc
//              #TCON0_CTL_REG Clear Bits[22] TCON0_Test_Value 0:all black
//              #TCON0_CTL_REG Clear Bit[0-1] TCON0_SRC_SEL 0b00:select DE Ch1
//          - Turn On TCON0                                                                 inCode Sub: LCDC_open
//              #TCON0_DCLK_REG Bit[31] TCON0_Dclk_En 1:Enable
//              #TCON_GCTL_REG Bit[31] TCON_EN 1:Enable
//      iv> Turn Off LCD Clock                                                          inCode Sub: lcdc_clk_off
//          - LCD_CH0_CFG_REG Clear Bit[31] 0:Disable
// 3- Set & Clean Graphics Frame Buffer
//  a) Fill Framebuffer with Black Background (00)                  make sure none is on memory
//
//  b) Clean CACHE                                                  make sure none is remaining from last startup
//
// 4- Display_Startup
//  a) LCD_Panel_Power_Enable                                       turn off backlight, give power to LCD Panel
//      i> Turn Off Backlight
//      ii> Delay 20-40 ms                                              Give the backlight 20-40ms to turn off & power up the panel
//      iii> LCD_PWR_ON                                                 Send PIO Signal to Power The LCD (Default is On)
//  b) BE_Mode_Set                                                  set mode of DEBE and DEFE
//      i> DE_BE_Layer_Set_Format
//          - DEBE_ATTCTL0_REG1 Set bits[8-11] LAY_FBFMT 0b1010(0xA)(10): 32 bit Color
//          - DEBE_ATTCTL0_REG1 Set bits[0-1] LAY_FBPS PS Pixels Sequence For 32bitBbp: 0b00 (0) = ARGB (Default)
//          - DEBE_ATTCTL0_REG1 Set bit[2] 0: LAY_BRSWAPEN 0:RGB
//      ii> SET_GFX_ADDRESS_TO_DEBE                                                          inCode Sub: lcdc_clk_on
//          - DEBE_LAYFB_L32ADD_REG0 Set bit2[4-31] Lower Nibble Of the Framebiffer address
//          - DEBE_LAYFB_H4ADD_REG Set bit2[0-3] High Nibble Of the Framebiffer address to layer0
//      iii> SET_GFX_LINE_WIDTH_IN_BITS
//          - DEBE_LAYLINEWIDTH_REG0 Set bits[0-31] lcd_x * 32 aka lcd_x * (4 * 8)
//      iv> DEBE_Set_Alpha to 0xFF Full Opaque
//          - DEBE_ATTCTL0_REG0 Set bits[24-31] LAY_GLBALPHA 0xFF: Full Opaque
//      v> DEBE_Set_Screen_Win (Set the point of the upper left corner of the Layer Window and to the size of (w x h)
//          - DEBE_LAYCOOR_REG0 Set bits[0-15] Layer Y  0 And Set bits[16-31] Layer X 0  Start Draw Layer At (0, 0)
//          - DEBE_LAYSIZE_REG0 Set bits[0-15] (lcd_y - 1) And Set bits[16-31] (lcd_x - 1) lcd_x & lcd_y from Script.fex
//      vi> DEBE_Set_Full_Resolution
//          - DEBE_DISSIZE_REG Set bits[0-15] (lcd_y - 1) And Set bits[16-31] (lcd_x - 1) lcd_x & lcd_y from Script.fex
//      vii> DEBE_Enable_Layer_0
//          - DEBE_MODCTL_REG Set bit[8] LAY0_EN 1:Enable
//  c) LCD_PIO_Set                                                  set mode of TCON
//      i> PIO_PD_CFG0 Set bits[8-31] as 0x22222200 ==> PD2-PD7 to M2
//      ii> PIO_PD_CFG1 Set bits[8-31] as 0x22222200 ==> PD10-PD15 to M2
//      iii> PIO_PD_CFG2 Set bits[8-31] as 0x22222200 ==> PD18-PD23 to M2
//      iv> PIO_PD_CFG3 Set bits[8-31] as 0x2222 ==> PD24-PD27 to M2
//  d) LCD_Mode_Set
//      i> Open TCON0 ((Enable TCON0, Set STATE_Delay to Max & Clear TCON0_IO_TRI_REG Aka Turn On)
//          - LCD_CH0_CFG_REG Set Bit[31] TCON_EN 1:Enable
//          - TCON0_CTL_REG Set Bits[4-8] STA delay = 30 (delay = vfp+vspw+vbp = 570) but max delay = 30
//          - TCON0_CTL_REG Set Bit[31] TCON_EN 1:Enable
//      ii> Set Display Ram Clock Timing
//          - TCON0_DCLK_REG Set Bits[0-6] DCLK_Div 8:(m - 1) 297Mhz / 9 = 33Mhz As per Script.fex (Can Be 4 - 6 if flicker)
//      iii> Configure Panel Resolution
//          - TCON0_BASIC0_REG Set bits[0-15] (lcd_y - 1) And Set bits[16-31] (lcd_x - 1) lcd_x & lcd_y from Script.fex
//      iv> Configure Horizontal Timing ===>>>> Notice (ht - 1) is Crucial and have to be (1055 - 1) exactly to avoid flicker
//          - TCON0_BASIC1_REG Set bits[0-15] (hbp - 1) And Set bits[16-31] (ht - 1) Essential (1055 - 1) from Script.fex
//      v> Configure Vertical Timing
//          - TCON0_BASIC2_REG Set bits[0-15] (vbp - 1) And Set bits[16-31] (vt - 1) from Script.fex
//      vi> Configure HSYNC_PW And VSYNC_PW
//          - TCON0_BASIC3_REG Set bits[0-15] (lcd_hv_vspw - 1) And Set bits[16-31] (lcd_hv_hspw - 1) from Script.fex
//      vii> Enable IO TRI
//          - TCON0_IO_TRI_REG Clear Bits[0-31] 0x00000 0's:Enable
// 5- Turn_On_Backlight
//  a) delay 1 seconds                                                   // Give time for The display to Scan At Least twice On
//  b) Backlight On
//  c) BCK_L_CTRL                                                       // Brightness Control set 100%  0: 100% 10: 0%
// 6- RTC_Init
//  a) TWI1_Init        For RTC (RealTime Calender)
//  b) LED Release
// ===================================================================================================================================
.equ CCM_BASE,                      0x01C20000      // Base address for the CCM Clock 5.3 page 57
.equ PIO_BASE,                      0x01C20800      // Base address for the PIO controller  PIO = GPIO
.equ ASYNC_Timer_BASE,              0x01C20C00      // Base address for ASync Timer (it include RTC at Offset 0x100 - 0x13C)
.equ PWM_BASE,                      0x01C20C00      // Base address for the PWM controller 0x01C20C00 9.2 page 83
.equ TWI0_BASE,                     0x01C2AC00      // Base address for the TWI0 Two Wire Interface Controlling AXP209 PMU
.equ TWI1_BASE,                     0x01C2B000      // Base address for the TWI1 controlling AT8563S RTC Realtime Controller
.equ TWI2_BASE,                     0x01C2B400      // Base address for the TWI2 controlling CSI Camera Serial Interface
.equ TCON_BASE,                     0x01C0C000      // Base address for the TCON Controller (LCD/TV Timing Controller)
.equ DEFE_BASE,                     0x01E00000      // Base address for the DE FE Controller (Display Engine Front End)
.equ DEBE_BASE,                     0x01E60000      // Base address for the DE BE Controller (Display Engine Back End)
.equ LRADC_BASE,                    0x01C22800      // Base address for the LRADC Controls Keys Vol up / Vol Down

// --- AXP209 Address ---
.equ AXP209_BASE,                   0x68            // Base address for AXP209 bit[0] R/W 0b0 = Write 0b1 = Read
                                                    // 0x68 used as a Write Address, Use 0x69 for Read
.equ AXP209_SHUT_VOLT_SET_REG,      0x31            // Controls AXP209 SLEEP And WAKEUP
.equ AXP209_SHUT_BATT_CHGLED_REG,   0x32            // Controls AXP209 Shut Down, Battery Charging, And Charging LED
.equ AXP209_CHRG_CTRL1_REG,         0x33            //
.equ AXP209_CHRG_CTRL2_REG,         0x34            //
.equ AXP209_BACKUP_BAT_CTRL_REG,    0x35            // Backup battery charge control
.equ AXP209_PEK_PARAMETERS_REG,     0x36            // Control Long Press Seconds, USing Key For Shut Down, And Time To Shutdown

.equ IRQ_Enable1,                   0x40            // ACIN and VBus Enabling Check For Conditions (Default is Checking for All)
.equ IRQ_Status1,                   0x48            // ACIN and VBus Status Over Voltage, Connecting/Disconnecting
.equ IRQ_Enable2,                   0x41            // Battery Enabling Conditions (Default is All Bits On)
.equ IRQ_Status2,                   0x49            // Battery Status
.equ IRQ_Enable3,                   0x42            // Enabling Check For DC Current Conditions And Detect Power Button
.equ IRQ_Status3,                   0x4A            // DC Current Status And Power Button Status
.equ IRQ_Enable4,                   0x43            //
.equ IRQ_Status4,                   0x4B            //
.equ IRQ_Enable5,                   0x44            //
.equ IRQ_Status5,                   0x4C            //

.equ AXP209_GPIO0_REG,              0x90            // GPIO0 Address for LCD Power, bits [0:2]
                                                    // Default State is On (3.3v) in FEL Mode, 0b000 = 0v  0b001 = 3.3v
.equ AXP209_GPIO1_REG,              0x92            // GPIO1 Address for LCD Back Light, bits [0:2]
                                                    // Default State is Off (0v) in EFL Mode, 0b000 = 0v  0b001 = 3.3v
.equ COULOMB_CHG_BAT_METER0,        0xB0            // Coulomb charging the battery meter data register[31: 24]
.equ COULOMB_CHG_BAT_METER1,        0xB1            // Coulomb charging the battery meter data register[23: 16]
.equ COULOMB_CHG_BAT_METER2,        0xB2            // Coulomb charging the battery meter data register[15: 8]
.equ COULOMB_CHG_BAT_METER3,        0xB3            // Coulomb charging the battery meter data register[7: 0]
.equ COULOMB_DISCHG_BAT_METER0,     0xB4            // Coulomb discharging the battery meter data register[31: 24]
.equ COULOMB_DISCHG_BAT_METER1,     0xB5            // Coulomb discharging the battery meter data register[23: 16]
.equ COULOMB_DISCHG_BAT_METER2,     0xB6            // Coulomb discharging the battery meter data register[15: 8]
.equ COULOMB_DISCHG_BAT_METER3,     0xB7            // Coulomb discharging the battery meter data register[7: 0]
.equ COULOMB_COUNTER_CONTROL,       0xB7            //
.equ AXP209_FUEL_GAUGE,             0xB9            // Battery Percentage And Set Battery Mode

// --- AT8563S Address ---
.equ AT8563S_BASE,                  0xA2            // Base address for AT8563S bit[0] R/W 0b0 = Write 0b1 = Read
                                                    // 0xA2 used as a Write Address, Use 0xA3 for Read
.equ AT8563S_Control_status_1,      0x0             //
.equ AT8563S_Control_status_2,      0x1             //
.equ AT8563S_VL_seconds,            0x2             // Read And Write bits [0-6]
.equ AT8563S_Minutes,               0x3             // Read And Write bits [0-6]
.equ AT8563S_Hours,                 0x4             // Read And Write bits [0-5]
.equ AT8563S_Days,                  0x5             // Read And Write bits [0-5]
.equ AT8563S_Weekdays,              0x6             // Read And Write bits [0-2]
.equ AT8563S_Century_months,        0x7             // Read And Write bits [0-4] bit[7] century 0:x 1:x+1
.equ AT8563S_Years,                 0x8             // Read And Write bits [0-7]
.equ AT8563S_Minute_alarm,          0x9             // Read And Write bits [0-6] bit[7] Enable Alarm
.equ AT8563S_Hour_alarm,            0xA             // Read And Write bits [0-5] bit[7] Enable Alarm
.equ AT8563S_Day_alarm,             0xB             // Read And Write bits [0-5] bit[7] Enable Alarm
.equ AT8563S_Weekday_alarm,         0xC             // Read And Write bits [0-2] bit[7] Enable Alarm
.equ AT8563S_CLKOUT_control,        0xD             // Read And Write bits [0-6]
.equ AT8563S_Timer_control,         0xE             // Read And Write bits [0-6]
.equ AT8563S_Timer,                 0xF             // Read And Write bits [0-6]


// --- LRADC ---
.equ LRADC_CTRL,                    0x00            // LRADC Control Register
.equ LRADC_INTC,                    0x04            // LRADC Interrupt Control Register
.equ LRADC_INTS,                    0x08            // LRADC Interrupt Status Register
.equ LRADC_DATA0,                   0x0c            // LRADC Data Register 0
.equ LRADC_DATA1,                   0x10            // LRADC Data Register 1


// --- ASYNC_Timer ---
.equ ASYNC_TMR_IRQ_EN_REG,          0x0000          // Timer IRQ Enable
.equ ASYNC_TMR_IRQ_STAS_REG,        0x0004          // Timer Status
.equ ASYNC_TMR0_CTRL_REG,           0x0010          // Timer 0 Control
.equ ASYNC_TMR0_INTV_VALUE_REG,     0x0014          // Timer 0 Interval Value
.equ ASYNC_TMR0_CURNT_VALUE_REG,    0x0018          // Timer 0 Current Value
.equ ASYNC_TMR1_CTRL_REG,           0x0020          // Timer 1 Control
.equ ASYNC_TMR1_INTV_VALUE_REG,     0x0024          // Timer 1 Interval Value
.equ ASYNC_TMR1_CURNT_VALUE_REG,    0x0028          // Timer 1 Current Value
.equ ASYNC_TMR2_CTRL_REG,           0x0030          // Timer 2 Control
.equ ASYNC_TMR2_INTV_VALUE_REG,     0x0034          // Timer 2 Interval Value
.equ ASYNC_TMR2_CURNT_VALUE_REG,    0x0038          // Timer 2 Current Value
.equ ASYNC_TMR3_CTRL_REG,           0x0040          // Timer 3 Control
.equ ASYNC_TMR3_INTV_VALUE_REG,     0x0044          // Timer 3 Interval Value
.equ ASYNC_TMR4_CTRL_REG,           0x0050          // Timer 4 Control
.equ ASYNC_TMR4_INTV_VALUE_REG,     0x0054          // Timer 4 Interval Value
.equ ASYNC_TMR4_CURNT_VALUE_REG,    0x0058          // Timer 4 Current Value
.equ ASYNC_TMR5_CTRL_REG,           0x0060          // Timer 5 Control
.equ ASYNC_TMR5_INTV_VALUE_REG,     0x0064          // Timer 5 Interval Value
.equ ASYNC_TMR5_CURNT_VALUE_REG,    0x0068          // Timer 5 Current Value
.equ AVS_CNT_CTL_REG,               0x0080          // AVS Control Registe
.equ AVS_CNT0_REG,                  0x0084          // AVS Counter 0 Register
.equ AVS_CNT1_REG,                  0x0088          // AVS Counter 1 Register
.equ AVS_CNT_DIVISOR_REG,           0x008C          // AVS Divisor
.equ WDOG_CTRL_REG,                 0x0090          // Watchdog Control
.equ WDOG_MODE_REG,                 0x0094          // Watchdog Mode
.equ COUNTER64_CTRL_REG,            0x00A0          // 64-bit Counter control
.equ COUNTER64_LOW_REG,             0x00A4          // 64-bit Counter low
.equ COUNTER64_HI_REG,              0x00A8          // 64-bit Counter high

// --- TWI Registers Offsets ---
.equ TWI_ADDR,                      0x0000
.equ TWI_XADDR,                     0x0004
.equ TWI_DATA,                      0x0008
.equ TWI_CNTR,                      0x000C
.equ TWI_STAT,                      0x0010
.equ TWI_CCR,                       0x0014
.equ TWI_SRST,                      0x0018
.equ TWI_EFR,                       0x001C
.equ TWI_LCR,                       0x0020

// --- CCM Register Offsets for OSCM ---
.equ PLL1_CFG_REG,                  0x0000          // PLL1 Control
.equ PLL1_TUN_REG,                  0x0004          // PLL1 Tuning
.equ PLL2_CFG_REG,                  0x0008          // PLL2 Control
.equ PLL2_TUN_REG,                  0x000C          // PLL2 Tuning
.equ PLL3_CFG_REG,                  0x0010          // PLL3 Control
//.equ PLLxx_CFG_REG,               0x0014          // Missing Register place (we need a proper manual)
.equ PLL4_CFG_REG,                  0x0018          // PLL4 Control
//.equ PLLxx_CFG_REG,               0x001C          // Missing Register place (we need a proper manual)
.equ PLL5_CFG_REG,                  0x0020          // PLL5 Control
.equ PLL5_TUN_REG,                  0x0024          // PLL5 Tuning
.equ PLL6_CFG_REG,                  0x0028          // PLL6 Control
//.equ PLLxx_CFG_REG,               0x002C          // Missing Register place (we need a proper manual)
.equ PLL7_CFG_REG,                  0x0030          // PLL7 Control
//.equ PLLxx_CFG_REG,               0x0034          // Missing Register place (we need a proper manual)
.equ PLL1_TUN2_REG,                 0x0038          // PLL1 Tuning2
.equ PLL5_TUN2_REG,                 0x003C          // PLL5 Tuning2
.equ OSC24M_CFG_REG,                0x0050          // OSC24M control
.equ CPU_AHB_APB0_CFG_REG,          0x0054          // CPU, AHB And APB0 Divide Ratio
.equ APB1_CLK_DIV_REG,              0x0058          // APB1 Clock Divider
.equ AXI_GATING_REG,                0x005C          // AXI Module Clock Gating
.equ AHB_GATING_REG0,               0x0060          // AHB Module Clock Gating 0
.equ AHB_GATING_REG1,               0x0064          // AHB Module Clock Gating 1
.equ APB0_GATING_REG,               0x0068          // APB0 Module Clock Gating
.equ APB1_GATING_REG,               0x006C          // APB1 Module Clock Gating
.equ NAND_SCLK_CFG_REG,             0x0080          // Nand Flash Clock
//.equ NAND_SCLK_CFG_REG,           0x0084          // Missing Register place (we need a proper manual)
.equ SD0_SCLK_CFG_REG,              0x0088          // SD0 Clock
.equ SD1_SCLK_CFG_REG,              0x008C          // SD1 Clock
.equ SD2_SCLK_CFG_REG,              0x0090          // SD2 Clock
//.equ SD2_SCLK_CFG_REG,            0x0094          // Missing Register place (we need a proper manual)
//.equ SD2_SCLK_CFG_REG,            0x0098          // Missing Register place (we need a proper manual)
.equ CE_SCLK_CFG_REG,               0x009C          // Crypto Engine Clock
.equ SPI0_SCLK_CFG_REG,             0x00A0          // SPI0 Clock
.equ SPI1_SCLK_CFG_REG,             0x00A4          // SPI1 Clock
.equ SPI2_SCLK_CFG_REG,             0x00A8          // SPI2 Clock
//.equ SD2_SCLK_CFG_REG,            0x00AC          // Missing Register place (we need a proper manual)
.equ IR_SCLK_CFG_REG,               0x00B0          // IR Clock
.equ DRAM_SCLK_CFG_REG,             0x0100          // DRAM Clock
.equ BE_CFG_REG,                    0x0104          // Display Engine Backend Clock
.equ FE_CFG_REG,                    0x010C          // Display Engine Front End Clock
.equ LCD_CH0_CFG_REG,               0x0118          // LCD Channel0 Clock Found At U-BOOT Sunxi C Source Code **** was missing from TRM
.equ LCD_CH1_CFG_REG,               0x012C          // LCD Channel1 Clock
.equ CSI_CFG_REG,                   0x0134          // CSI Clock
.equ VE_CFG_REG,                    0x013C          // Video Engine Clock
.equ AUDIO_CODEC_SCLK_CFG_REG,      0x0140          // Audio Codec Gating Special Clock
.equ AVS_SCLK_CFG_REG,              0x0144          // AVS Gating Special Clock
.equ MALI_CLOCK_CFG_REG,            0x0154          // Mali400 Gating Special Clock
.equ MBUS_SCLK_CFG_REG,             0x015C          // MBUS Gating Clock
.equ IEP_SCLK_CFG_REG,              0x0160          // IEP Gating Clock

// --- TCON Registers Offsets
.equ TCON_GCTL_REG,                 0x0000          //TCON Global Control Register
.equ TCON_GINT0_REG,                0x0004          //TCON Global Interrupt Register0
.equ TCON_GINT1_REG,                0x0008          //TCON Global Interrupt Register1
.equ TCON0_FRM_CTL_REG,             0x0010          //TCON FRM Control Register
.equ TCON0_FRM_PIXEL_SEED0_REG,     0x0014          //TCON FRM Pixel Seed Register0
.equ TCON0_FRM_PIXEL_SEED1_REG,     0x0018          //TCON FRM Pixel Seed Register1
.equ TCON0_FRM_PIXEL_SEED2_REG,     0x001C          //TCON FRM Pixel Seed Register2
.equ TCON0_FRM_LINE_SEED0_REG,      0x0020          //TCON FRM Line Seed Register0
.equ TCON0_FRM_LINE_SEED1_REG,      0x0024          //TCON FRM Line Seed Register1
.equ TCON0_FRM_LINE_SEED2_REG,      0x0028          //TCON FRM Line Seed Register2
.equ TCON0_FRM_TAB0_REG,            0x002C          //TCON FRM Table Register0
.equ TCON0_FRM_TAB1_REG,            0x0030          //TCON FRM Table Register1
.equ TCON0_FRM_TAB2_REG,            0x0034          //TCON FRM Table Register2
.equ TCON0_FRM_TAB3_REG,            0x0038          //TCON FRM Table Register3
.equ TCON0_CTL_REG,                 0x0040          //TCON0 Control Register (TCON0 Enable)
.equ TCON0_DCLK_REG,                0x0044          //TCON0 Data Clock Register
.equ TCON0_BASIC0_REG,              0x0048          //TCON0 Basic Timing Register0 Panel Size (X, Y)
.equ TCON0_BASIC1_REG,              0x004C          //TCON0 Basic Timing Register1 Total Horizontal Period (HT)
.equ TCON0_BASIC2_REG,              0x0050          //TCON0 Basic Timing Register2 Total Vertical Period (lcd_vt) and lcd_vbp
.equ TCON0_BASIC3_REG,              0x0054          //TCON0 Basic Timing Register3 HSYNC and VSYNC Pulse Widths
.equ TCON0_HV_IF_REG,               0x0058          //TCON0 Hv Panel Interface Register (RGB data format)
.equ TCON0_CPU_IF_REG,              0x0060          //TCON0 CPU Panel Interface Register
.equ TCON0_CPU_WR_REG,              0x0064          //TCON0 CPU Panel Write Data Register
.equ TCON0_CPU_RD0_REG,             0x0068          //TCON0 CPU Panel Read Data Register0
.equ TCON0_CPU_RD1_REG,             0x006C          //TCON0 CPU Panel Read Data Register1
.equ TCON0_IO_POL_REG,              0x0088          //TCON0 IO Polarity Register (DE/DCLK Polarity)
.equ TCON0_IO_TRI_REG,              0x008C          //TCON0 IO Control Register
.equ TCON1_CTL_REG,                 0x0090          //TCON1 Control Register
.equ TCON1_BASIC0_REG,              0x0094          //TCON1 Basic Timing Register0
.equ TCON1_BASIC1_REG,              0x0098          //TCON1 Basic Timing Register1
.equ TCON1_BASIC2_REG,              0x009C          //TCON1 Basic Timing Register2
.equ TCON1_BASIC3_REG,              0x00A0          //TCON1 Basic Timing Register3
.equ TCON1_BASIC4_REG,              0x00A4          //TCON1 Basic Timing Register4
.equ TCON1_BASIC5_REG,              0x00A8          //TCON1 Basic Timing Register5
.equ TCON1_IO_POL_REG,              0x00F0          //TCON1 IO Polarity Register
.equ TCON1_IO_TRI_REG,              0x00F4          //TCON1 IO Control Register
.equ TCON_CEU_CTL_REG,              0x0100          //TCON CEU Control Register
.equ TCON_CEU_COEF0_REG,            0x0110          //TCON CEU Coefficient Register0
.equ TCON_CEU_COEF1_REG,            0x0114          //TCON CEU Coefficient Register1
.equ TCON_CEU_COEF2_REG,            0x0118          //TCON CEU Coefficient Register2
.equ TCON_CEU_COEF3_REG,            0x011C          //TCON CEU Coefficient Register3
.equ TCON_CEU_COEF4_REG,            0x0120          //TCON CEU Coefficient Register4
.equ TCON_CEU_COEF5_REG,            0x0124          //TCON CEU Coefficient Register5
.equ TCON_CEU_COEF6_REG,            0x0128          //TCON CEU Coefficient Register6
.equ TCON_CEU_COEF7_REG,            0x012C          //TCON CEU Coefficient Register7
.equ TCON_CEU_COEF8_REG,            0x0130          //TCON CEU Coefficient Register8
.equ TCON_CEU_COEF9_REG,            0x0134          //TCON CEU Coefficient Register9
.equ TCON_CEU_COEF10_REG,           0x0138          //TCON CEU Coefficient Register10
.equ TCON_CEU_COEF11_REG,           0x013C          //TCON CEU Coefficient Register11
.equ TCON_CEU_COEF12_REG,           0x0140          //TCON CEU Coefficient Register12
.equ TCON_CEU_COEF13_REG,           0x0144          //TCON CEU Coefficient Register13
.equ TCON_CEU_COEF14_REG,           0x0148          //TCON CEU Coefficient Register14
.equ TCON1_FILL_CTL_REG,            0x0300          //TCON1 Fill Data Control Register
.equ TCON1_FILL_BEGIN0_REG,         0x0304          //TCON1 Fill Data Begin Register0
.equ TCON1_FILL_END0_REG,           0x0308          //TCON1 Fill Data End Register0
.equ TCON1_FILL_DATA0_REG,          0x030C          //TCON1 Fill Data Value Register0
.equ TCON1_FILL_BEGIN1_REG,         0x0310          //TCON1 Fill Data Begin Register1
.equ TCON1_FILL_END1_REG,           0x0314          //TCON1 Fill Data End Register1
.equ TCON1_FILL_DATA1_REG,          0x0318          //TCON1 Fill Data Value Register1
.equ TCON1_FILL_BEGIN2_REG,         0x031C          //TCON1 Fill Data Begin Register2
.equ TCON1_FILL_END2_REG,           0x0320          //TCON1 Fill Data End Register2
.equ TCON1_FILL_DATA2_REG,          0x0324          //TCON1 Fill Data Value Register2
.equ TCON1_GAMMA_TABLE_REG,         0x400           //0x400-0x7FF TCON1 Gama Table Register

// --- DE BE Registers Offsets
.equ DEBE_MODCTL_REG,               0x800           //DEBE mode control register
.equ DEBE_BACKCOLOR_REG,            0x804           //DE-back color control register
.equ DEBE_DISSIZE_REG,              0x808           //DE-back display size setting register
.equ DEBE_LAYSIZE_REG0,             0x810           //layer0 DE-layer size register
.equ DEBE_LAYSIZE_REG1,             0x814           //layer1 DE-layer size register
.equ DEBE_LAYSIZE_REG2,             0x818           //layer2 DE-layer size register
.equ DEBE_LAYSIZE_REG3,             0x81C           //layer3 DE-layer size register
.equ DEBE_LAYCOOR_REG0,             0x820           //layer0 DE-layer coordinate control register
.equ DEBE_LAYCOOR_REG1,             0x824           //layer1 DE-layer coordinate control register
.equ DEBE_LAYCOOR_REG2,             0x828           //layer2 DE-layer coordinate control register
.equ DEBE_LAYCOOR_REG3,             0x82C           //layer3 DE-layer coordinate control register
.equ DEBE_LAYLINEWIDTH_REG0,        0x840           //layer0 DE-layer frame buffer line width register
.equ DEBE_LAYLINEWIDTH_REG1,        0x844           //layer1 DE-layer frame buffer line width register
.equ DEBE_LAYLINEWIDTH_REG2,        0x848           //layer2 DE-layer frame buffer line width register
.equ DEBE_LAYLINEWIDTH_REG3,        0x84C           //layer3 DE-layer frame buffer line width register
.equ DEBE_LAYFB_L32ADD_REG0,        0x850           //layer0 layer frame buffer low 32bit address reg.
.equ DEBE_LAYFB_L32ADD_REG1,        0x854           //layer1 layer frame buffer low 32bit address reg.
.equ DEBE_LAYFB_L32ADD_REG2,        0x858           //layer2 layer frame buffer low 32bit address reg.
.equ DEBE_LAYFB_L32ADD_REG3,        0x85C           //layer3 layer frame buffer low 32bit address reg.
.equ DEBE_LAYFB_H4ADD_REG,          0x860           //DE-layer frame buffer high 4 bit address register
.equ DEBE_REGBUFFCTL_REG,           0x870           //DE-Register buffer control register
.equ DEBE_CKMAX_REG,                0x880           //DE-color key MAX register
.equ DEBE_CKMIN_REG,                0x884           //DE-color key MIN register
.equ DEBE_CKCFG_REG,                0x888           //DE-color key configuration register
.equ DEBE_ATTCTL0_REG0,             0x890           //layer0 DE-layer attribute control register0
.equ DEBE_ATTCTL1_REG0,             0x894           //layer1 DE-layer attribute control register0
.equ DEBE_ATTCTL2_REG0,             0x898           //layer2 DE-layer attribute control register0
.equ DEBE_ATTCTL3_REG0,             0x89C           //layer3 DE-layer attribute control register0
.equ DEBE_ATTCTL0_REG1,             0x8A0           //layer0 DE-layer attribute control register1
.equ DEBE_ATTCTL1_REG1,             0x8A4           //layer1 DE-layer attribute control register1
.equ DEBE_ATTCTL2_REG1,             0x8A8           //layer2 DE-layer attribute control register1
.equ DEBE_ATTCTL3_REG1,             0x8AC           //layer3 DE-layer attribute control register1
.equ DEBE_HWCCTL_REG,               0x8D8           //DE-HWC coordinate control register
.equ DEBE_HWCFBCTL_REG,             0x8E0           //DE-HWC frame buffer format register
.equ DEBE_WBCTL_REG,                0x8F0           //DEBE write back control register
.equ DEBE_WBADD_REG,                0x8F4           //DEBE write back address register
.equ DEBE_WBLINEWIDTH_REG,          0x8F8           //DEBE write back buffer line width register
.equ DEBE_IYUVCTL_REG,              0x920           //DEBE input YUV channel control register
.equ DEBE_IYUVADD0_REG,             0x930           //layer0 DEBE YUV channel frame buffer address reg
.equ DEBE_IYUVADD1_REG,             0x934           //layer1 DEBE YUV channel frame buffer address reg
.equ DEBE_IYUVADD2_REG,             0x938           //layer2 DEBE YUV channel frame buffer address reg
.equ DEBE_IYUVLINEWIDTH_REG0,       0x940           //layer0 DEBE YUV channel buffer line width reg.
.equ DEBE_IYUVLINEWIDTH_REG1,       0x944           //layer1 DEBE YUV channel buffer line width reg.
.equ DEBE_IYUVLINEWIDTH_REG2,       0x948           //layer2 DEBE YUV channel buffer line width reg.
.equ DEBE_YGCOEF_REG0,              0x950           //layer0 DEBE Y/G coefficient register
.equ DEBE_YGCOEF_REG1,              0x954           //layer1 DEBE Y/G coefficient register
.equ DEBE_YGCOEF_REG2,              0x958           //layer2 DEBE Y/G coefficient register
.equ DEBE_YGCONS_REG,               0x95C           //DEBE Y/G constant register
.equ DEBE_URCOEF_REG0,              0x960           //DEBE U/R coefficient register0
.equ DEBE_URCOEF_REG1,              0x964           //DEBE U/R coefficient register1
.equ DEBE_URCOEF_REG2,              0x968           //DEBE U/R coefficient register2
.equ DEBE_URCONS_REG,               0x96C           //DEBE U/R constant register
.equ DEBE_VBCOEF_REG0,              0x970           //DEBE V/B coefficient register0
.equ DEBE_VBCOEF_REG1,              0x974           //DEBE V/B coefficient register1
.equ DEBE_VBCOEF_REG2,              0x978           //DEBE V/B coefficient register2
.equ DEBE_VBCONS_REG,               0x97C           //DEBE V/B constant register
.equ DEBE_OCCTL_REG,                0x9C0           //DEBE output color control register
.equ DEBE_OCRCOEF_REG0,             0x9D0           //DEBE output color R coefficient register0
.equ DEBE_OCRCOEF_REG1,             0x9D4           //DEBE output color R coefficient register1
.equ DEBE_OCRCOEF_REG2,             0x9D8           //DEBE output color R coefficient register2
.equ DEBE_OCRCONS_REG,              0x9DC           //DEBE output color R constant register
.equ DEBE_OCGCOEF_REG0,             0x9E0           //DEBE output color G coefficient register0
.equ DEBE_OCGCOEF_REG1,             0x9E4           //DEBE output color G coefficient register1
.equ DEBE_OCGCOEF_REG2,             0x9E8           //DEBE output color G coefficient register2
.equ DEBE_OCGCONS_REG,              0x9EC           //DEBE output color G constant register
.equ DEBE_OCBCOEF_REG0,             0x9F0           //DEBE output color B coefficient register0
.equ DEBE_OCBCOEF_REG1,             0x9F4           //DEBE output color B coefficient register1
.equ DEBE_OCBCOEF_REG2,             0x9F8           //DEBE output color B coefficient register2
.equ DEBE_OCBCONS_REG,              0x9FC           //DEBE output color B constant register

// --- DE FE Registers Offsets
.equ DEFE_EN_REG,                   0x0000          //DEFE Module Enable Register
.equ DEFE_FRM_CTRL_REG,             0x0004          //DEFE Frame Process Control Register
.equ DEFE_BYPASS_REG,               0x0008          //DEFE CSC By-Pass Register
.equ DEFE_AGTH_SEL_REG,             0x000C          //DEFE Algorithm Selection Register
.equ DEFE_LINT_CTRL_REG,            0x0010          //DEFE Line Interrupt Control Register
.equ DEFE_BUF_ADDR0_REG,            0x0020          //DEFE Input Channel 0 Buffer Address Register
.equ DEFE_BUF_ADDR1_REG,            0x0024          //DEFE Input Channel 1 Buffer Address Register
.equ DEFE_BUF_ADDR1_REG,            0x0028          //DEFE Input Channel 2 Buffer Address Register
.equ DEFE_FIELD_CTRL_REG,           0x002C          //DEFE Field Sequence Register
.equ DEFE_TB_OFF0_REG,              0x0030          //DEFE Channel 0 Tile-Based Offset Register
.equ DEFE_TB_OFF1_REG,              0x0034          //DEFE Channel 1 Tile-Based Offset Register
.equ DEFE_TB_OFF2_REG,              0x0038          //DEFE Channel 2 Tile-Based Offset Register
.equ DEFE_LINESTRD0_REG,            0x0040          //DEFE Channel 0 Line Stride Register
.equ DEFE_LINESTRD1_REG,            0x0044          //DEFE Channel 1 Line Stride Register
.equ DEFE_LINESTRD2_REG,            0x0048          //DEFE Channel 2 Line Stride Register
.equ DEFE_INPUT_FMT_REG,            0x004C          //DEFE Input Format Register
.equ DEFE_WB_ADDR0_REG,             0x0050          //DEFE Channel 3 Write Back Address Register
.equ DEFE_OUTPUT_FMT_REG,           0x005C          //DEFE Output Format Register
.equ DEFE_INT_EN_REG,               0x0060          //DEFE Interrupt Enable Register
.equ DEFE_INT_STATUS_REG,           0x0064          //DEFE Interrupt Status Register
.equ DEFE_STATUS_REG,               0x0068          //DEFE Status Register
.equ DEFE_CSC_COEF00_REG,           0x0070          //DEFE CSC Coefficient 00 Register
.equ DEFE_CSC_COEF01_REG,           0x0074          //DEFE CSC Coefficient 01 Register
.equ DEFE_CSC_COEF02_REG,           0x0078          //DEFE CSC Coefficient 02 Register
.equ DEFE_CSC_COEF03_REG,           0x007C          //DEFE CSC Coefficient 03 Register
.equ DEFE_CSC_COEF10_REG,           0x0080          //DEFE CSC Coefficient 10 Register
.equ DEFE_CSC_COEF11_REG,           0x0084          //DEFE CSC Coefficient 11 Register
.equ DEFE_CSC_COEF12_REG,           0x0088          //DEFE CSC Coefficient 12 Register
.equ DEFE_CSC_COEF13_REG,           0x008C          //DEFE CSC Coefficient 13 Register
.equ DEFE_CSC_COEF20_REG,           0x0090          //DEFE CSC Coefficient 20 Register
.equ DEFE_CSC_COEF21_REG,           0x0094          //DEFE CSC Coefficient 21 Register
.equ DEFE_CSC_COEF22_REG,           0x0098          //DEFE CSC Coefficient 22 Register
.equ DEFE_CSC_COEF23_REG,           0x009C          //DEFE CSC Coefficient 23 Register
.equ DEFE_WB_LINESTRD_EN_REG,       0x00D0          //DEFE Write Back Line Stride Enable Register
.equ DEFE_WB_LINESTRD0_REG,         0x00D4          //DEFE Write Back Channel 3 Line Stride Register
.equ DEFE_CH0_INSIZE_REG,           0x0100          //DEFE Channel 0 Input Size Register
.equ DEFE_CH0_OUTSIZE_REG,          0x0104          //DEFE Channel 0 Output Size Register
.equ DEFE_CH0_HORZFACT_REG,         0x0108          //DEFE Channel 0 Horizontal Factor Register
.equ DEFE_CH0_VERTFACT_REG,         0x010C          //DEFE Channel 0 Vertical factor Register
.equ DEFE_CH0_HORZPHASE_REG,        0x0110          //DEFE Channel 0 Horizontal Initial Phase Register
.equ DEFE_CH0_VERTPHASE0_REG,       0x0114          //DEFE Channel 0 Vertical Initial Phase 0 Register
.equ DEFE_CH0_VERTPHASE1_REG,       0x0118          //DEFE Channel 0 Vertical Initial Phase 1 Register
.equ DEFE_CH1_INSIZE_REG,           0x0200          //DEFE Channel 1 Input Size Register
.equ DEFE_CH1_OUTSIZE_REG,          0x0204          //DEFE Channel 1 Output Size Register
.equ DEFE_CH1_HORZFACT_REG,         0x0208          //DEFE Channel 1 Horizontal Factor Register
.equ DEFE_CH1_VERTFACT_REG,         0x020C          //DEFE Channel 1 Vertical factor Register
.equ DEFE_CH1_HORZPHASE_REG,        0x0210          //DEFE Channel 1 Horizontal Initial Phase Register
.equ DEFE_CH1_VERTPHASE0_REG,       0x0214          //DEFE Channel 1 Vertical Initial Phase 0 Register
.equ DEFE_CH1_VERTPHASE1_REG,       0x0218          //DEFE Channel 1 Vertical Initial Phase 1 Register
.equ DEFE_CH0_HORZCOEF_REGN,        0x0400          //0x0400+N*4 DEFE Channel 0 Horizontal Filter Coefficient Reg. N=0:31
.equ DEFE_CH0_HORZCOEF_REGN1,       0x0480          //0x0480+N*4 DEFE Channel 0 Horizontal Filter Coefficient Reg1. N=0:31
.equ DEFE_CH0_VERTCOEF_REGN,        0x0500          //0x0500+N*4 DEFE Channel 0 Vertical Filter Coefficient Reg. N=0:31
.equ DEFE_CH1_HORZCOEF_REGN,        0x0600          //0x0600+N*4 DEFE Channel 1 Horizontal Filter Coefficient Reg. N=0:31
.equ DEFE_CH1_HORZCOEF_REGN1,       0x0680          //0x0680+N*4 DEFE Channel 1 Horizontal Filter Coefficient Reg1. N=0:31
.equ DEFE_CH1_VERTCOEF_REGN,        0x0700          //0x0700+N*4 DEFE Channel 1 Vertical Filter Coefficient Reg. N=0:31
//

// --- PIO Register Offsets ---
// ---- PB ----
.equ PIO_PB_CFG0,                  0x24             // PB0-PB4 configuration
.equ PIO_PB_CFG1,                  0x28             // PB10 & PB15 configuration
.equ PIO_PB_CFG2,                  0x2C             // PB16-PB18 configuration
.equ PIO_PB_CFG3,                  0x30             // Reserved
.equ PIO_PB_DAT,                   0x34             // PB Data register, for M0(input) & M1(output)
.equ PIO_PB_DRV0,                  0x38             // PB0-PB15 Multi-Driving Select
.equ PIO_PB_DRV1,                  0x3C             // PB16-PB20 Multi-Driving Select
.equ PIO_PB_PULL0,                 0x40             // PB0-PB15 Pull-up/down Select
.equ PIO_PB_PULL1,                 0x44             // PB16-PB20 Pull-up/down Select
// ---- PC ----
.equ PIO_PC_CFG0,                  0x48             // PC0-PC7 configuration
.equ PIO_PC_CFG1,                  0x4C             // PC8-PC15 configuration
.equ PIO_PC_CFG2,                  0x50             // PC19 configuration
.equ PIO_PC_CFG3,                  0x54             // Reserved
.equ PIO_PC_DAT,                   0x58             // PC Data register, for M0(input) & M1(output)
.equ PIO_PC_DRV0,                  0x5C             // PC0-PC15 Multi-Driving Select
.equ PIO_PC_DRV1,                  0x60             // PC16-PC19 Multi-Driving Select
.equ PIO_PC_PULL0,                 0x64             // PC0-PC15 Pull-up/down Select
.equ PIO_PC_PULL1,                 0x68             // PC16-PC19 Pull-up/down Select
// ---- PD ----
.equ PIO_PD_CFG0,                  0x6C             // PD2-PD7 configuration
.equ PIO_PD_CFG1,                  0x70             // PD10-PD15 configuration
.equ PIO_PD_CFG2,                  0x74             // PD18-PD23 configuration
.equ PIO_PD_CFG3,                  0x78             // PD24-PD27 configuration
.equ PIO_PD_DAT,                   0x7C             // PD Data register, for M0(input) & M1(output)
.equ PIO_PD_DRV0,                  0x80             // PD0-PD15 Multi-Driving Select
.equ PIO_PD_DRV1,                  0x84             // PD16-PD27 Multi-Driving Select
.equ PIO_PD_PULL0,                 0x88             // PD0-PD15 Pull-up/down Select
.equ PIO_PD_PULL1,                 0x8C             // PD16-PD27 Pull-up/down Select
// ---- PE ----
.equ PIO_PE_CFG0,                  0x90             // PE0-PE7 configuration
.equ PIO_PE_CFG1,                  0x94             // PE8-PE11 configuration
.equ PIO_PE_CFG2,                  0x98             // Reserved
.equ PIO_PE_CFG3,                  0x9C             // Reserved
.equ PIO_PE_DAT,                   0xA0             // PE Data register, for M0(input) & M1(output)
.equ PIO_PE_DRV0,                  0xA4             // PE0-PE11 Multi-Driving Select
.equ PIO_PE_DRV1,                  0xA8             // Reserved
.equ PIO_PE_PULL0,                 0xAC             // PE0-PE11 Pull-up/down Select
.equ PIO_PE_PULL1,                 0xB0             // Reserved
// ---- PF ----
.equ PIO_PF_CFG0,                  0xB4             // PF0-PF5 configuration
.equ PIO_PF_CFG1,                  0xB8             // Reserved
.equ PIO_PF_CFG2,                  0xBC             // Reserved
.equ PIO_PF_CFG3,                  0xC0             // Reserved
.equ PIO_PF_DAT,                   0xC4             // PF Data register, for M0(input) & M1(output)
.equ PIO_PF_DRV0,                  0xC8             // PF0-PF5 Multi-Driving Select
.equ PIO_PF_DRV1,                  0xCC             // Reserved
.equ PIO_PF_PULL0,                 0xD0             // PF0-PF5 Pull-up/down Select
.equ PIO_PF_PULL1,                 0xD4             // Reserved
// ---- PG ----
.equ PIO_PG_CFG0,                  0xD8             // PG0-PG4 configuration
.equ PIO_PG_CFG1,                  0xDC             // PG9-PG12 configuration
.equ PIO_PG_CFG2,                  0xE0             // Reserved
.equ PIO_PG_CFG3,                  0xE4             // Reserved
.equ PIO_PG_DAT,                   0xE8             // PG Data register, for M0(input) & M1(output)
.equ PIO_PG_DRV0,                  0xEC             // PG0-PG13 Multi-Driving Select
.equ PIO_PG_DRV1,                  0xF0             // Reserved
.equ PIO_PG_PULL0,                 0xF4             // PG0-PG13 Pull-up/down Select
.equ PIO_PG_PULL1,                 0xF8             // Reserved
// ---- Int Config ----
.equ PIO_INT_CFG0,                 0x200             // Int0-Int7 configuration
.equ PIO_INT_CFG1,                 0x204             // Int8-Int15 configuration
.equ PIO_INT_CFG2,                 0x208             // Int16-Int23 configuration
.equ PIO_INT_CFG3,                 0x20C             // Int24-Int31 configuration
.equ PIO_INT_CTL,                  0x210             // Int0-Int31 0: disable 1: enable
.equ PIO_INT_STATUS,               0x214             // Int0-Int31 0: No IRQ Pending 1: IRQ Pending
.equ PIO_INT_DEB,                  0x218             // Interrupt Debounce


// --- PWM Register Offsets ---
.equ PWM_CTRL,                      0x0200          // PWM Control Register 0x0200 9.2 page 83
.equ PWM_CH0_PERIOD_ACTIVE_REG,     0x0204          // PWM Channel 0 Period Register 0x0204 9.2 page 83

// --- i2c bit banging Clock Speed ---
.equ i2C_DELAY,                     750             //(0x2EE) this 750 for 100khz slowest for AXP209
                                                    // SPµs = [1,000,000 / (desired speed_hz * 4)]
                                                    // we multply by 4 cause 4 bytes require after the loop
                                                    // 32 bit operand (cmp rx, #nnn)
                                                    //  1.2 GHz CPU= (1,200 cycles/µs)
                                                    // and 4 cycles per loop iteration.
                                                    // i2C_DELAY = [(SPµs * 1,200) / 4]
                                                    // for 100khz = 100,000 SPµs = [1,000,000/ (100,000 * 4)] = 2.5µs
                                                    // i2C_DELAY = (2.5µs * 1,200) / 4 = 750
                                                    // for 400khz i2C_DELAY would be 184
                                                   
.equ ONE_SEC_DELAY,                  3500000        // for 1hz SPµs = [1,000,000/ (1 * 4)] = 250,000µs
                                                    // ONE_SEC_DELAY = (250,000µs * 1,200) / 100 = 3,000,000
                                                    // but this is not so precice so with trial and error i reached to
                                                    // 3,500,000

// --- LCD Specs For Tablet IT-708 VESA 800x480 32bit 60hz
.equ lcd_x,                         800             // *** from script.fex *** Active Pixels Aka Width 800
.equ lcd_hv_hspw,                   48              // *** from script.fex *** Horizontal Sync Width 48
.equ lcd_hbp,                       215             // *** from script.fex *** Horizontal Back Porch 215, see below to calculate HFP
.equ lcd_ht,                        1055            // *** from script.fex *** Total Horizontal Px. (lcd_x+HFP+lcd_hv_hspw+lcd_hbp) 1055
.equ lcd_hfp,                       -8              // WRONG (MINUS) calculated hfp = lcd_ht - lcd_x - lcd_hv_hspw - lcd_hbp
.equ lcd_y,                         480             // *** from script.fex ***  Active Lines Aka Height 480
.equ lcd_hv_vspw,                   3               // *** from script.fex *** Vertical Sync Width 3
.equ lcd_vbp,                       34              // *** from script.fex *** Vertical Back Porch 34, see below to calculate VFP
.equ lcd_vt,                        1050            // *** from script.fex *** Total Vertical Pixles (lcd_y+VFP+lcd_hv_vspw+lcd_vbp) 1050
.equ lcd_vfp,                       533             // calculated (not from specs) vfp = lcd_vt - lcd_y - lcd_hv_vspw - lcd_vbp
.equ lcd_dclk_freq,                 33              // *** from script.fex *** TCON0 Data Clock Speed 33Mhz
.equ lcd_pwm_ch,                    0               // *** from script.fex *** PWM Channel 0
.equ lcd_pwm_freq,                  10000           // *** from script.fex *** Backlight PWM Frequency
.equ lcd_pwm_pol,                   1               // *** from script.fex *** PWM Polarity inveterd
.equ lcd_if,                        0               // *** from script.fex *** 32/24 bit parallel RGB interface RGB888
.equ lcd_hv_if,                     0               // HV is controlled by DE BE
.equ lcd_hv_smode,                  0               // 0: Parallel 1: Serial
.equ lcd_hv_s888_if,                0               // Serial is s888 if enabled
.equ lcd_hv_syuv_if,                0               // Serial is YUV if Enabled
.equ lcd_lvds_ch,                   0               // Low-Voltage Differential Signaling CH0 (twisted pair serial lcd)
.equ lcd_lvds_mode,                 0               // Low-Voltage Differential Signaling Mode 0 Standard
.equ lcd_lvds_bitwidth,             0               // Low-Voltage Differential Signaling Bitwidth Standard
.equ lcd_lvds_io_cross,             0               // Low-Voltage Differential Signaling io cross default
.equ lcd_cpu_if,                    0               // Internal RGB888
.equ lcd_frm_18,                    0x80000000      // frame rate control mode is 18 bit RGB666 dithered to 24 bit RGB888
                                                    // from sunxi #define SUNXI_LCDC_TCON0_FRM_CTRL_RGB666 ((1 << 31) | (0 << 4))
.equ lcd_frm_16,                    0x80000050      // frame rate control mode is 16 bit RGB565 dithered to 24 bit RGB888
                                                    // from sunxi #define SUNXI_LCDC_TCON0_FRM_CTRL_RGB565 ((1 << 31) | (5 << 4))
.equ lcd_frm_seed,                  0x11111111      // 25 bits width for pixel seed and 13 bits for line seed
                                                    // dithering requires non zero, random-ish values
                                                    // from sunxi source #define SUNXI_LCDC_TCON0_FRM_SEED        0x11111111
.equ lcd_frm_tab0,                  0x01010000      // 13 bits width dithering requires non zero, random-ish values
.equ lcd_frm_tab1,                  0x15151111      // 13 bits width dithering requires non zero, random-ish values
.equ lcd_frm_tab2,                  0x57575555      // 13 bits width dithering requires non zero, random-ish values
.equ lcd_frm_tab3,                  0x7f7f7777      // 13 bits width dithering requires non zero, random-ish values
                                                    // from sunxi source #define SUNXI_LCDC_TCON0_FRM_TAB0        0x01010000
                                                    // from sunxi source #define SUNXI_LCDC_TCON0_FRM_TAB1        0x15151111
                                                    // from sunxi source #define SUNXI_LCDC_TCON0_FRM_TAB2        0x57575555
                                                    // from sunxi source #define SUNXI_LCDC_TCON0_FRM_TAB3        0x7f7f7777
.equ lcd_io_cfg0,                   0               // 0: RGB 1: BGR
.equ lcd_gamma_correction_en,       0               // Gamma Correction 0:disable 1:enable
.equ lcd_gamma_tbl_0,               0x0             // Gamma Table 0
.equ lcd_gamma_tbl_1,               0x10101         // Gamma Table 1
.equ lcd_gamma_tbl_255,             0xffffff        // Gamma Table 255
.equ lcd_bl_en_used,                1               // Backlight Available
.equ lcd_bl_en,                     1               // port:power1<1><0><default><1> Backlight 0:diable 1:enable
.equ lcd_power_used,                1               // LCD Power Available
.equ lcd_power,                     1               // port:power0<1><0><default><1> LCD Power 0:diable 1:enable
.equ lcd_pwm_used,                  1               // LCD PWM for Backlight Available
.equ lcd_pwm,                       2               // port:PB02<2><0><default><default> LCD PWM for Backlight use port 2


// Equates for the framebuffer
.equ FB_BPP,                    4                   // 4 bytes per pixel (RGBA8888)
.equ FB_SIZE,                   (lcd_x * lcd_y * FB_BPP)

.equ FRAMEBUFFER_ADDRESS,       0x48000000
.equ FRAMEBUFFER_BASE,          FRAMEBUFFER_ADDRESS
.equ COLOR_BACKGROUND,          0xFF000000   //Black

@ >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@
@ <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< LCD Driver Section >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@
@ <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
// ========================================================================
// 0- LCD_DRIVER_LOAD
// initialize LCD and Turn On Backlight
// Gives a Functions to control
// 1- Backlight On/Off
// 2- Backlight Brightness 0 - 100 %
// 3- LED Flashe Slow/Fast On/Off Release
// 4- Provide a Fixed Memory (At 0x48000000) As GFX Framebuffer for 32 bit color 800 x 480 Screen
// 6- Init RTC Real Time Clock For Time And Date Functions
// ========================================================================
LCD_DRIVER_LOAD:
    push    {r0-r10, lr}

    bl      Power_Management_Engines_Init               // set the Backlight & LED PM Engine

    bl      Gating_AVS_OSC24M

    bl      Display_Engines_Init                        // Init DE BE, DE FE & TCON
        
    bl      Clean_And_Fill_Framebuffer

    bl      Display_Startup                                  // Configure LCD
    
    bl      Turn_On_Backlight
    
    bl      RTC_Init

    bl      LRADC_Init

    pop     {r0-r10, pc}
    .ltorg

//###############################################################################################################
//############################################# Main Calls ######################################################
//###############################################################################################################

// ========================================================================
// 1- Power_Management_Engines_Init
// initialize TWI0 For Power Management Chip AXP209
// ========================================================================
    Power_Management_Engines_Init:
    push    {r0-r5, lr}

    bl      TWI0_Init

    bl      LED_Slow_Flash

    pop     {r0-r5, pc}
    .ltorg

Gating_AVS_OSC24M:
    ldr     r0, =CCM_BASE
    ldr     r1, [r0,#AVS_SCLK_CFG_REG] // Get AVS_SCLK_CFG_REG
    orr     r1, r1, #0x80000000 // Set bit[31] SCLK_GATING
    str     r1, [r0,#AVS_SCLK_CFG_REG] // Store at AVS_SCL
        
    ldr     r0, =ASYNC_Timer_BASE
    mov     r1, #1  // Set bit[0] AVS_CNT0_EN A/V Sync Counter 1 source is OSC24M 0:Disable 1:Enable
    str     r1, [r0,#AVS_CNT_CTL_REG] // Store at AVS_CNT_CTL_REG
    movw    r1, #0x2EE0 // Set bits[0-11] AVS_CNT0_D to 0x2EE0 & Clear [16-27] AVS_CNT1_D
    str     r1, [r0,#AVS_CNT_DIVISOR_REG] // Store at AVS_CNT_DIVISOR_REG
    mov     r1, #0  // Clear bits[0-31] AVS_CNT0
    str     r1, [r0,#AVS_CNT0_REG] // Store at AVS_CNT0_REG
    bx      lr
    .ltorg      //put this right after the function that contains "invalid literal constant" error to solve it

// ========================================================================
// 2- Display_Engines_Init
// initialize DE BE, DE FE, TCON
// ========================================================================
Display_Engines_Init:
    push    {r0-r5, lr}

    bl      PLL_INIT                             //Sets PLL3 & PLL7 to 297mhz
    
    bl      DE_FE_Init

    bl      DE_BE_Init

    bl      TCON_INIT

    pop     {r0-r5, pc}
    .ltorg
    
// ========================================================================
// 3- Clean_And_Fill_Framebuffer
// initialize DE BE, DE FE, TCON
// ========================================================================
Clean_And_Fill_Framebuffer:
    push    {r0-r5, lr}

    
    bl      fill_framebuffer_black

    ldr     r0, =FRAMEBUFFER_BASE
    ldr     r1, =FB_SIZE
    
    bl      clean_DCACHE_by_va                          //video_set_flush_dcache(dev, true)//  // flush D_CACHE

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// 4- Display_Startup
// Configure LCD
// ========================================================================
Display_Startup:
    push    {r0-r5, lr}
    
    bl      LCD_Panel_Power_Enable                                  // turn off backlight, give power and send no reset to LCD Panel
            
    bl      BE_Mode_Set                                             // set mode of DEBE and DEFE
    
    bl      LCD_PIO_Set                                // set mode of TCON
            
    bl      LCD_Mode_Set
        
    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// 5- Turn_On_Backlight
// Turn The Backlight On and Release LED
// ========================================================================
Turn_On_Backlight:
    push    {r0-r5, lr}
    
    mov     r0, #1                                          // Give time for The display to Scan At Least twice On LCD
    bl      delay_ms

    bl      BCK_L_ON
    
    mov     r0, #5                                          // Brightness Control set 50%  0: 100% 10: 0%
                                                            // save backlight for those old machines its hard to replace
    bl      BCK_L_CTRL

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// 6- RTC_Init
// initialize TWI1 For RTC Chip AT8563S
// ========================================================================
RTC_Init:
    push    {r0-r5, lr}

    bl      TWI1_Init

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// 7- LRADC_Init
// initialize LRADC For Detecting Vol up / Vol Down keys
// ========================================================================
LRADC_Init:
    push    {r0-r5, lr}

    bl      LRADC_Enable

    bl      LED_Release

    pop     {r0-r5, pc}
    .ltorg

//###############################################################################################################
//########################################## Display Engines Init Functions #####################################
//###############################################################################################################

// =======================================================================
// PLL_INIT
// Sets PLL3 & PLL7 to 297Mhz
// =======================================================================
PLL_INIT:
    push {r0-r5, lr}
    
    bl      clock_set_pll3_297MHZ                                // set PLL3 Frequency to 297mHz by using multiplier = 99

.verify_PLL3_297MHZ:
    bl      clock_get_pll3                                       // get current frequency of PLL3 at r5
    
    ldr     r2, =297000000                                      // 297mhz (99 x 3mhz)
    cmp     r5, r2
    bne     .verify_PLL3_297MHZ                                // check if the setting has been saved in PLL as 198mhz
    
    mov     r0, #3
    bl      delay_ms
    
    bl      clock_set_pll7_297MHZ                                // set PLL3 Frequency to 297mHz by using multiplier = 99

.verify_PLL7_297MHZ:
    bl      clock_get_pll7                                       // get current frequency of PLL3 at r5
    
    ldr     r2, =297000000                                      // 297mhz (99 x 3mhz)
    cmp     r5, r2
    bne     .verify_PLL7_297MHZ                                // check if the setting has been saved in PLL as 198mhz
    
    mov     r0, #3
    bl      delay_ms

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// DE_FE_Init
// initialize DE FE
// ========================================================================
DE_FE_Init:
    push    {r0-r5, lr}

    // Set PLL7 Main Frequency to 297mhz (Integer Mode) (we use PLL7 As Per Code)
    
    //  Component   Clock Source        Source Frequency    Divider (M)                 Final Frequency
    //  ------------------------------------------------------------------------------------------------
    //  PLL7        3 MHz Internal      3 MHz               99 (M=99)                   297 MHz
    //  FE          PLL7                PLL7_Out            M = 0 M+1                   297 MHz

//  b) Init FE NC.                                                                          inCode Label: Scaler_Init
//      i> Init FE Clock                                                                    inCode Sub: scaler_clk_init
//          - FE_CFG_REG Clear bit[30] 1:Deassert                                inCode Label: h_defe0mclk
//          - FE_CFG_REG Set bits[24-25] 0b10:PLL7 Set FE to PLL7 (297mhz|99|0)            inCode Label: h_defe0mclk
//          - FE_CFG_REG Set bits[0-3] 0:CLK_DIV_RATIO_M make sure no devider            inCode Label: h_defe0mclk
//          - FE_AHB_GATING Set bit[14] 1:Pass                                              inCode Label: h_defe0ahbclk
//          - FE_CFG_REG Set bit[31] 1:Enable       ????                                    inCode Label: h_defe0mclk
//          - FE_CFG_REG Set bit[31] 0:Disable      ????                                    inCode Label: h_defe0mclk
//          - FE Dclk Gatting Set bit[25] 1:Pass    ????                                    inCode Label: h_defe0dramclk
//          - FE Dclk Gatting Set bit[25] 0:Mask    ????                                    inCode Label: h_defe0dramclk
    mov     r2, #1              //Deassert
    bl      FE_ASSERT_DEASSERT
    mov     r2, #1              //PLL7
    bl      FE_SET_PLL
    mov     r2, #1              // M = 0 (m-1)
    bl      FE_SET_M
    bl      FE_AHB_GATING       // Gatting AHB to DE FE  AHB_GATING_REG1
    mov     r2, #1              //Enable
    bl      FE_ENABLE_DISABLE
    mov     r2, #0              //Disable
    bl      FE_ENABLE_DISABLE
    mov     r1, #1              //Pass
    bl      DRAM_FE_DCLK_GATING
    mov     r1, #0              //Mask
    bl      DRAM_FE_DCLK_GATING

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// DE_BE_Init
// initialize DE BE, DE FE
// ========================================================================
DE_BE_Init:
    push {r0-r5, lr}

    // Set PLL3 Main Frequency to 297mhz (Integer Mode) (we use PLL3 As Per Code)
    
    //  Component   Clock Source        Source Frequency    Divider (M)                 Final Frequency
    //  ------------------------------------------------------------------------------------------------
    //  PLL3        3 MHz Internal      3 MHz               99 (M=99)                   297 MHz
    //  BE          PLL3                PLL3_Out            M = 0 M+1                   297 MHz

//  c) Init BE VIMP.                                                                inCode Label: Image_init
//      i> Init BE Clock                                                                inCode Sub: image_clk_init
//          - BE_CFG_REG Clear bit[30] 1:Deassert                                       inCode Label: h_debe0mclk
//          - BE_CFG_REG Set bits[24-25] 0b00:PLL3 Set BE to PLL3 (297mhz|99|0)             inCode Label: h_debe0mclk
//          - Check Frequency NC.       it gives zero in BE But it is Ok in code
//          - BE_CFG_REG Set bits[0-3] 0:CLK_DIV_RATIO_M make sure no devider               inCode Label: h_debe0mclk
//          - BE_AHB_GATING Set bit[12] 1:Pass                                              inCode Label: h_debe0ahbclk
//          - BE Dclk Gatting Set bit[26] 1:Pass                                            inCode Label: h_debe0dramclk
//          - BE Dclk Gatting Set bit[26] 0:Mask                                            inCode Label: h_debe0dramclk
//          - BE_CFG_REG Set bit[31] 1:Enable                                               inCode Label: h_debe0mclk
//      ii> Turn On BE Clock                                                            inCode Sub: image_clk_on
//      iii> Clean BE Registers All BE Registers Have To Be Zero before proceed (Bug)   inCode Sub: DE_BE_Reg_Init
//      iv> Clean Display Sprite I guess this is when you clean the Video Memory        inCode Sub: BSP_disp_sprite_init
//      v> Search for The Script FEX that has LCD Data (Already Hard Coded)             inCode Sub: BSP_disp_set_output_csc
//      vi> Turn On And Start BE Using DEBE_MODCTL_REG                                  inCode Sub: Image_open
//          - START_CTL Set bit[1] 1:Start                                              inCode Sub: DE_BE_Enable
//          - DEBE_EN Set bit[0] 1:Enable                                               inCode Sub: DE_BE_Enable
 
    //i>
    mov     r2, #1              //Deassert
    bl      BE_ASSERT_DEASSERT
    
    mov     r2, #0              //PLL3
    bl      BE_SET_PLL
    
    mov     r2, #1              // M = 0 (m-1)
    bl      BE_SET_M
    bl      BE_AHB_GATING       // Gatting AHB to DE FE  AHB_GATING_REG1
    mov     r1, #1              //Pass
    bl      DRAM_BE_DCLK_GATING
    mov     r1, #0              //Mask
    bl      DRAM_BE_DCLK_GATING
    mov     r2, #1              //Enable
    bl      BE_ENABLE_DISABLE

    //ii>
    mov     r1, #1              //Pass
    bl      DRAM_BE_DCLK_GATING

    //iii>
    bl      BE_REGISTERS_CLEAN
    
    //iv>
    
    //v>
    
    //vi>
    bl      DE_BE_Start
    bl      DE_BE_Enable
    

    pop     {r0-r5, pc}
    .ltorg
    
// ========================================================================
// TCON_INIT
// initialize TCON
// ========================================================================
TCON_INIT:
    push {r0-r5, lr}

    // Set PLL3 Main Frequency to 297mhz (Integer Mode) (we use PLL3 As Per Code)
    
    //  Component   Clock Source    Source Frequency    Divider (M)    Final Frequency
    //  -------------------------------------------------------------------------------
    //  PLL3        3 MHz Internal  3 MHz               99 (M=99)      297 MHz
    //  TCON        PLL3            297 MHz             8 (M+1=9)      33 MHz    tDCLK = tSCLK * DIVCLCK (33Mhz = 297 / 9)

    // ---- 2d: setup TCON LCD_CH0_CFG_REG Main Frequency to 33mhz Source PLL3 (this missing from the manual)
    //
    // LCD_CH0_CFG_REG -- Explain as per Source (Missing from manual)
    // CLK_DIV_RATIO_M    (bits 0-3) 00:M=1 01:M=2 02:M=3 .............15:M=16 (May Be Not Exist For CH0)
    // SCLK_SRC_SEL       (bits 24-25) 00: PLL3 01: PLL7 10: PLL3x2 11: PLL7x2
    // TVE_RST            (bit 29) 0: reset valid, 1: reset invalid
    // LCD_RST            (bit 30) 0: reset valid, 1: reset invalid
    // SCLK_GATING        (bit 31) 0: Clock is OFF 1: Clock is ON
    // Notice, No div here cause SCLK has to be Equal to PLL3 or PLL7 or PLL3x2 or PLL7x2 [CLK-OUT = CLK-IN]
    //
    // |PLL3x1| -------------->  -------------------
    // |PLL7x1| --------------> |   LCD-CH0-CLK     |        LCD-CH0-CLK-OUT
    // |PLL3x2| --------------> | CLK-OUT = CLK-IN  |------------------------>
    // |PLL7x2| -------------->  -------------------
    //

//  d) Init TCON VIMP.                                                              inCode Label: Disp_lcdc_init
//      i> Init TCON Clock                                                              inCode Sub: lcdc_clk_init
//          - LCD_CH0_CFG_REG Set bits[24-25] 0b00:PLL3 Set LCD to PLL3 (297mhz|99|0)       inCode Label: h_lcd0ch0mclk0
//          - LCD_CH0_CFG_REG Clear bit[30] 1:Deassert                                      inCode Label: h_lcd0ch0mclk0
//          - LCD_CH0_AHB_GATING Set bit[4] 1:Pass                                          inCode Label: h_lcd0ahbclk
//          - LCD_CH0_CFG_REG Set bit[31] 1:Enable                                          inCode Label: h_lcd0ch0mclk0
//          - LCD_CH0_CFG_REG Set bit[31] 0:Disable                                         inCode Label: h_lcd0ch0mclk0
//      ii> Turn On TCON Clock                                                          inCode Sub: lcdc_clk_on
//          - LCD_CH0_CFG_REG Set bit[31] 1:Enable                                          inCode Label: h_lcd0ch0mclk0
//      iii> Init LCD Controller                                                        inCode Sub: LCDC_init
//          - Close TCON0 ((Disable TCON0 And Set TCON0_IO_TRI_REG Default)                 inCode Sub: TCON0_close
//              #TCON0_CTL_REG Clear Bit[31] TCON_EN 0:Disable
//              #TCON0_IO_TRI_REG Set Bit[0-31] 0xFFFFFFFF (Default)
//          - Enable Global Interrupt                                                             inCode Sub: LCDC_enable_int
//              #TCON_GINT0_REG Set bit[31] TCON0_Vb_Int_En 1:Enable
//              #TCON_GINT0_REG Set bit[29] TCON0_Line_Int_En 1:Enable
//          - Select Source                                                                inCode Sub: BSP_disp_set_output_csc
//              #TCON0_CTL_REG Clear Bits[22] TCON0_Test_Value 0:all black
//              #TCON0_CTL_REG Clear Bit[0-1] TCON0_SRC_SEL 0b00:select DE Ch1
//          - Turn On TCON0                                                                 inCode Sub: LCDC_open
//              #TCON0_DCLK_REG Bit[31] TCON0_Dclk_En 1:Enable
//              #TCON_GCTL_REG Bit[31] TCON_EN 1:Enable
//      iv> Turn Off LCD Clock                                                          inCode Sub: lcdc_clk_off
//          - LCD_CH0_CFG_REG Clear Bit[31] 0:Disable
//
//
    //i>
    mov     r2, #0              //PLL3
    bl      TCON_SET_PLL

    mov     r2, #1              //Deassert
    bl      TCON_ASSERT_DEASSERT

    bl      LCD_AHB_GATING      // Gatting AHB to LCD  AHB_GATING_REG1

    mov     r2, #1              //Enable
    bl      TCON_ENABLE_DISABLE

    mov     r2, #0              //Disable
    bl      TCON_ENABLE_DISABLE

    //ii>
    mov     r2, #1              //Enable
    bl      TCON_ENABLE_DISABLE

    //iii>
    mov     r2, #0              //Close
    bl      TCON_OPEN_CLOSE_CONTROLLER
    mov     r2, #0xFFFFFFFF     //Disable (-1)
    bl      TCON_IO_TRI_ENABLE_DISABLE
    
    mov     r2, #0x80000000       //TCON0_Vb_Int_En 1:Enable
    bl      TCON_GINT_ENABLE
    mov     r2, #0x20000000       //TCON0_Line_Int_En 1:Enable
    bl      TCON_GINT_ENABLE

    mov     r2, #0              // DE CH1(FIFO1 enable)
    bl      TCON_LINK_SOURCE
    
    mov     r2, #1             //DCLK ON
    bl      TCON_DCLK_ON_OFF
    mov     r2, #1             //GCONT Enable
    bl      TCON_GLOBAL_CONTROLLER_ENABLE_DISABLE

    //iv>
    mov     r2, #0             //Disable
    bl      TCON_ENABLE_DISABLE

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// clock_set_pll3_297MHZ
// Set PLL3 Clock to 297 MHz for TCON
// ========================================================================
clock_set_pll3_297MHZ:
    push    {r0-r5, lr}

    // ---- clock_set_pll3(unsigned int clk)
    ldr     r0, =CCM_BASE
    //ldr     r1, [r0, #PLL3_CFG_REG]             // Read Current Configurations
    //bic     r1, r1, #(0b1111111 << 0)           // Clear bite [0:6] Bits
    //orr     r1, r1, #(99 << 0)                  // Set bits [0:6] PLL3_FACTOR_M 99 3mhz*99 = 297mhz 99=(297/3)
    //orr     r1, r1, #(0b1 << 15)                // Set bit [15] PLL3_MODE_SEL 0: fractional 1: integer
    //orr     r1, r1, #(0b1 << 14)                // Set bit [15] PLL3_FUNC_SEL 0: 270mhz 1: 297mhz
    //orr     r1, r1, #(0b1 << 31)                // Set bit [31] PLL3_Enable 0: disable 1: enable
    ldr     r1, =0x8010D063                     // Sets All In One Step Plus All Defaults
    str     r1, [r0, #PLL3_CFG_REG]             // turn it on after complete setup values

.verify_PLL3_CFG:
    ldr     r3, [r0, #PLL3_CFG_REG]
    cmp     r1, r3
    bne     .verify_PLL3_CFG

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// clock_set_pll3_297MHZ
// Set PLL3 Clock to 297 MHz for TCON
// ========================================================================
clock_set_pll7_297MHZ:
    push    {r0-r5, lr}

    // ---- clock_set_pll3(unsigned int clk)
    ldr     r0, =CCM_BASE
    //ldr     r1, [r0, #PLL7_CFG_REG]               // Read Current Configurations
    //bic     r1, r1, #(0b1111111 << 0)             // Clear bite [0:6] Bits
    //orr     r1, r1, #(99 << 0)                    // Set bits [0:6] PLL3_FACTOR_M 99 3mhz*99 = 297mhz 99=(297/3)
    //orr     r1, r1, #(0b1 << 15)                  // Set bit [15] PLL3_MODE_SEL 0: fractional 1: integer
    //orr     r1, r1, #(0b1 << 14)                  // Set bit [15] PLL3_FUNC_SEL 0: 270mhz 1: 297mhz
    //orr     r1, r1, #(0b1 << 31)                  // Set bit [31] PLL3_Enable 0: disable 1: enable
    ldr     r1, =0x8010D063                         // Sets All In One Step Plus All Defaults
    str     r1, [r0, #PLL7_CFG_REG]                 // turn it on after complete setup values

.verify_PLL7_CFG:
    ldr     r3, [r0, #PLL7_CFG_REG]
    cmp     r1, r3
    bne     .verify_PLL7_CFG

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// clock_get_pll3
// gets the current pll3 frequency for the DE & FE and non DRAM Purposes
// Input: [CCM_BASE]
// Input: [PLL3_CFG_REG]
// Return: r5 the current PLL3 frequency
// ========================================================================
clock_get_pll3:
    push    {r0-r4, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #PLL3_CFG_REG]       @ read PLL3_CFG

    and     r1, r1, #0x7F                 @ PLL3_FACTOR_M = bits[0:6]

    movw    r2, #0xC6C0                   @ low 16 of 3000000 = 0xC6C0
    movt    r2, #0x002D                   @ high 16 -> r2 = 0x2DC6C0 = 3000000

    mul     r5, r2, r1                    @ r5 = 3_000_000 * M

    pop     {r0-r4, pc}
    .ltorg

// ========================================================================
// clock_get_pll7
// gets the current pll7 frequency for the DE & FE and non DRAM Purposes
// Input: [CCM_BASE]
// Input: [PLL7_CFG_REG]
// Return: r5 the current PLL7 frequency
// ========================================================================
clock_get_pll7:
    push    {r0-r4, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #PLL3_CFG_REG]       @ read PLL3_CFG

    and     r1, r1, #0x7F                 @ PLL3_FACTOR_M = bits[0:6]

    movw    r2, #0xC6C0                   @ low 16 of 3000000 = 0xC6C0
    movt    r2, #0x002D                   @ high 16 -> r2 = 0x2DC6C0 = 3000000

    mul     r5, r2, r1                    @ r5 = 3_000_000 * M

    pop     {r0-r4, pc}
    .ltorg

// ========================================================================
// clock_get_pll5p
// gets the current pll5 frequency for the DE & FE and non DRAM Purposes
// Input: [CCM_BASE]
// Input: [PLL5_CFG_REG]
// Return: r5 the current PLL5 frequency
// ========================================================================
clock_get_pll5p:
    push    {r0-r4, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #PLL5_CFG_REG]         // (Default: 0x00000000)
    
    @ Extract K
    mov     r2, r1, lsr #4                  // Get K (bits [8-12] shift right r1 by 16 bits, store in r2 moves bits 8-12 to bit 0-4
    and     r2, r2, #3                      // mask 0b11111 (#0x1F) 00:1 01:2 10:3 11:4
    add     r2, r2, #1                      // Add 1 to map to 1, 2, 3, or 4.
                                        // r2 got K
    @ Extract N
    mov     r3, r1, lsr #8                  // Get N (bits [8-12] shift right r1 by 16 bits, store in r2 moves bits 8-12 to bit 0-4
    and     r3, r3, #0x1F                   // mask 0b11111 (#0x1F) N from 0 to 31
                                        // r3 got N
    @ Extract P
    mov     r4, r1, lsr #16                 // Get P (bits [16-17] shift right r1 by 16 bits, store in r2 moves bits 16,17 to bit 0-1
    and     r4, r4, #3                      // mask 0b11 (#3) P value 00:1 01:2 10:4 11:8 P should be (1/2/4/8)
                                        // but we going to use it as shift instead of div like (lsr #3) equal to (div over #8)
                                        // so we keep it as its value
                                        
    ldr     r5, =24000000                   // OSC24M 24mhz

    mul     r6, r2, r3                      // r6 = K * N
    mul     r5, r6, r5                      // r5 = 24MHZ * N * K

    lsr     r5, r4                          // r5 = (24000000 * N * K) >> P
    
    @ Divide by 1/2/4/8 using logical shift right by r4 (0..3)
    cmp     r4, #0
    beq     .no_shift
    lsr     r5, r5, r4                  // r5 >>= r4  (divide by 2^P)

.no_shift:                                        // r5 got PLL5 Current Frequency
    pop     {r0-r4, pc}
    .ltorg

// ========================================================================
// FE_ASSERT_DEASSERT
// Assert FE (Enable Reset) /Deassert FE (Disable Reset)
// r2 = Reset_State
// ========================================================================
FE_ASSERT_DEASSERT:
    push {r0-r5, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #FE_CFG_REG]           // Read Current Configurations
    bic     r1, r1, #(0b1 << 30)            // Clear bit[30]
    orr     r1, r1, r2, lsl #30             // Set bit [30] FE_RST 0 = reset valid 1 = reset invalid
    str     r1, [r0, #FE_CFG_REG]
    
.verify_FE_RST:
    ldr     r3, [r0, #FE_CFG_REG]
    cmp     r3, r1
    bne     .verify_FE_RST

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// FE_Enable_Disable
// Enable/Disable FE
// r2 = Enable/Disable
// ========================================================================
FE_ENABLE_DISABLE:
    push {r0-r5, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #FE_CFG_REG]           // Read Current Configurations
    bic     r1, r1, #(0b1 << 31)            // Clear bit[31]
    orr     r1, r1, r2, lsl #31             // Set bit [31] FE_EN 0 = Disable 1 = Enable
    str     r1, [r0, #FE_CFG_REG]
    
.verify_FE_EN:
    ldr     r3, [r0, #FE_CFG_REG]
    cmp     r3, r1
    bne     .verify_FE_EN

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// FE_SET_M
// PLL SET For FE
// r2 = PLL   00: PLL3 01: PLL7 10: PLL5
// ========================================================================
FE_SET_PLL:
    push {r0-r5, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #FE_CFG_REG]           // Read Current Configurations
    bic     r1, r1, #(0b11 << 24)           // Clear bits[24-25]
    orr     r1, r1, r2, lsl #24             // Set bits [24-25] CLK_SRC_SEL 00: PLL3 01: PLL7 10: PLL5
    str     r1, [r0, #FE_CFG_REG]
    
.verify_FE_PLL:
    ldr     r3, [r0, #FE_CFG_REG]
    cmp     r3, r1
    bne     .verify_FE_PLL

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// FE_SET_M
// M Devider SET For FE
// r2 = M Div
// ========================================================================
FE_SET_M:
    push {r0-r5, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #FE_CFG_REG]           // Read Current Configurations
    bic     r1, r1, #(0xF << 0)             // Clear bits [0-3]
    sub     r2, r2, #1                      // m - 1
    and     r2, r2, #0xF                    // masking to make sure we only has 4 bits at [0-3] LSB
    orr     r1, r1, r2                      // Set bits [0-3] CLK_DIV_RATIO_M m = r2-1 (m+1) = r2, pll5/r2 = 300Mhz
    str     r1, [r0, #FE_CFG_REG]
    
.verify_FE_M:
    ldr     r3, [r0, #FE_CFG_REG]
    cmp     r3, r1
    bne     .verify_FE_M

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// BE_ASSERT_DEASSERT
// Assert BE (Enable Reset) /Deassert BE (Disable Reset)
// r2 = Reset_State
// ========================================================================
BE_ASSERT_DEASSERT:
    push {r0-r5, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #BE_CFG_REG]           // Read Current Configurations
    bic     r1, r1, #(0b1 << 30)            // Clear bit[30]
    orr     r1, r1, r2, lsl #30             // Set bit [30] BE_RST 0 = reset valid 1 = reset invalid
    str     r1, [r0, #BE_CFG_REG]
    
.verify_BE_RST:
    ldr     r3, [r0, #BE_CFG_REG]
    cmp     r3, r1
    bne     .verify_BE_RST

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// BE_Enable_Disable
// Enable/Disable BE
// r2 = Enable/Disable
// ========================================================================
BE_ENABLE_DISABLE:
    push {r0-r5, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #BE_CFG_REG]           // Read Current Configurations
    bic     r1, r1, #(0b1 << 31)            // Clear bit[31]
    orr     r1, r1, r2, lsl #31             // Set bit [31] BE_EN 0 = Disable 1 = Enable
    str     r1, [r0, #BE_CFG_REG]
    
.verify_BE_EN:
    ldr     r3, [r0, #BE_CFG_REG]
    cmp     r3, r1
    bne     .verify_BE_EN

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// BE_SET_M
// PLL SET For BE
// r2 = PLL   00: PLL3 01: PLL7 10: PLL5
// ========================================================================
BE_SET_PLL:
    push {r0-r5, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #BE_CFG_REG]           // Read Current Configurations
    bic     r1, r1, #(0b11 << 24)           // Clear bits[24-25]
    orr     r1, r1, r2, lsl #24             // Set bits [24-25] CLK_SRC_SEL 00: PLL3 01: PLL7 10: PLL5
    str     r1, [r0, #BE_CFG_REG]
    
.verify_BE_PLL:
    ldr     r3, [r0, #BE_CFG_REG]
    cmp     r3, r1
    bne     .verify_BE_PLL

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// BE_SET_M
// M Devider SET For BE
// r2 = M Div
// ========================================================================
BE_SET_M:
    push {r0-r5, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #BE_CFG_REG]           // Read Current Configurations
    bic     r1, r1, #(0xF << 0)             // Clear bits [0-3]
    sub     r2, r2, #1                      // m - 1
    and     r2, r2, #0xF                    // masking to make sure we only has 4 bits at [0-3] LSB
    orr     r1, r1, r2                      // Set bits [0-3] CLK_DIV_RATIO_M m = r2-1 (m+1) = r2, pll5/r2 = 300Mhz
    str     r1, [r0, #BE_CFG_REG]
    
.verify_BE_M:
    ldr     r3, [r0, #BE_CFG_REG]
    cmp     r3, r1
    bne     .verify_BE_M

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// BE_REGISTERS_CLEAN
// Clean all BE Registers (Bug workaround)
// r2 = Reset_State
// ========================================================================
BE_REGISTERS_CLEAN:
    push {r0-r5, lr}

    // Engine bug, clear DEBE registers after reset
    ldr     r0, =DEBE_BASE
    mov     r1, #0
    mov     r2, #DEBE_MODCTL_REG   // 0x800 (first register at DEBE
    mov     r4, #0x1000
    
.clearloop:
    add     r3, r0, r2
    str     r1, [r3]
    add     r2, r2, #4              //Clean Next Register and next etc...
    cmp     r2, r4
    blt     .clearloop

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// DE_BE_Start
// Start DEBE
// ========================================================================
DE_BE_Start:
    push    {r0-r5, lr}

    ldr     r0, =DEBE_BASE

    ldr     r1, [r0, #DEBE_MODCTL_REG]
    orr     r1, r1, #(0b1 << 1)                 // Set bit [1] (START_CTL) 0:Reset 1:Start
    str     r1, [r0, #DEBE_MODCTL_REG]

.verify_DE_BE_Start:
    ldr     r3, [r0, #DEBE_MODCTL_REG]      @ read back
    tst     r3, #(0b1 << 1)
    beq     .verify_DE_BE_Start             @ if not zero loop

    pop     {r0-r5, pc}
    .ltorg
//End of function DE_BE_StartEnable

// ========================================================================
// DE_BE_Enable
// Enable DEBE
// ========================================================================
DE_BE_Enable:
    push    {r0-r5, lr}

    ldr     r0, =DEBE_BASE
    ldr     r1, [r0, #DEBE_MODCTL_REG]
    orr     r1, r1, #(0b1 << 0)                 // Set bit [0] (DEBE_EN) 0:Disable 1:Enable
    str     r1, [r0, #DEBE_MODCTL_REG]
    
.verify_DE_BE_Enable:
    ldr     r3, [r0, #DEBE_MODCTL_REG]          @ read back
    tst     r3, #(0b1 << 0)
    beq     .verify_DE_BE_Enable                @ if zero loop
    
    pop     {r0-r5, pc}
    .ltorg
//End of function DE_BE_StartEnable


// ========================================================================
// TCON_ASSERT_DEASSERT
// Assert TCON (Enable Reset) /Deassert TCON (Disable Reset)
// r2 = Reset_State
// ========================================================================
TCON_ASSERT_DEASSERT:
    push {r0-r5, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #LCD_CH0_CFG_REG]      // Read Current Configurations
    bic     r1, r1, #(0b1 << 30)            // Clear bit[30]
    orr     r1, r1, r2, lsl #30             // Set bit [30] TCON_RST 0 = reset valid 1 = reset invalid
    str     r1, [r0, #LCD_CH0_CFG_REG]
    
.verify_LCD_RST:
    ldr     r3, [r0, #LCD_CH0_CFG_REG]
    cmp     r3, r1
    bne     .verify_LCD_RST

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// TCON_Enable_Disable
// Enable/Disable TCON
// r2 = Enable/Disable
// ========================================================================
TCON_ENABLE_DISABLE:
    push {r0-r5, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #LCD_CH0_CFG_REG]           // Read Current Configurations
    bic     r1, r1, #(0b1 << 31)            // Clear bit[31]
    orr     r1, r1, r2, lsl #31             // Set bit [31] TCON_EN 0 = Disable 1 = Enable
    str     r1, [r0, #LCD_CH0_CFG_REG]
    
.verify_LCD_EN:
    ldr     r3, [r0, #LCD_CH0_CFG_REG]
    cmp     r3, r1
    bne     .verify_LCD_EN

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// TCON_SET_PLL
// PLL SET For TCON
// r2 = PLL   00: PLL3 01: PLL7 10: PLL3x2 11: PLL7x2
// ========================================================================
TCON_SET_PLL:
    push {r0-r5, lr}

    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #LCD_CH0_CFG_REG]           // Read Current Configurations
    bic     r1, r1, #(0b11 << 24)           // Clear bits[24-25]
    orr     r1, r1, r2, lsl #24             // Set bits [24-25] CLK_SRC_SEL 00: PLL3 01: PLL7 10: PLL5
    str     r1, [r0, #LCD_CH0_CFG_REG]
    
.verify_LCD_PLL:
    ldr     r3, [r0, #LCD_CH0_CFG_REG]
    cmp     r3, r1
    bne     .verify_LCD_PLL

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// TCON_OPEN_CLOSE_CONTROLLER
// CONTROLLER ON/OFF For TCON
// r2 = ON/OFF   00: CLOSE 01: OPEN
// ========================================================================
TCON_OPEN_CLOSE_CONTROLLER:
    push {r0-r5, lr}

    ldr     r0, =TCON_BASE
    ldr     r1, [r0, #TCON0_CTL_REG]
    bic     r1, r1, #(0b1 << 31)            // Clear bit[31]
    orr     r1, r1, r2, lsl #31             // Set bit [31] TCON0_En 0:Disable 1:Enable
    str     r1, [r0, #TCON0_CTL_REG]
   
.verify_LCD_ON_OFF:
    ldr     r3, [r0, #TCON0_CTL_REG]
    cmp     r3, r1
    bne     .verify_LCD_ON_OFF

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// TCON_IO_TRI_ENABLE_DISABLE
// TCON IO TRI ENABLE DISABLE (important to let lcd turn on)
// r2 = TRI STATE 0s:enable 1s:disable
//      0: enable
//      -1: disable
// ========================================================================
TCON_IO_TRI_ENABLE_DISABLE:
    push {r0-r5, lr}

    ldr     r0, =TCON_BASE
    str     r2, [r0, #TCON0_IO_TRI_REG]

.verify_LCD_IO:
    ldr     r3, [r0, #TCON0_IO_TRI_REG]
    cmp     r3, r2
    bne     .verify_LCD_IO

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// TCON_GINT_ENABLE
// TCON GLOBAL INTERRUPT ON/OFF For TCON
// r2 = int enabler
//      0x80000000  Set bit[31] TCON0_Vb_Int_En
//      0x20000000  Set bit[29] TCON0_Line_Int_En
// ========================================================================
TCON_GINT_ENABLE:
    push {r0-r5, lr}

    ldr     r0, =TCON_BASE
    ldr     r1, [r0, #TCON_GINT0_REG]
    orr     r1, r1, r2          //Set bit[31] TCON0_Vb_Int_En 0:Disable 1:Enable
                                //Set bit[29] TCON0_Line_Int_En 0:Disable 1:Enable
    str     r1, [r0, #TCON_GINT0_REG]
   
.verify_LCD_GINT:
    ldr     r3, [r0, #TCON_GINT0_REG]
    cmp     r3, r1
    bne     .verify_LCD_GINT

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// TCON_LINK_SOURCE
// LINK Engine To TCON As A Source
// r2 = Engine
//      0: DE CH1(FIFO1 enable)
//      1: DE CH2(FIFO1 enable)
//      2: DMA 565 input(FIFO1 enable)
//      3: Test intput(FIFO1 disable)
// ========================================================================
TCON_LINK_SOURCE:
    push {r0-r5, lr}

    ldr     r0, =TCON_BASE
    ldr     r1, [r0, #TCON0_CTL_REG]
    bic     r1, r1, #(0b11 << 0)                // Clear bits[0-1]
    orr     r1, r1, r2, lsl #0                  // Set bits[0-1]    0b00: DE CH1(FIFO1 enable)
                                                //                  0b01: DE CH2(FIFO1 enable)
                                                //                  0b10: DMA 565 input(FIFO1 enable)
                                                //                  0b11: Test intput(FIFO1 disable)
    bic     r1, r1, #(0b1 << 22)                // Clear bit[22] TCON0_Test_Value 0:Disable Test Value 1: all 1's
    str     r1, [r0, #TCON0_CTL_REG]
   
.verify_LCD_LINK:
    ldr     r3, [r0, #TCON0_CTL_REG]
    cmp     r3, r1
    bne     .verify_LCD_LINK

    pop     {r0-r5, pc}
    .ltorg


// ========================================================================
// TCON_DCLK_ON_OFF
// TCON DCLK ON/OFF
// r2 = State
//      0:Off
//      1:ON
// ========================================================================
TCON_DCLK_ON_OFF:
    push {r0-r5, lr}

    ldr     r0, =TCON_BASE
    ldr     r1, [r0, #TCON0_DCLK_REG]
    bic     r1, r1, #(0b1 << 31)            // Clear bit[31]
    orr     r1, r1, r2, lsl #31             // Set bit [31] TCON0_Dclk_En 0 = Disable 1 = Enable
    str     r1, [r0, #TCON0_DCLK_REG]
   
.verify_LCD_DCLK:
    ldr     r3, [r0, #TCON0_DCLK_REG]
    cmp     r3, r1
    bne     .verify_LCD_DCLK

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// TCON_GLOBAL_CONTROLLER_ENABLE_DISABLE
// TCON GLOBAL CONTROLLER ENABLER
// r2 = State
//      0:Disable
//      1:Enable
// ========================================================================
TCON_GLOBAL_CONTROLLER_ENABLE_DISABLE:
    push {r0-r5, lr}

    ldr     r0, =TCON_BASE
    ldr     r1, [r0, #TCON_GCTL_REG]
    bic     r1, r1, #(0b1 << 31)            // Clear bit[31]
    orr     r1, r1, r2, lsl #31             // Set bit [31] TCON0_Dclk_En 0 = Disable 1 = Enable
    str     r1, [r0, #TCON_GCTL_REG]
   
.verify_LCD_GCTL:
    ldr     r3, [r0, #TCON_GCTL_REG]
    cmp     r3, r1
    bne     .verify_LCD_GCTL

    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// LCD_SCLK_GATING
// LCD_CH0_CFG_REG set bit[31] turn on clk
// ========================================================================
LCD_SCLK_GATING:
    push    {r0-r5, lr}

    //setbits_le32(&ccm->ahb_gate1, 1 << AHB_GATE_OFFSET_DE_BE0)//
    // Gatting AHB to DE BE  AHB_GATING_REG1
    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #LCD_CH0_CFG_REG]
    orr     r1, r1, #(0b1 << 31)            // Set bit [31] SCLK_GATING 0 = clock off 1 = clock on
    str     r1, [r0, #LCD_CH0_CFG_REG]

.verify_LCD_SCLK_GATING:
    ldr     r1, [r0, #LCD_CH0_CFG_REG]
    tst     r1, #(0b1 << 31)
    beq     .verify_LCD_SCLK_GATING
    
    pop     {r0-r5, pc}
    .ltorg
//End of function LCD_SCLK_GATING


// ========================================================================
// BE_SCLK_GATING
// BE_CFG_REG set bit[31] turn on clk
// ========================================================================
BE_SCLK_GATING:
    push    {r0-r5, lr}

    //setbits_le32(&ccm->ahb_gate1, 1 << AHB_GATE_OFFSET_DE_BE0)//
    // Gatting AHB to DE BE  AHB_GATING_REG1
    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #BE_CFG_REG]
    orr     r1, r1, #(0b1 << 31)            // Set bit [31] SCLK_GATING 0 = clock off 1 = clock on
    str     r1, [r0, #BE_CFG_REG]

.verify_BE_SCLK_GATING:
    ldr     r1, [r0, #BE_CFG_REG]
    tst     r1, #(0b1 << 31)
    beq     .verify_BE_SCLK_GATING
    
    pop     {r0-r5, pc}
    .ltorg
//End of function BE_AHB_GATING

// ========================================================================
// FE_SCLK_GATING
// FE_CFG_REG set bit[31] turn on clk
// ========================================================================
FE_SCLK_GATING:
    push    {r0-r5, lr}

    //setbits_le32(&ccm->ahb_gate1, 1 << AHB_GATE_OFFSET_DE_BE0)//
    // Gatting AHB to DE BE  AHB_GATING_REG1
    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #FE_CFG_REG]
    orr     r1, r1, #(0b1 << 31)            // Set bit [31] SCLK_GATING 0 = clock off 1 = clock on
    str     r1, [r0, #FE_CFG_REG]

.verify_FE_SCLK_GATING:
    ldr     r1, [r0, #FE_CFG_REG]
    tst     r1, #(0b1 << 31)
    beq     .verify_FE_SCLK_GATING
    
    pop     {r0-r5, pc}
    .ltorg
//End of function BE_AHB_GATING


// ========================================================================
// DRAM_BE_DCLK_GATING
// DRAM_SCLK_CFG_REG set bit[26] turn on clk
// ========================================================================
DRAM_BE_DCLK_GATING:
    push    {r0-r5, lr}
    
    //setbits_le32(&ccm->dram_clk_gate, 1 << CCM_DRAM_GATE_OFFSET_DE_BE0)//
    // Gatting DRAM to DEBE
    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #DRAM_SCLK_CFG_REG]    // (Default: 0x00000000)
    orr     r1, r1, #(0b1 << 26)            // Set bit [26] DRAM_GATE_DE_BE0 0:mask 1:pass Gating DRAM Clock for DE-BE
    str     r1, [r0, #DRAM_SCLK_CFG_REG]

.verify_DRAM_BE_DCLK_GATING:
    ldr     r1, [r0, #DRAM_SCLK_CFG_REG]
    tst     r1, #(0b1 << 26)                // test DRAM_GATE_DE_BE0
    beq     .verify_DRAM_BE_DCLK_GATING        // loop until bit set
    
    pop     {r0-r5, pc}
    .ltorg
//End of function DRAM_BE_DCLK_GATING

// ========================================================================
// DRAM_FE_DCLK_GATING
// DRAM_SCLK_CFG_REG set bit[25] turn on clk
// ========================================================================
DRAM_FE_DCLK_GATING:
    push    {r0-r5, lr}
    
    //setbits_le32(&ccm->dram_clk_gate, 1 << CCM_DRAM_GATE_OFFSET_DE_BE0)//
    // Gatting DRAM to DEBE
    mov     r3, r1
    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #DRAM_SCLK_CFG_REG]    // (Default: 0x00000000)
    bic     r1, r1, #(0b1 << 25)
    orr     r1, r1, r3, lsl #25              // Set bit [25] DRAM_GATE_DE_FE0 0:mask 1:pass Gating DRAM Clock for DE-FE
    str     r1, [r0, #DRAM_SCLK_CFG_REG]

.verify_DRAM_FE_DCLK_GATING:
    ldr     r3, [r0, #DRAM_SCLK_CFG_REG]
    cmp     r3, r1                          // test DRAM_GATE_DE_BE0
    bne     .verify_DRAM_FE_DCLK_GATING        // loop until bit set
    
    pop     {r0-r5, pc}
    .ltorg
//End of function DRAM_BE_DCLK_GATING


// ========================================================================
// BE_AHB_GATING
// AHB_GATING_REG1 Set bit[12] BE_AHB_GATING
// ========================================================================
BE_AHB_GATING:
    push    {r0-r5, lr}

    //setbits_le32(&ccm->ahb_gate1, 1 << AHB_GATE_OFFSET_DE_BE0)//
    // Gatting AHB to DE BE  AHB_GATING_REG1
    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #AHB_GATING_REG1]      // (Default: 0x00000000)
    orr     r1, r1, #(0b1 << 12)            // Set bit [12] BE_AHB_GATING 0:mask 1:pass Gating AHB Clock for DE-BE
    str     r1, [r0, #AHB_GATING_REG1]

.verify_BE_AHB_GATING:
    ldr     r1, [r0, #AHB_GATING_REG1]      // (Default: 0x00000000)
    tst     r1, #(0b1 << 12)
    beq     .verify_BE_AHB_GATING
   
    pop     {r0-r5, pc}
    .ltorg
//End of function BE_AHB_GATING

// ========================================================================
// FE_AHB_GATING
// AHB_GATING_REG1 Set bit[14] FE_AHB_GATING
// ========================================================================
FE_AHB_GATING:
    push    {r0-r5, lr}

    //setbits_le32(&ccm->ahb_gate1, 1 << AHB_GATE_OFFSET_DE_FE0)//
    // Gatting AHB to DE FE  AHB_GATING_REG1
    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #AHB_GATING_REG1]      // (Default: 0x00000000)
    orr     r1, r1, #(0b1 << 14)            // Set bit [14] FE_AHB_GATING 0:mask 1:pass Gating AHB Clock for DE-FE
    str     r1, [r0, #AHB_GATING_REG1]

.verify_FE_AHB_GATING:
    ldr     r1, [r0, #AHB_GATING_REG1]      // (Default: 0x00000000)
    tst     r1, #(0b1 << 14)
    beq     .verify_FE_AHB_GATING
   
    pop     {r0-r5, pc}
    .ltorg
//End of function BE_AHB_GATING


// ========================================================================
// LCD_AHB_GATING
// AHB_GATING_REG1 Set bit[4] LCD_AHB_GATING
// ========================================================================
LCD_AHB_GATING:
    push    {r0-r5, lr}

    /* Clock on */
    // Gatting AHB to LCD  AHB_GATING_REG1
    //setbits_le32(&ccm->ahb_gate1, 1 << AHB_GATE_OFFSET_LCD0)//
    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #AHB_GATING_REG1]          // (Default: 0x00000000)
    orr     r1, r1, #(0b1 << 4)                 // Set bit [4] LCD_AHB_GATING 0:mask 1:pass Gating AHB Clock for LCD
    str     r1, [r0, #AHB_GATING_REG1]

.verify_LCD_AHB_GATING:
    ldr     r2, [r0, #AHB_GATING_REG1]
    tst     r2, #(1 << 4)
    beq     .verify_LCD_AHB_GATING

    pop     {r0-r5, pc}
    .ltorg
//End of function LCD_AHB_GATING








//###############################################################################################################
//########################################## Clean And Fill Framebuffer Functions ###############################
//###############################################################################################################

// ========================================================================
// test_DRAM
// Test Dram working after gate it to BE And FE
// ========================================================================
test_DRAM:
    push    {r0-r2, lr}
    ldr     r0, =FRAMEBUFFER_BASE
    ldr     r1, =0xA5A5A5A5
    str     r1, [r0]          @ write test pattern
    ldr     r2, [r0]          @ read back
    cmp     r2, r1
    bne     .dr_test_fail

    b       .end_dr_test

.dr_test_fail:
    bl      LED_Fast_Flash
    
.end_dr_test:
    pop     {r0-r2, pc}
    .ltorg

// ========================================================================
// fill_framebuffer
// Fill the framebuffer with a solid green color
// Input: [FRAMEBUFFER_BASE] Base address of the framebuffer
// Input: r1 Color value (solid color)
// Input: r2: Counter for the number of pixels
// ========================================================================
fill_framebuffer_black:
    push    {r0-r2, lr}
    ldr     r0, =FRAMEBUFFER_BASE
    ldr     r1, =COLOR_BACKGROUND                // Black color in RGBA8888 format (Alpha=FF, Red=00, Green=00, Blue=00)
    ldr     r2, =(lcd_x * lcd_y)            // Number of pixels

.fill_loop_bl:
    str     r1, [r0]                    // Store r1 inside [r0]
    add     r0, r0, #4                  // next word
    subs    r2, r2, #1                 // Decrement the counter
    bne     .fill_loop_bl                   // Branch back to the start of the loop

    pop     {r0-r2, pc}                 // Return from the subroutine
    .ltorg


// ========================================================================
// Clear D-Cache
// use it right right after you change the framebuffer and before enabling BE,FE,TCON
// inputs:
// r0 => FRAMEBUFFER_BASE
// r1 => FRAMEBUFFER_SIZE
// ========================================================================
clean_DCACHE_by_va:
    push    {r2-r4, lr}

    cmp     r1, #0
    beq     .done

    mov     r2, #32              @ CACHE_LINE = 32 bytes (adjust if needed)
    add     r3, r0, r1           @ end = start + len

.align_loop:
    @ Clean by VA to Point of Unification (DC CVAU variant)
    mcr     p15, 0, r0, c7, c10, 1   @ DC CVAU, Clean D-cache by VA to PoU/PoC (implementation dependent)
    add     r0, r0, r2
    cmp     r0, r3
    blt     .align_loop

    dsb
    isb

    pop     {r2-r4, pc}
.done:
    pop     {r2-r4, pc}
    .ltorg

// ========================================================================
// fill_framebuffer_with_photo
// Fill the framebuffer with a solid green color
// ========================================================================
fill_framebuffer_with_photo:
    push    {r0-r4, lr}
    ldr     r0, =FRAMEBUFFER_BASE
    ldr     r1, =0x40000000                     // Place where you loaded the photo
    ldr     r2, =(lcd_x * lcd_y)                // Number of pixels

.fill_loop_ph:
    mov     r4, r0
    ldr     r0, [r1]
    mov     r3, r0
    mov     r0, r4
    str     r3, [r0]                    // Store r1 inside [r0]
    add     r0, r0, #4                  // next word
    add     r1, r1, #4                  // next word
    subs    r2, r2, #1                 // Decrement the counter
    bne     .fill_loop_ph               // Branch back to the start of the loop

    pop     {r0-r4, pc}                 // Return from the subroutine
    .ltorg





//###############################################################################################################
//########################################## Display Startup Functions ##########################################
//###############################################################################################################

// ========================================================================
// LCD_Panel_Power_Enable
// turn off backlight, give power and send no reset to LCD Panel
// ========================================================================
LCD_Panel_Power_Enable:

    push {r0-r5, lr}
    
    bl BCK_L_OFF

    mov     r0, #20                                              // Give the backlight 20-40ms to turn off and power up the panel.
    bl      delay_ms

    bl      LCD_PWR_ON

    pop     {r0-r5, pc}
    
    .ltorg


// ========================================================================
// BE_Mode_Set
// set mode of DEBE and DEFE
// ========================================================================
BE_Mode_Set:
    push    {r0-r5, lr}
    
    mov     r2, #0xA                        // 0b1010 = 0xA(10) 32 bit Color
    mov     r3, #0x0                        // 0: RGB Mode 1: BGR Mode
    mov     r4, #0x0                        // 0: LAY_FBPS Pixels Sequence
    bl      DE_BE_Layer_Set_Format          // DE_BE_Layer_Set_Format

    bl      SET_GFX_ADDRESS_TO_DEBE         // Set The Framebuffer Address for hi and low address registers
    
    bl      SET_GFX_LINE_WIDTH_IN_BITS      // Assign the line width in bits not bytes (width x 4 x 8) for 32bit mode

    mov     r2, #0xFF                       //r2 = 0xFF Alpha Byte Full Opaque
    bl      DEBE_Set_Alpha
    
    bl      DEBE_Set_Screen_Win             // Set Window Of Screen Resolution

    bl      DEBE_Set_Full_Resolution

    bl      DEBE_Enable_Layer_0

    pop     {r0-r5, pc}
    .ltorg


// ========================================================================
// LCD_PIO_Set
// set mode of TCON
// ========================================================================
LCD_PIO_Set:
    push    {r0-r5, lr}

    ldr     r0, =PIO_BASE
    movw    r1, #0x2200                     // ldr r2, =0x22222200
    movt    r1, #0x2222
    str     r1, [r0, #PIO_PD_CFG0]              // PD2-PD7 to M2
    
.verify_PIO_PD_CFG0:
    ldr     r3, [r0, #PIO_PD_CFG0]
    cmp     r3, r1
    bne     .verify_PIO_PD_CFG0
                
    ldr     r0, =PIO_BASE
    movw    r1, #0x2200                     // ldr r2, =0x22222200
    movt    r1, #0x2222
    str     r1, [r0, #PIO_PD_CFG1]              // PD10-PD15 to M2

.verify_PIO_PD_CFG1:
    ldr     r3, [r0, #PIO_PD_CFG1]
    cmp     r3, r1
    bne     .verify_PIO_PD_CFG1
        
    ldr     r0, =PIO_BASE
    movw    r1, #0x2200                     // ldr r2, =0x22222200
    movt    r1, #0x2222
    str     r1, [r0, #PIO_PD_CFG2]              // PD18-PD23 to M2

.verify_PIO_PD_CFG2:
    ldr     r3, [r0, #PIO_PD_CFG2]
    cmp     r3, r1
    bne     .verify_PIO_PD_CFG2
        
    ldr     r0, =PIO_BASE
    ldr     r1, [r0, #PIO_PD_CFG3]
    mov     r2, #0
    movw    r2, #0xFFFF
    bic     r1, r1, r2
    movw    r2, #0x2222                     //ldr r2, =0x2222
    orr     r1, r1, r2                      // PD24-PD27 to M2
    str     r1, [r0, #PIO_PD_CFG3]

.verify_PIO_PD_CFG3:
    mov     r2, #0
    movw    r2, #0xFFFF
    and     r1, r1, r2                    // isolate (mask) bits [0-15]
    ldr     r3, [r0, #PIO_PD_CFG3]
    and     r3, r3, r2
    cmp     r3, r1
    bne     .verify_PIO_PD_CFG3
        
    pop     {r0-r5, pc}
    .ltorg

// ========================================================================
// LCD_Mode_Set
// set mode of LCD
// ========================================================================
LCD_Mode_Set:
    push    {r0-r5, lr}

    mov     r2, #1                                                   // Enable
    bl      TCON_ENABLE_DISABLE

    mov     r2, #30                                                 //(delay = vfp+vspw+vbp = 570) & max delay = 30
    bl      TCON_STATE_DELAY

    mov     r2, #1                                                  //Enable
    bl      TCON_OPEN_CLOSE_CONTROLLER


    mov     r2, #0x8                                                // Has to be 8 (m + 1) cause (8 + 1) = 9 cause 297mhz / 9 = 33 mhz
    bl      TCON_DCLK_DIV                                           // if you notice flickering at start you can go to 6 untill 4
    
    bl      TCON_Configure_Panel_Resolution
    
    bl      TCON_Configure_Horizontal_Timing

    bl      TCON_Configure_Vertical_Timing

    bl      TCON_Configure_HSYNC_PW_And_VSYNC_PW

    mov     r2, #0                                      //Enable 0's:Enable
    bl      TCON_IO_TRI_ENABLE_DISABLE
    
    pop     {r0-r5, pc}
    .ltorg


// ========================================================================
// DE_BE_Layer_Set_Format
// Set RGB 32bit Format for DEBE
//Input:
//r2 = 0xA(10) bpp_code => 32 bit color (0b1010)
//r3 = 0 RGB_Swap 0 = rgb 1 = bgr
//r4 = 0 LAY_FBPS Pixels Sequence
//     (For 32bitBbp: 0b00/0b01 (0/1) = ARGB (Default)
//     0b10/0b11 (2/3) = AGBR
//     See “Pixels Sequence” table
// ========================================================================
DE_BE_Layer_Set_Format:
    push    {r0-r5, lr}
    
    // DEBE_ATTCTL0_REG1 (0x8A0) - Layer 0 Set framebuffer format to ARGB8888 (0xA)
    //writel(SUNXI_DE_BE_LAYER_ATTR1_FMT_XRGB8888, &de_be->layer0_attr1_ctrl)// DEBE_ATTCTL0_REG1
    ldr     r0, =DEBE_BASE
    ldr     r1, [r0, #DEBE_ATTCTL0_REG1]
    bfc     r0, #0, #12                     // r0 = Clear bits field [0 to 11] = bic r1, r1, #(0xFFF << 0)
                                            // BFC S, E bit Field Clear start, size
    orr     r1, r1, r4, lsl #0              // Set bits [0-1] LAY_FBPS PS Pixels Sequence
                                            // For 32bitBbp:
                                            // 0b00/0b01 (0/1) = ARGB (Default)
                                            // 0b10/0b11 (2/3) = AGBR
                                            // See “Pixels Sequence” table
    orr     r1, r1, r3, lsl #2              // Clear bit [2] LAY_BRSWAPEN 0:RGB 1:BGR
    orr     r1, r1, r2, lsl #8              // Set bits [8-11] LAY_FBFMT 1001:32bit (Padding:8/R:8/G:8/B:8)
                                            // LAY_FBFMT
                                            // Frame buffer format
                                            // Normal mode data format
                                            // 0000: mono 1-bpp
                                            // 0001: mono 2-bpp
                                            // 0010: mono 4-bpp
                                            // 0011: mono 8-bpp
                                            // 0100: color 16-bpp (R:6/G:5/B:5)
                                            // 0101: color 16-bpp (R:5/G:6/B:5)
                                            // 0110: color 16-bpp (R:5/G:5/B:6)
                                            // 0111: color 16-bpp (Alpha:1/R:5/G:5/B:5)
                                            // 1000: color 16-bpp (R:5/G:5/B:5/Alpha:1)
                                            // 1001: color 24-bpp (Padding:8/R:8/G:8/B:8)
                                            // 1010: color 32-bpp (Alpha:8/R:8/G:8/B:8) <<<<----
                                            // 1011: color 24-bpp (R:8/G:8/B:8)
                                            // 1100: color 16-bpp (Alpha:4/R:4/G:4/B:4)
                                            // 1101: color 16-bpp (R:4/G:4/B:4/Alpha:4)
                                            // Other: Reserved
    str     r1, [r0, #DEBE_ATTCTL0_REG1]

.verify_ATTCTL0:
    ldr     r3, [r0, #DEBE_ATTCTL0_REG1]    @ read back
    mov     r2, #0
    movw    r2, #0xFFF
    and     r3, r3, r2                      // isolate bits [0-11]
    and     r1, r1, r2                      // isolate bits [0-11]
    cmp     r3, r1
    bne     .verify_ATTCTL0                 @ if zero loop

    pop     {r0-r5, pc}
    .ltorg
//End of function DE_BE_Layer_Set_Format


// ========================================================================
// SET_GFX_ADDRESS_TO_DEBE
// Set HI And Lo Address of DEBE
// ========================================================================
SET_GFX_ADDRESS_TO_DEBE:
    push    {r0-r5, lr}
    
    // DEBE_LAYFB_L32ADD_REG0 (0x850) - Layer 0 Set framebuffer address lower 32bits
    //writel(address << 3, &de_be->layer0_addr_low32b)//
    ldr     r0, =DEBE_BASE
    ldr     r1, =FRAMEBUFFER_BASE            // Frame Buffer Address (0x42000000)
    lsl     r1, r1, #3                       // remove bits [29-31]
    str     r1, [r0, #DEBE_LAYFB_L32ADD_REG0]

.verify_DEBE_LAYFB_L32ADD:
    ldr     r3, [r0, #DEBE_LAYFB_L32ADD_REG0]             @ read back
    cmp     r3, r1                                  @ test LAY0_EN (bit 8)
    bne     .verify_DEBE_LAYFB_L32ADD                    @ if not equal

    // DEBE_LAYFB_H4ADD_REG (0x860) - Layer 0 Set framebuffer address high 4bits
    //writel(address >> 29, &de_be->layer0_addr_high4b)//
    ldr     r0, =DEBE_BASE
    ldr     r1, =FRAMEBUFFER_BASE             // Frame Buffer Address (0x42000000)
    mov     r3, r1, lsr #29                   @ high4 = addr >> 29 (bits [31:28] -> bits [3:0])
    and     r3, r3, #0xF                      @ mask only lowest 4 bits[0-3]

    //---->>expermental<<----
    //mov r0, #0x0                          @ >>expermental<< manually force Lay0 nibble to Zero as per android system re
    //mov r3, r0,asr#29                     @ >>expermental<< manually force Lay0 nibble to Zero as per android system re
    //---->>expermental<<----

    ldr     r4, [r0, #DEBE_LAYFB_H4ADD_REG]
    bic     r4, r4, #0xFF                     @ clear LAY0 nibble (bits[3:0] plus unused bits[4-7])
    orr     r4, r4, r3                        @ set LAY0 nibble
    str     r4, [r0, #DEBE_LAYFB_H4ADD_REG]

.verify_DEBE_LAYFB_H4ADD:
    ldr     r3, [r0, #DEBE_LAYFB_H4ADD_REG]             @ read back
    and     r3, r3, #0xF                                // isolate bits [0-3]
    and     r4, r4, #0xF                                // isolate bits [0-3]
    cmp     r3, r4                                      @ test LAY0 nibble bits [0-3]
    bne     .verify_DEBE_LAYFB_H4ADD                    @ if not equal

    pop     {r0-r5, pc}
    .ltorg
//End of function SET_GFX_ADDRESS_TO_DEBE


// ========================================================================
// SET_GFX_LINE_WIDTH_IN_BITS
// Set line width in bits for the DEBE
// ========================================================================
SET_GFX_LINE_WIDTH_IN_BITS:
    push    {r0-r5, lr}

    // DEBE_LAYLINEWIDTH_REG (0x840) - Layer 0 (line width in bits (not bytes) lcd_x * 32 aka lcd_x * (4 * 8)
    //writel(SUNXI_DE_BE_LAYER_STRIDE(mode->xres), &de_be->layer0_stride)// DEBE_LAYLINEWIDTH_REG0
    ldr     r0, =DEBE_BASE
    ldr     r1, =lcd_x
    lsl     r1, r1, #5                                  //its like multiply it by 32 aka (2⁵) to get line width in bits (not bytes)
    str     r1, [r0, #DEBE_LAYLINEWIDTH_REG0]

.verify_DEBE_LAYLINEWIDTH:
    ldr     r3, [r0, #DEBE_LAYLINEWIDTH_REG0]            @ read back
    cmp     r3, r1                                       @ test LAY0_EN (bit 8)
    bne     .verify_DEBE_LAYLINEWIDTH                    @ if not equal

    pop     {r0-r5, pc}
    .ltorg
//End of function SET_GFX_LINE_WIDTH_IN_BITS


// ========================================================================
// DEBE_Set_Alpha
// Set Alpha Percentage for the DEBE
//  Input:
//  r2 = Alpha Percentage 0x00: Full Transparent 0xFF: Full Opaque
// ========================================================================
DEBE_Set_Alpha:
    push    {r0-r5, lr}

    ldr     r0, =DEBE_BASE
    ldr     r1, [r0, #DEBE_ATTCTL0_REG0]             // read
    bfi     r1, r2, #0x18, #8                        // set bit[24-31] LAY_GLBALPHA from r2 = 0xFF
                                                     // Bit Field Insert
                                                     // Copy from bit[0] at r2 to bit[24(0x18)] at r0 with width 8 bits
    str     r1, [r0, #DEBE_ATTCTL0_REG0]             // Store (0,0)

.verify_DEBE_Alpha:
    ldr     r3, [r0, #DEBE_ATTCTL0_REG0]             @ read back
    cmp     r3, r1                                   @ test LAY0_EN (bit 8)
    bne     .verify_DEBE_Alpha                       @ if not equal

    pop     {r0-r5, pc}
    .ltorg
//End of function DEBE_Set_Alpha


// ========================================================================
// DEBE_Set_Screen_Win
// a) SET_DE_LAYER_COORDINATES
// Sets Zero Start Point Coordinates X = 0 & Y = 0 for the DEBE
// b) SET_DE_LAYER_SIZE
// Sets FUll Screen As Desired Window Width & Height
// ========================================================================
DEBE_Set_Screen_Win:
    push    {r0-r5, lr}

//----- a) SET_DE_LAYER_COORDINATES ----
    ldr     r0, =DEBE_BASE
    movw    r1, #0                                  // Set X Upper Left Coordinate At LSB bits[[0-15]
    movt    r1, #0                                  // Set Y Upper Left Coordinate At MSB bits[[16-31]
    str     r1, [r0, #DEBE_LAYCOOR_REG0]            // Store (0,0)

.verify_DEBE_LAYCOOR:
    ldr     r3, [r0, #DEBE_LAYCOOR_REG0]            @ read back
    cmp     r3, r1                                  @ test LAY0_EN (bit 8)
    bne     .verify_DEBE_LAYCOOR                    @ if not equal

//----- b) SET_DE_LAYER_SIZE ----
    ldr     r0, =DEBE_BASE
    movw    r1, #(lcd_x - 1)                            // Set bits[0-12] X resolution
    movt    r1, #(lcd_y - 1)                            // Set bits[16-28] Y resolution
    str     r1, [r0, #DEBE_LAYSIZE_REG0]

.verify_DEBE_LAYSIZE:
    ldr     r3, [r0, #DEBE_LAYSIZE_REG0]            @ read back
    cmp     r3, r1                                  @ test LAY0_EN (bit 8)
    bne     .verify_DEBE_LAYSIZE                    @ if not equal

    pop     {r0-r5, pc}
    .ltorg
//End of function DEBE_Set_Screen_Win

// ========================================================================
// DEBE_Set_Full_Resolution
// Set Resolution for the DEBE
// ========================================================================
DEBE_Set_Full_Resolution:
    push    {r0-r5, lr}

    ldr     r0, =DEBE_BASE
    movw    r1, #(lcd_x - 1)                            // Set bits[0-15] X resolution
    movt    r1, #(lcd_y - 1)                            // Set bits[16-31] Y resolution
    str     r1, [r0, #DEBE_DISSIZE_REG]

.verify_DEBE_DISSIZE:
    ldr     r3, [r0, #DEBE_DISSIZE_REG]             @ read back
    cmp     r3, r1                                  @ test LAY0_EN (bit 8)
    bne     .verify_DEBE_DISSIZE                    @ if not equal

    pop     {r0-r5, pc}
    .ltorg
//End of function DEBE_Set_Alpha

// ========================================================================
// DEBE_Enable_Layer_0
// Set Layer for the DEBE
// ========================================================================
DEBE_Enable_Layer_0:
    push    {r0-r5, lr}

    ldr     r0, =DEBE_BASE
    ldr     r1, [r0, #DEBE_MODCTL_REG]
    orr     r1, r1, #(0b1 << 8)                 // Set bit [8] (LAY0_EN) 0:Disable 1:Enable
    str     r1, [r0, #DEBE_MODCTL_REG]

.verify_LAY0_EN:
    ldr     r3, [r0, #DEBE_MODCTL_REG]      @ read back
    tst     r3, #(1 << 8)                   @ test LAY0_EN (bit 8)
    beq     .verify_LAY0_EN                    @ if zero loop

    pop     {r0-r5, pc}
    .ltorg
//End of function DEBE_Set_Alpha

// ========================================================================
// TCON_STATE_DELAY
// CONTROLLER State Delat
// r2 = Delay 0-30 (delay = vfp+vspw+vbp = 570) & max delay = 30
// ========================================================================
TCON_STATE_DELAY:
    push {r0-r5, lr}

    ldr     r0, =TCON_BASE
    ldr     r1, [r0, #TCON0_CTL_REG]
    bic     r1, r1, #(0b11111 <<4)              // clear bits [4-8]
    orr     r1, r1, #(30 << 4)                  // 1- Set bits [4-8] STA delay =30 (delay = vfp+vspw+vbp = 570) & max delay = 30
    str     r1, [r0, #TCON0_CTL_REG]
   
.verify_LCD_STATE:
    ldr     r3, [r0, #TCON0_CTL_REG]
    cmp     r3, r1
    bne     .verify_LCD_STATE

    pop     {r0-r5, pc}
    .ltorg
//End of function TCON_STATE_DELAY

// ========================================================================
// TCON_DCLK_DIV
// TCON DCLK ON/OFF
// r2 = DIV Value 1 - 127 DCLKDIV >=4
// ========================================================================
TCON_DCLK_DIV:
    push {r0-r5, lr}

    ldr     r0, =TCON_BASE
    ldr     r1, [r0, #TCON0_DCLK_REG]
    bic     r1, r1, #(0b1111111 << 0)                   // Clear bits [0-6]
    orr     r1, r1, r2                                  // Set bits [0-6] DCLK_Div m=9 297/9 = 33MHZ
                                                        // Tdclk = Tsclk * DCLKDIV aka tsclk  = tdclk / DCLKDIV
                                                        // 1.if dclk1&dclk2 used，DCLKDIV >=6
                                                        // 2.if dclk only，DCLKDIV >=4
    str     r1, [r0, #TCON0_DCLK_REG]

.verify_LCD_DCLK_DIV:
    ldr     r3, [r0, #TCON0_DCLK_REG]
    cmp     r3, r1
    bne     .verify_LCD_DCLK_DIV

    pop     {r0-r5, pc}
    .ltorg
//End of function TCON_DCLK_DIV

// ========================================================================
// TCON_Configure_Panel_Resolution
// TCON Panel Resolution Setup
// ========================================================================
TCON_Configure_Panel_Resolution:
    push {r0-r5, lr}

    // ---- 3c: Configure Panel Resolution (TCON0_BASIC0_REG)
    ldr     r0, =TCON_BASE                              // Notice Here the X And Y Is Flipped THan the position In DE BE
    mov     r3, #lcd_y                                  // Set bits[0-10] Y resolution
    sub     r3, r3, #1
    mov     r1, #lcd_x                                  // Set bits[16-26] X resolution
    sub     r1, r1, #1
    orr     r3, r3, r1,lsl #16
    str     r3, [r0, #TCON0_BASIC0_REG]

.verify_TCON_BASIC0:
    ldr     r4, [r0, #TCON0_BASIC0_REG]
    cmp     r4, r3
    bne     .verify_TCON_BASIC0

    pop     {r0-r5, pc}
    .ltorg
//End of function TCON_Configure_Panel_Resolution

// ========================================================================
// TCON_Configure_Horizontal_Timing
// TCON Horizontal Timing Setup
// ========================================================================
TCON_Configure_Horizontal_Timing:
    push {r0-r5, lr}

    // ---- 3d: Configure Horizontal Timing (TCON0_BASIC1_REG)
    ldr     r0, =TCON_BASE
    mov     r3, #lcd_hbp                                // Can Be Any value, default is (hbp - 1) can be also (hspw + hbp) - 1
    sub     r3, r3, #1
    mov     r1, #lcd_ht                                 // **** Has to be (ht - 1) This is the Most Important to see anything on screen
    sub     r1, r1, #1
    orr     r3, r3, r1,lsl #16
    str     r3, [r0, #TCON0_BASIC1_REG]

.verify_TCON_BASIC1:
    ldr     r4, [r0, #TCON0_BASIC1_REG]
    cmp     r4, r3
    bne     .verify_TCON_BASIC1

    pop     {r0-r5, pc}
    .ltorg
//End of function TCON_Configure_Horizontal_Timing

// ========================================================================
// TCON_Configure_Vertical_Timing
// TCON Vertical Timing Setup
// ========================================================================
TCON_Configure_Vertical_Timing:
    push {r0-r5, lr}

    // ---- 3e: Configure Vertical Timing (TCON0_BASIC2_REG)
    ldr     r0, =TCON_BASE
    mov     r3, #lcd_vbp                                // Can Be Any value, default is (vbp - 1) can be also (vspw + vbp) - 1
    sub     r3, r3, #1
    mov     r1, #lcd_vt                                 // Can Be Any value, default is (vt - 1) can be also (vt * 2) - 1
    sub     r1, r1, #1
    orr     r3, r3, r1,lsl #16
    str     r3, [r0, #TCON0_BASIC2_REG]

.verify_TCON_BASIC2:
    ldr     r4, [r0, #TCON0_BASIC2_REG]
    cmp     r4, r3
    bne     .verify_TCON_BASIC2

    pop     {r0-r5, pc}
    .ltorg
//End of function TCON_Configure_Vertical_Timing

// ========================================================================
// TCON_Configure_HSYNC_PW_And_VSYNC_PW
// TCON HSYNC_PW And VSYNC_PW Setup
// ========================================================================
TCON_Configure_HSYNC_PW_And_VSYNC_PW:
    push {r0-r5, lr}

    // ---- 3f: Configure HSYNC_PW and VSYNC_PW (TCON0_BASIC3_REG)
    ldr     r0, =TCON_BASE
    mov     r3, #lcd_hv_vspw                            // Can Be Any value, default is (vspw - 1)
    sub     r3, r3, #1
    mov     r1, #lcd_hv_hspw                            // Can Be Any value, default is (hspw - 1)
    sub     r1, r1, #1
    orr     r3, r3, r1,lsl #16
    str     r3, [r0, #TCON0_BASIC3_REG]

.verify_TCON_BASIC3:
    ldr     r4, [r0, #TCON0_BASIC3_REG]
    cmp     r4, r3
    bne     .verify_TCON_BASIC3

    pop     {r0-r5, pc}
    .ltorg
//End of function TCON_Configure_HSYNC_PW_And_VSYNC_PW


//###############################################################################################################
//########################################## Power Management Functions #########################################
//###############################################################################################################

//========================================================================
// Turn LCD Back Light On
//========================================================================
BCK_L_ON:
    push    {r0-r7, lr}
    
    // --- Step 0: Turn On AXP209_GPIO1_REG Using bit Bangibg Method ---
    // Notice: Using only this Step would turn on the backlight but to control its intensity you would need Step 2 - 4
    // Using PB0 as SCL Clock & PB1 as SDA Data with M2 and M1
    // You Have to remember we use the open Drain When Set those pins to 1 And thats by just turn it into input pins
    // in Open drain when the Pins released or assigned as input the pull resistor pulls the pins signal to high
    // so when you test it using avometer you would find it 1 even it is input and this is useful also to get ACK
    // back from the AXP209 after sending each byte to make sure of correct sending.
    
    bl      AXP209_Send_START_Via_TWI0            // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite          // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =AXP209_GPIO1_REG   // Send GPIO1 Register Address to send data to it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    mov     r6, #0x1                // Send Data to GPIO1 Register Address to set the pin GPIO1 (BK_LT) to 1 (allow BK_LT)
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal            // Stop Signal
    

    pop     {r0-r7, pc}
    .ltorg
//========================================================================
// Control LCD Back Light
// Input: r0 = brigtness (0-10)  0 = 100%, 5 = 50%, 10 = 0%
//========================================================================

BCK_L_CTRL:
    push    {r0-r7, lr}
    
    // --- Step 1: Control the brightness using PWM -----

    // ---- 1a: Configure PB2 (M2) for PWM -----
    // The GPIO controller must be set to route the PWM signal to pin PB2.
    // In the A13 manual (v1.5), this is done by setting M2 mode.
    // M2 for PB2 requires setting bits [8:10] in the PB_CFG0 register.
    // The value for M2 is typically 0b0010 (2).
    ldr     r3, =PIO_BASE
    ldr     r1, [r3, #PIO_PB_CFG0]
    bic     r1, r1, #(0b111 << 8)           // Clear bits [8:10]
    orr     r1, r1, #(0b010 << 8)           // Set bits [8:10] M2 (PWM) mode 2:(0b010)
    str     r1, [r3, #PIO_PB_CFG0]

    // ---- 1b: Configure PWM Channel 0 ---
    
    // ------ 1b.1: Set the period and duty cycle registers.
    // PWM_Output_Freq = PWM_Input_Freq ÷ PWM_Prescaler ÷ PWM_Period
    // 10,000 = 24,000,000 ÷ 240 ÷ 10
    // Let's use a period of 10 and a duty cycle of 5 for 50% brightness.
    // Alsoo Notice that PWM_DUTY_CYCLE is inverted 0: 100% brightness 10: 0% brightness (max duty = period)
    // and why it is inverted because this board has inverted pwm polarity as in script.fex lcd_pwm_pol = 1
    ldr     r3, =PWM_BASE
    ldr     r1, [r3, #PWM_CH0_PERIOD_ACTIVE_REG]
    bic     r1, r1, #0xFFFFFFFF         // Clear all bits
    orr     r1, r1, r0      //#(5 << 0) // Set Bits [0:15] PWM_Duty_Cycle 5 is half the PWM_Period so 50% brightness
    orr     r1, r1, #(10 << 16)         // Set Bits [16:31] PWM_Period
    str     r1, [r3, #PWM_CH0_PERIOD_ACTIVE_REG]

    // ------ 1b.2: Enable PWM output
    // In the PWM_CTRL register (p. 84):
    // Bit 9 enables the bypass (use OSC24MHz as source).
    // Bit 4 enables PWM0.
    // Bits [3:0] are for the pre-scalar. We wont reach 10,000
    ldr     r3, =PWM_BASE
    ldr     r1, [r3, #PWM_CTRL]
    bic     r1, r1, #(0b0010 << 0)      // Set pre-scalar bits [0:3] to reach the pwm freq 10,000
                                        //PWM_CH0_PRESCAL.
                                        //PWM Channel 0 Prescalar.
                                        //These bits should be setting before the PWM Channel 0 clock gate on.
                                        //0000: /120
                                        //0001: /180
                                        //0010: /240   <<<----- lcd_pwm_freq = 10,000
                                        //0011: /360
                                        //0100: /480
                                        //0101: /
                                        //0110: /
                                        //0111: /
                                        //1000: /12k
                                        //1001: /24k
                                        //1010: /36k
                                        //1011: /48k
                                        //1100: /72k
                                        //1101: /
    orr     r1, r1, #(0b1 << 4)         // Set bit[4] to enable PWM0
    orr     r1, r1, #(0b1 << 5)         // Set bit[5] PWM_CH0_ACT_STA 0 = low 1 = high
    orr     r1, r1, #(0b1 << 6)         // Set bit[6] SCLK_CH0_GATING Gating the Special Clock for PWM0 (0: mask, 1: pass)
    orr     r1, r1, #(0b0 << 7)         // Clear bit[7] PWM_CHANNEL0_MODE 0: cycle mode, 1: pulse mode
    orr     r1, r1, #(0b0 << 8)         // Clear bit [8] PWM_CH0_PUL_START 0: no effect, 1: output 1 pulse.
    orr     r1, r1, #(0b0 << 9)         // Clear bit [9] PWM0_BYPASS 0: disable 0:enable bypass mode (Output is 24mhz)
    orr     r1, r1, #(0b1 << 28)        // Clear bit [28] PWM0_RDY 0:PWM0 period register ready to write 1:PWM0 is busy
    str     r1, [r3, #PWM_CTRL]

    // --- PWM output is now active on PB2 ---

    pop     {r0-r7, pc}
    .ltorg

//========================================================================
// Turn LCD Back Light Off
//========================================================================
BCK_L_OFF:
    push    {r0-r7, lr}
    
    bl      AXP209_Send_START_Via_TWI0            // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite          // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =AXP209_GPIO1_REG   // Send GPIO1 Register Address to send data to it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    mov     r6, #0x0                // Send Data to GPIO1 Register Address to set the pin GPIO1 (BK_LT) to 0 (disable BK_LT)
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal            // Stop Signal

    pop     {r0-r7, pc}
    .ltorg
 
//========================================================================
// Turn LCD Power On
//========================================================================
LCD_PWR_ON:
    push    {r0-r7, lr}
    // --- Step 1: Turn On AXP209_GPIO1_REG Using bit Bangibg Method ---
    // Notice: Using only this Step would turn on the backlight but to control its intensity you would need Step 2 - 4
    // Using PB0 as SCL Clock & PB1 as SDA Data with M2 and M1
    // You Have to remember we use the open Drain When Set those pins to 1 And thats by just turn it into input pins
    // in Open drain when the Pins released or assigned as input the pull resistor pulls the pins signal to high
    // so when you test it using avometer you would find it 1 even it is input and this is useful also to get ACK
    // back from the AXP209 after sending each byte to make sure of correct sending.
    
    bl      AXP209_Send_START_Via_TWI0            // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite          // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =AXP209_GPIO0_REG   // Send GPIO1 Register Address to send data to it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    mov     r6, #0x1                // Send Data to GPIO1 Register Address to set the pin GPIO0 (LCD_PWR) to 1
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal            // Stop Signal

    pop     {r0-r7, pc}
    .ltorg
//========================================================================
// Turn LCD Power Off
//========================================================================
LCD_PWR_OFF:
    push    {r0-r7, lr}
    
    bl      AXP209_Send_START_Via_TWI0            // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite          // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =AXP209_GPIO0_REG   // Send GPIO1 Register Address to send data to it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    mov     r6, #0x0                // Send Data to GPIO1 Register Address to set the pin GPIO0 (LCD_PWR) to 0
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal            // Stop Signal

    pop     {r0-r7, pc}
    .ltorg
//========================================================================
// Turn Charging Battery LED Off
//========================================================================
LED_OFF:
    push    {r0-r7, lr}
    
    bl      AXP209_Send_START_Via_TWI0            // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite          // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =AXP209_SHUT_BATT_CHGLED_REG   // Send Register Address to send data to it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    mov     r1, #0x46               // #0b01000110 or 0x42 #0b01000010 This Is the Default Value of the Reg (refere to 10.13)
    orr     r1, r1, #(0b1 <<3)      // Set Bit [3] CHGLED Pin control 0:Auto 1:Manual (use this register to set it)
    bic     r1, r1, #(0b11 <<4)     // Clear Bits [4-5] remove any old values
    orr     r1, r1, #(0b00 <<4)     // Set Bits [4-5] CHGLED Pin function 00:OFF 01:Slow Flash 10:Fast Flash 11:ON
    mov     r6, r1                  // Send Data to GPIO1 Register Address to set the pin GPIO1 (BK_LT) to 1 (allow BK_LT)
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal            // Stop Signal
    
    pop     {r0-r7, pc}
    .ltorg


//========================================================================
// Turn Charging Battery LED On
//========================================================================
LED_ON:
    push    {r0-r7, lr}
    
    bl      AXP209_Send_START_Via_TWI0            // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite          // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =AXP209_SHUT_BATT_CHGLED_REG   // Send Register Address to send data to it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    mov     r1, #0x46               // #0b01000110 or 0x42 #0b01000010 This Is the Default Value of the Reg (refere to 10.13)
    orr     r1, r1, #(0b1 <<3)      // Set Bit [3] CHGLED Pin control 0:Auto 1:Manual (use this register to set it)
    bic     r1, r1, #(0b11 <<4)     // Clear Bits [4-5] remove any old values
    orr     r1, r1, #(0b11 <<4)     // Set Bits [4-5] CHGLED Pin function 00:OFF 01:Slow Flash 10:Fast Flash 11:ON
    mov     r6, r1                  // Send Data to GPIO1 Register Address to set the pin GPIO1 (BK_LT) to 1 (allow BK_LT)
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal            // Stop Signal
    
    pop     {r0-r7, pc}
    .ltorg


//========================================================================
// Make Charging Battery LED Slow Flashing 1hz
//========================================================================
LED_Slow_Flash:
    push    {r0-r7, lr}

    bl      AXP209_Send_START_Via_TWI0            // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite          // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =AXP209_SHUT_BATT_CHGLED_REG   // Send Register Address to send data to it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    mov     r1, #0x46               // #0b01000110 or 0x42 #0b01000010 This Is the Default Value of the Reg (refere to 10.13)
    orr     r1, r1, #(0b1 <<3)      // Set Bit [3] CHGLED Pin control 0:Auto 1:Manual (use this register to set it)
    bic     r1, r1, #(0b11 <<4)     // Clear Bits [4-5] remove any old values
    orr     r1, r1, #(0b01 <<4)     // Set Bits [4-5] CHGLED Pin function 00:OFF 01:Slow Flash 10:Fast Flash 11:ON
    mov     r6, r1                  // Send Data to GPIO1 Register Address to set the pin GPIO1 (BK_LT) to 1 (allow BK_LT)
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal            // Stop Signal
    
    pop     {r0-r7, pc}
    .ltorg


//========================================================================
// Make Charging Battery LED Fast Flashing 4hz
//========================================================================
LED_Fast_Flash:
    push    {r0-r7, lr}
    
    bl      AXP209_Send_START_Via_TWI0            // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite          // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =AXP209_SHUT_BATT_CHGLED_REG   // Send Register Address to send data to it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    mov     r1, #0x46               // #0b01000110 or 0x42 #0b01000010 This Is the Default Value of the Reg (refere to 10.13)
    orr     r1, r1, #(0b1 <<3)      // Set Bit [3] CHGLED Pin control 0:Auto 1:Manual (use this register to set it)
    bic     r1, r1, #(0b11 <<4)     // Clear Bits [4-5] remove any old values
    orr     r1, r1, #(0b10 <<4)     // Set Bits [4-5] CHGLED Pin function 00:OFF 01:Slow Flash 10:Fast Flash 11:ON
    mov     r6, r1                  // Send Data to GPIO1 Register Address to set the pin GPIO1 (BK_LT) to 1 (allow BK_LT)
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal            // Stop Signal
    
    pop     {r0-r7, pc}
    .ltorg


//========================================================================
// LED Automatically Controlled By The Charge
//========================================================================
LED_Release:
    push    {r0-r7, lr}
    
    bl      AXP209_Send_START_Via_TWI0            // Start Signal

    mov     r6, #0                               // State Write
    bl      AXP209_SendAddressReadWrite          // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =AXP209_SHUT_BATT_CHGLED_REG   // Send Register Address to send data to it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    mov     r1, #0x46               // #0b01000110 or 0x42 #0b01000010 This Is the Default Value of the Reg (refere to 10.13)
    bic     r1, r1, #(0b1 <<3)      // Set Bit [3] CHGLED Pin control 0:Auto 1:Manual (use this register to set it)
    bic     r1, r1, #(0b11 <<4)     // Clear Bits [4-5] remove any old values
    orr     r1, r1, #(0b00 <<4)     // Set Bits [4-5] CHGLED Pin function 00:OFF 01:Slow Flash 10:Fast Flash 11:ON
    mov     r6, r1                  // Send Data to GPIO1 Register Address to set the pin GPIO1 (BK_LT) to 1 (allow BK_LT)
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal            // Stop Signal
    
    pop     {r0-r7, pc}
    .ltorg

//========================================================================
// Read Power Switch
// Input:
// Output:
// r0 = Power Switch Condition
//      2: Released
//      3: Long Click
//========================================================================
PWR_SW_Long_Press_Read:
    push    {r1-r10, lr}

    bl      AXP209_Send_START_Via_TWI0         // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite         // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =IRQ_Status3                    // Send Register Address to Receive data From it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal             // Stop Signal

    bl      AXP209_Send_START_Via_TWI0          // Start Signal

    mov     r6, #1                             // State Read
    bl      AXP209_SendAddressReadWrite        // Send Address (make sure lsb [bit 0] is 0 for Writing and 1 for Reading)

    mov     r6, #0                              // Request Single Bytes
    bl      AXP209_Receive_Single_Byte_Data_Via_TWI0
    and     r7, r7, #0x3                       // make sure we get bits[0-7] only
    mov     r8, r7                              // Save
    
    bl      AXP209_Send_STOP_Signal            // Stop Signal

    mov     r0, r8
    
    pop     {r1-r10, pc}
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
    push    {r1-r10, lr}

    bl      AXP209_Send_START_Via_TWI0         // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite         // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =IRQ_Status5                    // Send Register Address to Receive data From it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal             // Stop Signal

    bl      AXP209_Send_START_Via_TWI0          // Start Signal

    mov     r6, #1                             // State Read
    bl      AXP209_SendAddressReadWrite        // Send Address (make sure lsb [bit 0] is 0 for Writing and 1 for Reading)

    mov     r6, #0                              // Request Single Bytes
    bl      AXP209_Receive_Single_Byte_Data_Via_TWI0
    and     r7, r7, #0x60                       // make sure we get bits[5-6] only
    lsr     r7, r7, #5
    mov     r8, r7                              // Save
    
    bl      AXP209_Send_STOP_Signal            // Stop Signal

    mov     r0, r8
    
    pop     {r1-r10, pc}
    .ltorg


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
// Read Battery Meter
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

    bl      AXP209_Send_START_Via_TWI0         // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite         // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =IRQ_Status2                    // Send Register Address to Receive data From it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal             // Stop Signal

    bl      AXP209_Send_START_Via_TWI0          // Start Signal

    mov     r6, #1                             // State Read
    bl      AXP209_SendAddressReadWrite        // Send Address (make sure lsb [bit 0] is 0 for Writing and 1 for Reading)

    mov     r6, #0                              // Request Single Bytes
    bl      AXP209_Receive_Single_Byte_Data_Via_TWI0
    and     r7, r7, #0xFF                       // make sure we get bits[0-7] only
    mov     r8, r7                              // Save
    
    bl      AXP209_Send_STOP_Signal            // Stop Signal

    mov     r0, r8
    
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

    bl      AXP209_Send_START_Via_TWI0         // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite         // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =AXP209_FUEL_GAUGE              // Send Register Address to Receive data From it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal             // Stop Signal

    bl      AXP209_Send_START_Via_TWI0          // Start Signal

    mov     r6, #1                             // State Read
    bl      AXP209_SendAddressReadWrite        // Send Address (make sure lsb [bit 0] is 0 for Writing and 1 for Reading)

    mov     r6, #0                              // Request Single Bytes
    bl      AXP209_Receive_Single_Byte_Data_Via_TWI0
    and     r7, r7, #0x7F                       // make sure we get bits[0-6] only
    mov     r8, r7                              // Save At bits[0-6] Percentage From 0-127
    
    bl      AXP209_Send_STOP_Signal            // Stop Signal

    mov     r0, r8

    pop     {r1-r10, pc}
    .ltorg

//========================================================================
// Read Battery Coulomb Meter In CHarging Mode
// Input:
// Output:
// r0 = Battery In Charge Meter Value (when connected to charger)
//========================================================================
Battery_Coulomb_CHRG_Read:
    push    {r1-r10, lr}
    
    mov     r8, #0
    
    // -- Get Byte0[0-7] --
    bl      AXP209_Send_START_Via_TWI0         // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite         // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =COULOMB_CHG_BAT_METER3        // Send Register Address to Receive data From it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal             // Stop Signal

    bl      AXP209_Send_START_Via_TWI0          // Start Signal

    mov     r6, #1                             // State Read
    bl      AXP209_SendAddressReadWrite        // Send Address (make sure lsb [bit 0] is 0 for Writing and 1 for Reading)

    mov     r6, #0                              // Request Single Bytes
    bl      AXP209_Receive_Single_Byte_Data_Via_TWI0
    and     r7, r7, #0xFF                       // make sure we get one byte only
    orr     r8, r7, r8                          // Save At bits[0-7]
    
    bl      AXP209_Send_STOP_Signal            // Stop Signal
    
    // -- Get Byte0[8-15] --
    bl      AXP209_Send_START_Via_TWI0         // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite         // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =COULOMB_CHG_BAT_METER2        // Send Register Address to Receive data From it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal             // Stop Signal

    bl      AXP209_Send_START_Via_TWI0          // Start Signal

    mov     r6, #1                             // State Read
    bl      AXP209_SendAddressReadWrite        // Send Address (make sure lsb [bit 0] is 0 for Writing and 1 for Reading)

    mov     r6, #0                              // Request Single Bytes
    bl      AXP209_Receive_Single_Byte_Data_Via_TWI0
    and     r7, r7, #0xFF                       // make sure we get one byte only
    lsl     r7, r7, #0x8
    orr     r8, r7, r8                          // Save At bits[8-15]
    
    bl      AXP209_Send_STOP_Signal            // Stop Signal
    
    // -- Get Byte0[15-23] --
    bl      AXP209_Send_START_Via_TWI0         // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite         // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =COULOMB_CHG_BAT_METER1        // Send Register Address to Receive data From it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal             // Stop Signal

    bl      AXP209_Send_START_Via_TWI0          // Start Signal

    mov     r6, #1                             // State Read
    bl      AXP209_SendAddressReadWrite        // Send Address (make sure lsb [bit 0] is 0 for Writing and 1 for Reading)

    mov     r6, #0                              // Request Single Bytes
    bl      AXP209_Receive_Single_Byte_Data_Via_TWI0
    and     r7, r7, #0xFF                       // make sure we get one byte only
    lsl     r7, r7, #16
    orr     r8, r7, r8                          // Save At bits[16-23]
    
    bl      AXP209_Send_STOP_Signal            // Stop Signal
    
    // -- Get Byte0[24-31] --
    bl      AXP209_Send_START_Via_TWI0         // Start Signal

    mov     r6, #0                              // State Write
    bl      AXP209_SendAddressReadWrite         // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =COULOMB_CHG_BAT_METER0        // Send Register Address to Receive data From it on next byte
    bl      AXP209_Send_Single_Byte_Data_Via_TWI0

    bl      AXP209_Send_STOP_Signal             // Stop Signal

    bl      AXP209_Send_START_Via_TWI0          // Start Signal

    mov     r6, #1                             // State Read
    bl      AXP209_SendAddressReadWrite        // Send Address (make sure lsb [bit 0] is 0 for Writing and 1 for Reading)

    mov     r6, #0                              // Request Single Bytes
    bl      AXP209_Receive_Single_Byte_Data_Via_TWI0
    and     r7, r7, #0xFF                       // make sure we get one byte only
    lsl     r7, r7, #24
    orr     r8, r7, r8                          // Save At bits[24-31]
    
    bl      AXP209_Send_STOP_Signal            // Stop Signal
    
    mov     r0, r8

    pop     {r1-r10, pc}
    .ltorg

 
//###############################################################################################################
//########################################## TWI0 Functions #####################################################
//###############################################################################################################

// =============== S U B R O U T I N E =======================================
// inputs:
// output:
// r0 = 0 success / -1 fail
// ===========================================================================
TWI0_Init:
    push    {lr}
    // just delay
    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #APB1_GATING_REG]  // r1 = load from APB1_GATING_REG
    and     r1, r1, #0xFFFFFFFF
    str     r1, [r0, #APB1_GATING_REG]

    mov     r0, #0x64                   // 100 ms
    bl      Delay_By_r0                 // r0 = Delay Value
                
    // TWI Gatting
    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #APB1_GATING_REG]  // r1 = load from APB1_GATING_REG
    orr     r1, r1, #(0b1 << 0)         // Set bit[0] TWI0_APB_GATING 0: mask, 1: pass
    str     r1, [r0, #APB1_GATING_REG]
                
    // Set PIO
    bl      Set_PIO_TWI0
 
    // Soft Reset TWI
    movw    r10, #0xFFFF                // r10 is the counter
                
    ldr     r0, =TWI0_BASE
    ldr     r1, [r0, #TWI_SRST]         // r1 = load from TWI_SRST
    orr     r1, r1, #(0b1 << 0)         // Set bit[0] soft_reset
    str     r1, [r0, #TWI_SRST]

.loopCheckResetObserved0:
    ldr     r0, =TWI0_BASE
    ldr     r1, [r0, #TWI_SRST]         // r1 = load from TWI_SRST
    cmp     r1, #0                      // reset register return to 0 when its observed
                                        // make sure the reset is done before proceed
    beq     .successTWI_SRST0
    mov     r3, r10                     // r3 = counter
    cmp     r3, #0                      // not 0 untill counter is done
    moveq   r3, #0                      // only execute if counter is done
    movne   r3, #1                      // r3 = 1
    uxtb    r3, r3                      // r3 = 1 unsigned extract lower byte
    sub     r10, r10, #1                // Counter -= 1
    cmp     r3, #0                      // loop untill counter became zero
    bne     .loopCheckResetObserved0

.successTWI_SRST0:
    cmp     r10, #0                     // if the counter equal zero so the reset not done
                                        // even after 0xFFFF (65535)loops so it fail
    bgt     .TWI_RST_Done0               // if the counter > 0 so it is successful
    mov     r3, #0xFFFFFFFF             // -1 fail
    b       .end0                        // r0 = 0 success TWI0 Init / r0 = -1 fail

.TWI_RST_Done0:

    bl      Setup_TWI0_Clock
                                        
    mov     r3, #0                      // r3 = 0 success /-1 fail

.end0:
    mov     r0, r3                      // r0 = 0 success TWI0 Init / r0 = -1 fail
    pop     {pc}
    .ltorg
// End of function TWI0_Init


// =============== S U B R O U T I N E =======================================
// input:
// output:
// ===========================================================================
Set_PIO_TWI0:
    //adjust PIO_PB_CFG0
    ldr     r0, =PIO_BASE
    ldr     r1, [r0, #PIO_PB_CFG0]
    mov     r3, #0x1C
    mvn     r3, r3                          // r3 = -0x1C = 0xFFFFFFE4
    and     r1, r1, r3                      // Clear bits[0-1] & [3,4] aka Clear PB0 (TWI0_SDA) and PB1 (TWI0_SCK)
    orr     r1, r1, #(0b010 << 0)           // Set bits[0-2]= 010: TWI0_SDA
    orr     r1, r1, #(0b010 << 4)           // Set bits[4-6]= 010: TWI0_SCK
    str     r1, [r0, #PIO_PB_CFG0]

    //adjust PB_PULL0
    ldr     r0, =PIO_BASE
    ldr     r1, [r0, #PIO_PB_PULL0]
    mov     r3,#0xB
    mvn     r3, r3                          // r3 = -0xB = 0xFFFFFFF5
    and     r1, r1, r3                      // Clear bits[1] & keep bits[0] 01 Pull Up for n = 0 (PB0) TWI0_SDA
                                            // Clear bits[3] & keep bits[2] 01 Pull Up for n = 1 (PB1) TWI0_SCK
    orr     r1, r1, #(0b0101 << 0)          // Set bits[0-1] 01 Pull Up for n = 0 (PB0) TWI0_SDA
                                            // Set bits[2-3] 01 Pull Up for n = 1 (PB1) TWI0_SCK
    str     r1, [r0, #PIO_PB_PULL0]

    bx      lr
// End of function Set_PIO_TWI0

// =============== S U B R O U T I N E =======================================
// input:
// output:
// ============================================================================
Setup_TWI0_Clock:
                
    ldr     r0, =TWI0_BASE
    mov     r1, #0x10                   // Set bit[4] from bits[3-6] CLK_M = 0b0010
    orr     r1, r1, #(0b1 << 0)         // set bit[0] from bits[0-2] CLK_N = 0b001
    str     r1, [r0,#TWI_CCR]           // store CLK_N = 1 and CLK_M = 2 to TWI_CCR
    mov     r1, #0x40                   // Set bit[6] BUS_EN bus enable
    str     r1, [r0,#TWI_CNTR]          // Store At TWI_CNTR Aka Bus enable
    mov     r1, #0                      // Set 0: No Data Byte to be written after read command
                                        // Data Byte follow Read Command Control
                                        // 0: No Data Byte to be written after read command
                                        // 1: 1 byte data to be written after read command
                                        // 2: 2 bytes data can be written after read command
                                        // 3: 3 bytes data can be written after read command
    str     r1, [r0,#TWI_EFR]           // store At TWI_EFR
    bx      lr
// End of function Setup_TWI_Registers


// =============== S U B R O U T I N E =======================================
// input:
// output:
// r0 = 0 => success
// ===========================================================================

AXP209_Send_START_Via_TWI0:
    mov     r10, #0xFFFF                //Counter
    ldr     r0, =TWI0_BASE
    ldr     r1, [r0, #TWI_SRST]         // r1 = load from TWI_SRST
    orr     r1, r1, #(0b1 << 0)         // Set bit[0] soft_reset
    str     r1, [r0, #TWI_SRST]

    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_SRST
    orr     r1, r1, #0x20               // set bit[5] M_STA Master Mode Start
                                        // this would transmit a START condition on the bus when the bus is free
    str     r1, [r0, #TWI_CNTR]


.loopCheckInterruptST:
    mov     r3, r10                     // r3 = 0x000FFFFF
    cmp     r3, #0                      // not zero untill last loop when var_8_counter became 0
    moveq   r3, #0                      // NX untill loop ended
    movne   r3, #1                      // r3 = 1
    uxtb    r3, r3                      // 1
    sub     r10, r10, #1                // r2 = 0x000FFFFE
    cmp     r3, #0                      // when loop done
    beq     .loop_doneST                // should not be zero if succesful otherwise it failes to start master mode
    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_SRST
    and     r1, r1, #8                  // check bit[3] INT_FLAG if its zero
    cmp     r1, #0                      // make sure inturrpt flag gets 1 to confirm entry
                                        // INT_FLAG is automatically set to ‘1’ when any of
                                        // 28 (out of the possible 29) states is entered
    beq     .loopCheckInterruptST       // r3 = 0x000FFFFF

.loop_doneST:
    cmp     r10, #0                     // should not be zero if succesful otherwise it failes to start master mode
    bgt     .CheckStateST
    mov     r3, #0xFFFFFFFF             // fail -1
    b       .doneST

.CheckStateST:
    ldr     r1, [r0, #TWI_STAT]         // r1 = load from TWI_STAT
    cmp     r1, #8                      // check for START condition transmitted
    beq     .success_START_sendST       // success Master mode Start
    mov     r3, #0xFFFFFFFF // fail
    b       .doneST
// ---------------------------------------------------------------------------

.success_START_sendST:
    mov     r3, #0                      // success Master mode Start

.doneST:
    mov     r0, r3
    bx      lr
// End of function AXP209_Send_START_Via_TWI0


// =============== S U B R O U T I N E =======================================
// input
// output
// r0 = 0 success -1 fail
// ===========================================================================
AXP209_SendAddressReadWrite:

    mov     r10, #0xFFFF                // r10 = 0x0000FFFF counter
                
    ldr     r0, =TWI0_BASE
    mov     r1, #AXP209_BASE            // Set byte to send
    orr     r1, r1, r6                  // Default is write (0) for read (1)
    str     r1, [r0, #TWI_DATA]

    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    and     r1, r1, #0xF7               // clear bit[3] INT_FLAG,  bits[8-31] Not Used
    str     r1, [r0, #TWI_CNTR]

.LoopNotObservedYetAD:
    mov     r3, r10                     // r3 = 0x000FFFFF
    cmp     r3, #0
    moveq   r3, #0                      // end loop
    movne   r3, #1                      // not end loop yet, keep check
    uxtb    r3, r3                      // r3 = r3
    sub     r10, r10, #1
    cmp     r3, #0                      // if end loop
    beq     .endLoopAD                  // the remaining of the counter after the observation
    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    and     r1, r1, #8                  // clear all except bit[3] Interrupt Flag
                                        // It would get 1 to indicate the data is accepted
    cmp     r1, #0                      // if its 0 so data not Observed Yet in the TWI0 register
    beq     .LoopNotObservedYetAD       // count 65535 loop to make sure of TWI0 Data Observation

.endLoopAD:
    cmp     r10, #0                     //  if its > 0 so observation done successfully
    bgt     .CheckStateAD
    mov     r3, #0xFFFFFFFF             // fail observation -1
    b       .endAD
// ---------------------------------------------------------------------------

.CheckStateAD:
    cmp     r6, #0                      // If its Write Mode Address
    bne     .readCheckStateAD
    ldr     r1, [r0, #TWI_STAT]         // r1 = load from TWI_CNTR
    cmp     r1, #0x18                   // Check for Address + Write bit transmitted, ACK received
    beq     .SuccessAddressReadWriteACK // success
    mov     r3, #0xFFFFFFFF             // else -1 fail writing
    b       .endAD

.readCheckStateAD:
    ldr     r1, [r0, #TWI_STAT]         // r1 = load from TWI_CNTR
    cmp     r1, #0x40                   // Check for Address + Read bit transmitted, ACK received
    beq     .SuccessAddressReadWriteACK // success
    mov     r3, #0xFFFFFFFF             // else -1 fail writing
    b       .endAD

.SuccessAddressReadWriteACK:
    mov     r3, #0                      // success
.endAD:
    mov     r0, r3
    bx      lr
// End of function AXP209_SendAddressReadWrite


// =============== S U B R O U T I N E =======================================
// input:
// r6 = Data Byte to be sent
// output:
// r0 = 0 if success
// ===========================================================================
AXP209_Send_Single_Byte_Data_Via_TWI0:

    mov     r10, #0xFFFF                // r10 = 0x0000FFFF counter
                
    ldr     r0, =TWI0_BASE
    and     r6, r6, #0xFF               // make sure it is byte
    str     r6, [r0, #TWI_DATA]         // Write Data to TWI_DATA
                
    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    and     r1, r1, #0xF7               // clear bit[3] INT_FLAG,  bits[8-31] Not Used
    str     r1, [r0, #TWI_CNTR]

.loopCheckInterruptFlagSS:
    mov     r3, r10                     // r3 = 0x000FFFFF
    cmp     r3, #0
    moveq   r3, #0                      // end loop
    movne   r3, #1                      // not end loop yet, keep check
    uxtb    r3, r3                      // r3 = r3
    sub     r10, r10, #1
    cmp     r3, #0                      // if end loop
    beq     .doneSS                     // the remaining of the counter after the observation
    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    and     r1, r1, #8                  // clear all except bit[3] Interrupt Flag
                                        // It would get 1 to indicate the data is accepted
    cmp     r1, #0                      // if its 0 so data not Observed Yet in the TWI0 register
    beq     .loopCheckInterruptFlagSS   // startCounter at 65535

.doneSS:
    cmp     r10, #0                     // make sure it is not zero or else not observed
    bgt     .checkStateSS
    mov     r3, #0xFFFFFFFF             // -1 fail not observed
    b       .endSS
.checkStateSS:
    ldr     r1, [r0, #TWI_STAT]         // r1 = load from TWI_CNTR
    cmp     r1, #0x28                   // Check for Data byte transmitted in master mode, ACK received
    beq     .success_Sending_Data       // success
    mov     r3, #0xFFFFFFFF             // else -1 fail writing
    b       .endSS
.success_Sending_Data:
    mov     r3, #0                      // success sending byte
.endSS:
    mov     r0, r3
    bx      lr
// End of function AXP209_Send_Single_Byte_Data_Via_TWI0

// =============== S U B R O U T I N E =======================================
// input:
// r6 = Last Byte To Recieve / More bytes to follow
//      0:Last Byte 1:More bytes to follow
// output:
// r0 = 0 if success
// r7 = Data Byte Received
// ===========================================================================
AXP209_Receive_Single_Byte_Data_Via_TWI0:

    mov     r10, #0xFFFF                // r10 = 0x0000FFFF counter

    ldr     r0, =TWI0_BASE
    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    and     r1, r1, #0xF3               // clear bit[2] A_ACK, bit[3] INT_FLAG, bits[8-31] Not Used
    lsl     r5, r6, #2                  // r5 = Set/Clear bit[2] using r6 for the orr next
    orr     r1, r1, r5                  // Set bit[2] A_ACK 0:last byte 1:More bytes to follow
    str     r1, [r0, #TWI_CNTR]

.loopCheckInterruptFlagSR0:
    mov     r3, r10                     // r3 = 0x000FFFFF
    cmp     r3, #0
    moveq   r3, #0                      // end loop
    movne   r3, #1                      // not end loop yet, keep check
    uxtb    r3, r3                      // r3 = r3
    sub     r10, r10, #1
    cmp     r3, #0                      // if end loop
    beq     .doneSR0                    // the remaining of the counter after the observation
    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    and     r1, r1, #8                  // clear all except bit[3] Interrupt Flag
                                        // It would get 1 to indicate the data is accepted
    cmp     r1, #0                      // if its 0 so data not Observed Yet in the TWI0 register
    beq     .loopCheckInterruptFlagSR0  // startCounter at 65535

.doneSR0:
    cmp     r10, #0                     // make sure it is not zero or else not observed
    bgt     .successDataObservationSR0
    mov     r3, #0xFFFFFFFF             // -1 fail not observed
    b       .endSR0
    
.successDataObservationSR0:
    mov     r10, #0                     // counter = 00
    b       .contSR0
    
.loopDelay63CyclesSR0:
    add     r10, r10, #1

.contSR0:
    cmp     r10, #0x63          // check if counter reach 0x63 99 bytes
    ble     .loopDelay63CyclesSR0
    
    ldr     r3, [r0, #TWI_DATA]         // r3 = get [TWI_DATA]
    uxtb    r7, r3                      // r6 = Received DATA (Make Sure its one byte only)

    cmp     r6, #0
    bne     .checkStateOfMoreBytesFollow0
    
.checkStateOfLastByte0:
    ldr     r3, [r0, #TWI_STAT]         // r3 = get [TWI_STAT]
    cmp     r3, #0x58                   // Check for Data byte received in master mode, not ACK transmitted
    bne     .checkStateOfLastByte0      // success
    b       .success_Receiving_Data0

.checkStateOfMoreBytesFollow0:
    ldr     r3, [r0, #TWI_STAT]         // r3 = get [TWI_STAT]
    cmp     r3, #0x50                   // Check for Data byte received in master mode, ACK transmitted
    bne     .checkStateOfMoreBytesFollow0    // success

.success_Receiving_Data0:
    mov     r3, #0                      // success sending byte

.endSR0:
    mov     r0, r3
    bx      lr
// End of function AXP209_Receive_Single_Byte_Data_Via_TWI1

// =============== S U B R O U T I N E =======================================
// input:
// output:
// r0: 0 for success
// ===========================================================================
AXP209_Send_STOP_Signal:

    mov     r10, #0xFFFF                // Counter
                
    ldr     r0, =TWI0_BASE
    ldr     r1, [r0,#TWI_CNTR]          // get [TWI_CNTR]
    and     r1, r1, #0xC0               // clear All except bits[6] BUS_EN and [7] INT_EN
    orr     r1, r1, #0x10               // Set bit[4] M_STP Send Stop Signal in Master Mode
    str     r1, [r0,#TWI_CNTR]          // Store to [TWI_CNTR] aka send Stop signal in Master Mode

.loopCheckMASTER_STOP:
    mov     r3, r10
    cmp     r3, #0
    moveq   r3, #0
    movne   r3, #1
    uxtb    r3, R3
    sub     r10, r10, #1
    cmp     r3, #0
    beq     .doneLoopMASTER_STOP_Check
    ldr     r1, [r0,#TWI_CNTR]          // get [TWI_CNTR]
    and     r1, r1, #0x10               // check bit[4] M_STP it should turn to zero if observed
    cmp     r1, #0
    bne     .loopCheckMASTER_STOP

.doneLoopMASTER_STOP_Check:
    cmp     r10, #0
    bgt     .success_Observation_M_STP
    mov     r3, #0xFFFFFFFF
    b       .endSTP
                
.success_Observation_M_STP:
    mov     r10, #0xFFFF

.loopCheckState:
    mov     r3, r10
    cmp     r3, #0
    moveq   r3, #0
    movne   r3, #1
    uxtb    r3, R3
    sub     r10, r10, #1
    cmp     r3, #0
    beq     .doneCheckState
    ldr     r1, [r0,#TWI_STAT]          // get [TWI_STAT]
    cmp     r1, #0xF8                   // check for No relevant status information, INT_FLAG=0
    bne     .loopCheckState

.doneCheckState:
    ldr     r1, [r0,#TWI_STAT]          // get [TWI_STAT]
    cmp     r1, #0xF8                   // again check for No relevant status information, INT_FLAG=0
    beq     .success_M_STP
    mov     r3, #0xFFFFFFFF
    b       .endSTP
// ---------------------------------------------------------------------------

.success_M_STP:
    mov             r3, #0
.endSTP:
    mov             r0, r3
    bx              lr
// End of function AXP209_Send_STOP_Signal


//###############################################################################################################
//########################################## TWI1 Functions #####################################################
//###############################################################################################################

// =============== S U B R O U T I N E =======================================
// inputs:
// output:
// r0 = 0 success / -1 fail
// ===========================================================================
TWI1_Init:
    push    {lr}
    // just delay
    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #APB1_GATING_REG]  // r1 = load from APB1_GATING_REG
    and     r1, r1, #0xFFFFFFFF
    str     r1, [r0, #APB1_GATING_REG]

    mov     r0, #0x64                   // 100 ms
    bl      Delay_By_r0                 // r0 = Delay Value
                
    // TWI Gatting
    ldr     r0, =CCM_BASE
    ldr     r1, [r0, #APB1_GATING_REG]  // r1 = load from APB1_GATING_REG
    orr     r1, r1, #(0b1 << 1)         // Set bit[1] TWI1_APB_GATING 0: mask, 1: pass
    str     r1, [r0, #APB1_GATING_REG]
                
    // Set PIO
    bl      Set_PIO_TWI1
 
    // Soft Reset TWI
    movw    r10, #0xFFFF                // r10 is the counter
                
    ldr     r0, =TWI1_BASE
    ldr     r1, [r0, #TWI_SRST]         // r1 = load from TWI_SRST
    orr     r1, r1, #(0b1 << 0)         // Set bit[0] soft_reset
    str     r1, [r0, #TWI_SRST]

.loopCheckResetObserved1:
    ldr     r0, =TWI1_BASE
    ldr     r1, [r0, #TWI_SRST]         // r1 = load from TWI_SRST
    cmp     r1, #0                      // reset register return to 0 when its observed
                                        // make sure the reset is done before proceed
    beq     .successTWI_SRST1
    mov     r3, r10                     // r3 = counter
    cmp     r3, #0                      // not 0 untill counter is done
    moveq   r3, #0                      // only execute if counter is done
    movne   r3, #1                      // r3 = 1
    uxtb    r3, r3                      // r3 = 1 unsigned extract lower byte
    sub     r10, r10, #1                // Counter -= 1
    cmp     r3, #0                      // loop untill counter became zero
    bne     .loopCheckResetObserved1

.successTWI_SRST1:
    cmp     r10, #0                     // if the counter equal zero so the reset not done
                                        // even after 0xFFFF (65535)loops so it fail
    bgt     .TWI_RST_Done1               // if the counter > 0 so it is successful
    mov     r3, #0xFFFFFFFF             // -1 fail
    b       .end1                        // r0 = 0 success TWI0 Init / r0 = -1 fail

.TWI_RST_Done1:

    bl      Setup_TWI1_Clock
                                        
    mov     r3, #0                      // r3 = 0 success /-1 fail

.end1:
    mov     r0, r3                      // r0 = 0 success TWI0 Init / r0 = -1 fail
    pop     {pc}
    .ltorg
// End of function TWI0_Init


// =============== S U B R O U T I N E =======================================
// input:
// output:
// ===========================================================================
Set_PIO_TWI1:
    //adjust PIO_PB_CFG0
    ldr     r0, =PIO_BASE
    ldr     r1, [r0, #PIO_PB_CFG1]
    bic     r1, r1, #(0b111 << 28)           // Clear bits[28-30] Clear PB15 (TWI1_SCK)
    orr     r1, r1, #(0b010 << 28)           // Set bits[2830]= 010: TWI1_SCK
    str     r1, [r0, #PIO_PB_CFG1]

    ldr     r0, =PIO_BASE
    ldr     r1, [r0, #PIO_PB_CFG2]
    bic     r1, r1, #(0b111 << 0)           // Clear bits[0-2] aka Clear PB16 (TWI1_SDA)
    orr     r1, r1, #(0b010 << 0)           // Set bits[0-2]= 010: TWI1_SDA
    str     r1, [r0, #PIO_PB_CFG2]

    //adjust PB_PULL0
    ldr     r0, =PIO_BASE
    ldr     r1, [r0, #PIO_PB_PULL0]
    bic     r1, r1, #(0b11 << 30)           // Clear bits[30-31] Pull Up for n = 15 (PB15) TWI1_SCK
    orr     r1, r1, #(0b01 << 30)           // Set bits[30-31] 01 Pull Up for n = 15 (PB15) TWI1_SCK
    str     r1, [r0, #PIO_PB_PULL0]

    ldr     r0, =PIO_BASE
    ldr     r1, [r0, #PIO_PB_PULL1]
    bic     r1, r1, #(0b11 << 0)            // Clear bits[0-1] Pull Up for n = 16 (PB16) TWI1_SCK
    orr     r1, r1, #(0b01 << 0)            // Set bits[0-1] 01 Pull Up for n = 16 (PB16) TWI1_SCK
    str     r1, [r0, #PIO_PB_PULL1]

    bx      lr
// End of function Set_PIO_TWI0

// =============== S U B R O U T I N E =======================================
// input:
// output:
// ============================================================================
Setup_TWI1_Clock:
                
    ldr     r0, =TWI1_BASE
    mov     r1, #0x10                   // Set bit[4] from bits[3-6] CLK_M = 0b0010  <----- Confirm M & N For TWI1--
    orr     r1, r1, #(0b1 << 0)         // set bit[0] from bits[0-2] CLK_N = 0b001 <----- Confirm M & N For TWI1--
    str     r1, [r0,#TWI_CCR]           // store CLK_N = 1 and CLK_M = 2 to TWI_CCR

    mov     r1, #0x40                   // Set bit[6] BUS_EN bus enable
    str     r1, [r0,#TWI_CNTR]          // Store At TWI_CNTR Aka Bus enable

    mov     r1, #0                      // Set 0: No Data Byte to be written after read command
                                        // Data Byte follow Read Command Control
                                        // 0: No Data Byte to be written after read command
                                        // 1: 1 byte data to be written after read command
                                        // 2: 2 bytes data can be written after read command
                                        // 3: 3 bytes data can be written after read command
    str     r1, [r0,#TWI_EFR]           // store At TWI_EFR
    bx      lr
// End of function Setup_TWI_Registers


// =============== S U B R O U T I N E =======================================
// input:
// output:
// r0 = 0 => success
// ===========================================================================

AT8563S_Send_START_Via_TWI1:
    mov     r10, #0xFFFF                //Counter
    ldr     r0, =TWI1_BASE
    ldr     r1, [r0, #TWI_SRST]         // r1 = load from TWI_SRST
    orr     r1, r1, #(0b1 << 0)         // Set bit[0] soft_reset
    str     r1, [r0, #TWI_SRST]

    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    orr     r1, r1, #0x20               // set bit[5] M_STA Master Mode Start
                                        // this would transmit a START condition on the bus when the bus is free
    str     r1, [r0, #TWI_CNTR]


.loopCheckInterruptST1:
    mov     r3, r10                     // r3 = 0x000FFFFF
    cmp     r3, #0                      // not zero untill last loop when var_8_counter became 0
    moveq   r3, #0                      // NX untill loop ended
    movne   r3, #1                      // r3 = 1
    uxtb    r3, r3                      // 1
    sub     r10, r10, #1                // r2 = 0x000FFFFE
    cmp     r3, #0                      // when loop done
    beq     .loop_doneST1               // should not be zero if succesful otherwise it failes to start master mode
    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_SRST
    and     r1, r1, #8                  // check bit[3] INT_FLAG if its zero
    cmp     r1, #0                      // make sure inturrpt flag gets 1 to confirm entry
                                        // INT_FLAG is automatically set to ‘1’ when any of
                                        // 28 (out of the possible 29) states is entered
    beq     .loopCheckInterruptST1      // r3 = 0x000FFFFF

.loop_doneST1:
    cmp     r10, #0                     // should not be zero if succesful otherwise it failes to start master mode
    bgt     .CheckStateST1
    mov     r3, #0xFFFFFFFF             // fail -1
    b       .doneST1

.CheckStateST1:
    ldr     r1, [r0, #TWI_STAT]         // r1 = load from TWI_STAT
    cmp     r1, #8                      // check for START condition transmitted
    beq     .success_START_sendST1      // success Master mode Start
    mov     r3, #0xFFFFFFFF // fail
    b       .doneST1
// ---------------------------------------------------------------------------

.success_START_sendST1:
    mov     r3, #0                      // success Master mode Start

.doneST1:
    mov     r0, r3
    bx      lr
// End of function AT8563S_Send_START_Via_TWI1


// =============== S U B R O U T I N E =======================================
// input
// r6 = Address Mode
//      0 for write 1 for read
// output
// r0 = 0 success -1 fail
// ===========================================================================
AT8563S_SendAddressReadWrite:

    mov     r10, #0xFFFF                // r10 = 0x0000FFFF counter
                
    ldr     r0, =TWI1_BASE
    mov     r1, #AT8563S_BASE            // Set byte to send
    orr     r1, r1, r6                  // Default is write (0xA2) for read (0xA3)
    str     r1, [r0, #TWI_DATA]

    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    and     r1, r1, #0xF7               // clear bit[3] INT_FLAG,  bits[8-31] Not Used
    str     r1, [r0, #TWI_CNTR]

.LoopNotObservedYetAD1:
    mov     r3, r10                     // r3 = 0x000FFFFF
    cmp     r3, #0
    moveq   r3, #0                      // end loop
    movne   r3, #1                      // not end loop yet, keep check
    uxtb    r3, r3                      // r3 = r3
    sub     r10, r10, #1
    cmp     r3, #0                      // if end loop
    beq     .endLoopAD1                  // the remaining of the counter after the observation
    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    and     r1, r1, #8                  // clear all except bit[3] Interrupt Flag
                                        // It would get 1 to indicate the data is accepted
    cmp     r1, #0                      // if its 0 so data not Observed Yet in the TWI0 register
    beq     .LoopNotObservedYetAD1      // count 65535 loop to make sure of TWI0 Data Observation

.endLoopAD1:
    cmp     r10, #0                     //  if its > 0 so observation done successfully
    bgt     .CheckStateAD1
    mov     r3, #0xFFFFFFFF             // fail observation -1
    b       .endAD1
// ---------------------------------------------------------------------------

.CheckStateAD1:
    cmp     r6, #0                      // If its Write Mode Address
    bne     .readCheckStateAD1
    ldr     r1, [r0, #TWI_STAT]         // r1 = load from TWI_CNTR
    cmp     r1, #0x18                   // Check for Address + Write bit transmitted, ACK received
    beq     .SuccessAddressReadWriteACK1 // success
    mov     r3, #0xFFFFFFFF             // else -1 fail writing
    b       .endAD1

.readCheckStateAD1:
    ldr     r1, [r0, #TWI_STAT]         // r1 = load from TWI_CNTR
    cmp     r1, #0x40                   // Check for Address + Read bit transmitted, ACK received
    beq     .SuccessAddressReadWriteACK1 // success
    mov     r3, #0xFFFFFFFF             // else -1 fail writing
    b       .endAD1

.SuccessAddressReadWriteACK1:
    mov     r3, #0                      // success
.endAD1:
    mov     r0, r3
    bx      lr
// End of function AT8563S_SendAddressReadWrite


// =============== S U B R O U T I N E =======================================
// input:
// r6 = Data Byte to be sent
// output:
// r0 = 0 if success
// ===========================================================================
AT8563S_Send_Single_Byte_Data_Via_TWI1:

    mov     r10, #0xFFFF                // r10 = 0x0000FFFF counter
                
    ldr     r0, =TWI1_BASE
    and     r6, r6, #0xFF               // make sure it is byte
    str     r6, [r0, #TWI_DATA]         // Write Data to TWI_DATA
                
    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    and     r1, r1, #0xF7               // clear bit[3] INT_FLAG,  bits[8-31] Not Used
    str     r1, [r0, #TWI_CNTR]

.loopCheckInterruptFlagSS1:
    mov     r3, r10                     // r3 = 0x000FFFFF
    cmp     r3, #0
    moveq   r3, #0                      // end loop
    movne   r3, #1                      // not end loop yet, keep check
    uxtb    r3, r3                      // r3 = r3
    sub     r10, r10, #1
    cmp     r3, #0                      // if end loop
    beq     .doneSS1                    // the remaining of the counter after the observation
    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    and     r1, r1, #8                  // clear all except bit[3] Interrupt Flag
                                        // It would get 1 to indicate the data is accepted
    cmp     r1, #0                      // if its 0 so data not Observed Yet in the TWI0 register
    beq     .loopCheckInterruptFlagSS1  // startCounter at 65535

.doneSS1:
    cmp     r10, #0                     // make sure it is not zero or else not observed
    bgt     .checkStateSS1
    mov     r3, #0xFFFFFFFF             // -1 fail not observed
    b       .endSS1
.checkStateSS1:
    ldr     r1, [r0, #TWI_STAT]         // r1 = load from TWI_CNTR
    cmp     r1, #0x28                   // Check for Data byte transmitted in master mode, ACK received
    beq     .success_Sending_Data1      // success
    mov     r3, #0xFFFFFFFF             // else -1 fail writing
    b       .endSS1
.success_Sending_Data1:
    mov     r3, #0                      // success sending byte
.endSS1:
    mov     r0, r3
    bx      lr
// End of function AT8563S_Send_Single_Byte_Data_Via_TWI1

// =============== S U B R O U T I N E =======================================
// input:
// r6 = Last Byte To Recieve / More bytes to follow
//      0:Last Byte 1:More bytes to follow
// output:
// r0 = 0 if success
// r7 = Data Byte Received
// ===========================================================================
AT8563S_Receive_Single_Byte_Data_Via_TWI1:

    mov     r10, #0xFFFF                // r10 = 0x0000FFFF counter

    ldr     r0, =TWI1_BASE
    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    and     r1, r1, #0xF3               // clear bit[2] A_ACK, bit[3] INT_FLAG, bits[8-31] Not Used
    lsl     r5, r6, #2                  // r5 = Set/Clear bit[2] using r6 for the orr next
    orr     r1, r1, r5                  // Set bit[2] A_ACK 0:last byte 1:More bytes to follow
    str     r1, [r0, #TWI_CNTR]

.loopCheckInterruptFlagSR1:
    mov     r3, r10                     // r3 = 0x000FFFFF
    cmp     r3, #0
    moveq   r3, #0                      // end loop
    movne   r3, #1                      // not end loop yet, keep check
    uxtb    r3, r3                      // r3 = r3
    sub     r10, r10, #1
    cmp     r3, #0                      // if end loop
    beq     .doneSR1                    // the remaining of the counter after the observation
    ldr     r1, [r0, #TWI_CNTR]         // r1 = load from TWI_CNTR
    and     r1, r1, #8                  // clear all except bit[3] Interrupt Flag
                                        // It would get 1 to indicate the data is accepted
    cmp     r1, #0                      // if its 0 so data not Observed Yet in the TWI0 register
    beq     .loopCheckInterruptFlagSR1  // startCounter at 65535

.doneSR1:
    cmp     r10, #0                     // make sure it is not zero or else not observed
    bgt     .successDataObservationSR1
    mov     r3, #0xFFFFFFFF             // -1 fail not observed
    b       .endSR1
    
.successDataObservationSR1:
    mov     r10, #0                     // counter = 00
    b       .contSR1
    
.loopDelay63CyclesSR1:
    add     r10, r10, #1

.contSR1:
    cmp     r10, #0x63          // check if counter reach 0x63 99 bytes
    ble     .loopDelay63CyclesSR1
    
    ldr     r3, [r0, #TWI_DATA]         // r3 = get [TWI_DATA]
    uxtb    r7, r3                      // r6 = Received DATA (Make Sure its one byte only)

    cmp     r6, #0
    bne     .checkStateOfMoreBytesFollow
    
.checkStateOfLastByte:
    ldr     r3, [r0, #TWI_STAT]         // r3 = get [TWI_STAT]
    cmp     r3, #0x58                   // Check for Data byte received in master mode, not ACK transmitted
    bne     .checkStateOfLastByte       // success
    b       .success_Receiving_Data1

.checkStateOfMoreBytesFollow:
    ldr     r3, [r0, #TWI_STAT]         // r3 = get [TWI_STAT]
    cmp     r3, #0x50                   // Check for Data byte received in master mode, ACK transmitted
    bne     .checkStateOfMoreBytesFollow    // success

.success_Receiving_Data1:
    mov     r3, #0                      // success sending byte

.endSR1:
    mov     r0, r3
    bx      lr
// End of function AT8563S_Receive_Single_Byte_Data_Via_TWI1


// =============== S U B R O U T I N E =======================================
// input:
// output:
// r0: 0 for success
// ===========================================================================
AT8563S_Send_STOP_Signal:

    mov     r10, #0xFFFF                // Counter
                
    ldr     r0, =TWI1_BASE
    ldr     r1, [r0,#TWI_CNTR]          // get [TWI_CNTR]
    and     r1, r1, #0xC0               // clear All except bits[6] BUS_EN and [7] INT_EN
    orr     r1, r1, #0x10               // Set bit[4] M_STP Send Stop Signal in Master Mode
    str     r1, [r0,#TWI_CNTR]          // Store to [TWI_CNTR] aka send Stop signal in Master Mode

.loopCheckMASTER_STOP1:
    mov     r3, r10
    cmp     r3, #0
    moveq   r3, #0
    movne   r3, #1
    uxtb    r3, R3
    sub     r10, r10, #1
    cmp     r3, #0
    beq     .doneLoopMASTER_STOP_Check1
    ldr     r1, [r0,#TWI_CNTR]          // get [TWI_CNTR]
    and     r1, r1, #0x10               // check bit[4] M_STP it should turn to zero if observed
    cmp     r1, #0
    bne     .loopCheckMASTER_STOP1

.doneLoopMASTER_STOP_Check1:
    cmp     r10, #0
    bgt     .success_Observation_M_STP1
    mov     r3, #0xFFFFFFFF
    b       .endSTP1
                
.success_Observation_M_STP1:
    mov     r10, #0xFFFF

.loopCheckState1:
    mov     r3, r10
    cmp     r3, #0
    moveq   r3, #0
    movne   r3, #1
    uxtb    r3, R3
    sub     r10, r10, #1
    cmp     r3, #0
    beq     .doneCheckState1
    ldr     r1, [r0,#TWI_STAT]          // get [TWI_STAT]
    cmp     r1, #0xF8                   // check for No relevant status information, INT_FLAG=0
    bne     .loopCheckState1

.doneCheckState1:
    ldr     r1, [r0,#TWI_STAT]          // get [TWI_STAT]
    cmp     r1, #0xF8                   // again check for No relevant status information, INT_FLAG=0
    beq     .success_M_STP1
    mov     r3, #0xFFFFFFFF
    b       .endSTP1
// ---------------------------------------------------------------------------

.success_M_STP1:
    mov             r3, #0
.endSTP1:
    mov             r0, r3
    bx              lr
// End of function AT8563S_Send_STOP_Signal

//###############################################################################################################
//########################################## RTC Functions ######################################################
//###############################################################################################################
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
    
    bl      AT8563S_Send_START_Via_TWI1         // Start Signal

    mov     r6, #0                              // State Write
    bl      AT8563S_SendAddressReadWrite        // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    ldr     r6, =AT8563S_VL_seconds             // Send Register Address to send data to it on next byte
    bl      AT8563S_Send_Single_Byte_Data_Via_TWI1

    bl      AT8563S_Send_STOP_Signal             // Stop Signal

    bl      AT8563S_Send_START_Via_TWI1         // Start Signal

    mov     r6, #1                              // State Read
    bl      AT8563S_SendAddressReadWrite        // Send Address (make sure lsb [bit 0] is 0 for Writing and 1 for Reading)

    // -- Get Seconds --
    mov     r6, #1                              // Request More Bytes Would Follow This Received one
    bl      AT8563S_Receive_Single_Byte_Data_Via_TWI1
    mov     r0, r7
    and     r0, r0, #0x7F                       // Clear Bit[7] (VL) Seconds BCD has 7 bits only
    bl      bcd_to_bin
    mov     r8, r0                              // Save Seconds bits[0-5] (bin size 6 bits) r8 = sec
    
    // -- Get Minutes --
    mov     r6, #1                              // Request More Bytes Would Follow This Received one
    bl      AT8563S_Receive_Single_Byte_Data_Via_TWI1
    mov     r0, r7
    and     r0, r0, #0x7F                       // Clear Bit[7] Minutes BCD has 7 bits Only
    bl      bcd_to_bin
    lsl     r0, r0, #8                          // Shift To the Location Of Minutes bits[8-13] (bin size 6 bits)
    orr     r8, r0, r8                          // Save Minutes (r8 = Min | Sec)

    // -- Get Hours --
    mov     r6, #1                              // Request More Bytes Would Follow This Received one
    bl      AT8563S_Receive_Single_Byte_Data_Via_TWI1
    mov     r0, r7
    and     r0, r0, #0x3F                       // Clear Bits[6-7] Hours BCD has 6 bits only
    bl      bcd_to_bin
    lsl     r0, r0, #16                         // Shift To the Location Of Hours bits[16-20] (bin size 5 bits)
    orr     r8, r0, r8                          // Save Hours (r8 =  Hours |Min | Sec )

    // -- Get Days --
    mov     r6, #1                              // Request More Bytes Would Follow This Received one
    bl      AT8563S_Receive_Single_Byte_Data_Via_TWI1
    mov     r0, r7
    and     r0, r0, #0x3F                       // Clear Bits[6-7] Days BCD has 6 bits only
    bl      bcd_to_bin
    mov     r9, r0                              // Save Days bits[0-4] (bin size 5 bits) r9 = Days

    // -- Get Weekday --
    mov     r6, #1                              // Request More Bytes Would Follow This Received one
    bl      AT8563S_Receive_Single_Byte_Data_Via_TWI1
    mov     r0, r7
    and     r0, r0, #0x7                        // Clear Bits[3-7] Weekday has 3 bits only
    lsl     r0, r0, #29                         // Shift To the Location Of Week bits[29-31] (size 3 bits)
    orr     r8, r0, r8                          // Weekday (r8 =  Weekday | Hours |Min | Sec )

    // -- Get Months --
    mov     r6, #1                              // Request More Bytes Would Follow This Received one
    bl      AT8563S_Receive_Single_Byte_Data_Via_TWI1
    mov     r0, r7
    and     r0, r0, #0x1F                       // Clear Bits[5-7] Days BCD has 5 bits only
    bl      bcd_to_bin
    lsl     r0, r0, #8                          // Shift To the Location Of Months bits[8-11] (bin size 4 bits)
    orr     r9, r0, r9                          // Save Months (r9 = Months | Days)
        
    // -- Get Years --
    mov     r6, #0                              // Indicate that this is the last Byte to Receive
    bl      AT8563S_Receive_Single_Byte_Data_Via_TWI1
    mov     r0, r7
    and     r0, r0, #0xFF                       // Year BCD has 8 bits
    bl      bcd_to_bin
    lsl     r0, r0, #16                         // Shift To the Location Of Years bits[16-23] (bin size 8 bits)
    orr     r9, r9, r0                          // Save Years (r9 = Year | Months | Days)

    bl      AT8563S_Send_STOP_Signal            // Stop Signal

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
    
    mov     r8, r0                              // Value
    mov     r9, r1                              // Type
    
    bl      AT8563S_Send_START_Via_TWI1         // Start Signal

    mov     r6, #0                              // State Write
    bl      AT8563S_SendAddressReadWrite        // Send Address (make sure lsb [bit 0] is 0 for Writing - our case - and 1 for Reading)
    
    add     r6, r9, #2                          // Send Register Address to send data to it on next byte
    bl      AT8563S_Send_Single_Byte_Data_Via_TWI1

    and     r0, r8, #0xFF                       // make sure It Is one Byte
    bl      bin_to_bcd                          // Convert to BCD
    and     r6, r0, #0xFF                       // Send Byte to Register
    bl      AT8563S_Send_Single_Byte_Data_Via_TWI1

    bl      AT8563S_Send_STOP_Signal             // Stop Signal
    pop     {r2-r10, pc}
    .ltorg


//###############################################################################################################
//########################################## LRADC Functions ####################################################
//###############################################################################################################
// =============== S U B R O U T I N E =======================================
// input:
// output:
// r0: 0 for success
// ===========================================================================
LRADC_Enable:

    ldr     r0, =LRADC_BASE
    ldr     r1, [r0,# LRADC_CTRL]          // get [LRADC_CTRL]
    orr     r1, r1, #(0b1 << 0)            // Set bit[0] Enable LRDC
    str     r1, [r0,# LRADC_CTRL]          // Store to [LRADC_CTRL]

    bx      lr
    
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

    ldr     r0, =LRADC_BASE
    ldr     r0, [r0,# LRADC_DATA0]          // get [LRADC_CTRL]

    bx      lr

//###############################################################################################################
//########################################## Tools Functions ######################################################
//###############################################################################################################

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
