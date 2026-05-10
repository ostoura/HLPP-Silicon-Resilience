org 0x7c00  ; Boot sector start address
; remember dl has the Boot Drive Number

;****************************************************
;---- Boot Sector -----
;****************************************************
sector_0:
jmp  main
    ; Set up the BIOS Parameter Block (BPB)
    ; if the Bios is Using FDD Emulator For USB Use this Fake BPB
    TIMES 3-($-$$) DB 0x90   ; Support 2 or 3 byte encoded JMPs before BPB.
    
    ; Dos 4.0 EBPB 1.44MB floppy
    OEMname:           db    "mkfs.fat"  ; mkfs.fat is what OEMname mkdosfs uses
    bytesPerSector:    dw    512
    sectPerCluster:    db    1
    reservedSectors:   dw    1
    numFAT:            db    2
    numRootDirEntries: dw    224
    numSectors:        dw    2880
    mediaType:         db    0xf0
    numFATsectors:     dw    9
    sectorsPerTrack:   dw    18
    numHeads:          dw    2
    numHiddenSectors:  dd    0
    numSectorsHuge:    dd    0
    driveNum:          db    0
    reserved:          db    0
    signature:         db    0x29
    volumeID:          dd    0x2d7e5a1a
    volumeLabel:       db    "NO NAME    "
    fileSysType:       db    "FAT12   "

    ; if the Bios is Using HDD Emulator For USB Use this Fake BPB
    ;NOP
    ;BS_OEMName      DB "HARIBOTE"
    ;BPB_BytsPerSec  DW 0x0200
    ;BPB_SecPerClus  DB 0x01
    ;BPB_RsvdSecCnt  DW 0x0001
    ;BPB_NumFATs     DB 0x02
    ;BPB_RootEntCnt  DW 0x0000
    ;BPB_TotSec16    DW 0x0000
    ;BPB_Media       DB 0xf8
    ;BPB_FATSz16     DW 0x0000
    ;BPB_SecPerTrk   DW 0xffff
    ;BPB_NumHeads    DW 0x0001
    ;BPB_HiDDSec     DD 0x00000000
    ;BPB_TotSec32    DD 0x00ee5000
    ;BPB_FATSz32     DD 0x000000ed
    ;BPB_ExtFlags    DW 0x0000
    ;BPB_FSVer       DW 0x0000
    ;BPB_RootClus    DD 0x00000000
    ;BPB_FSInfo      DW 0x0001
    ;BPB_BkBootSec   DW 0x0000
    ;
    ;times   12      DB 0    ;BPB_Reserverd
    ;
    ;BS_DrvNum       DB 0x80
    ;BS_Reserved1    DB 0x00
    ;BS_BootSig      DB 0x29
    ;BS_VolID        DD 0xa0a615c
    ;BS_VolLab       DB "ISHIHA BOOT"
    ;BS_FileSysType  DB "FAT32   "

main:
    ; Initialize segment registers
    xor ax,ax               ; We want a segment of 0 for DS for this question
    mov ds,ax               ;     Set AX to appropriate segment value for your situation
    mov es,ax               ; In this case we'll default to ES=DS
    mov bx,0x8000           ; Stack segment can be any usable memory
    
    cli                     ; Disable interrupts to circumvent bug on early 8088 CPUs
    mov ss,bx               ; This places it with the top of the stack @ 0x80000.
    mov sp,ax               ; Set SP=0 so the bottom of stack will be @ 0x8FFFF
    sti                     ; Re-enable interrupts
    mov [boot_drive], dl    ; dl has the booted drive number
    cld                     ; Set the direction flag to be positive direction

    ; Start in text mode
    mov ax, 3
    int 0x10
    mov ax, 0x0500
    int 0x10

    ;load sector1 to memory address out of the 512
    mov ah,02h          ;read from floppydisk (USB FDD Emulator Bios)
                        ; Note: if the Bios uses HDD Emulator we use 42h not 02h
    mov al,32           ;load 32 sectors (each is 512 so total codes 16,384) check last line (*)
    mov ch,0            ;first(and only) cylinder
    mov cl,2            ;starting at sector 2
    mov dh,0            ;first head
    mov dl,69           ;boot drive number, gets overwriten with the correct drive at next step
    boot_drive: equ $-1 ;dirty hack to avoid using a variable (the location of this lablel is 1 byte before its position $-1)
    mov bx,sector_1     ;address where the data will be loaded (let the system choose a place automatically)
    ;mov bx,0x07E0      ; optionaly you can set the address where the data will be loaded
    ;mov es, bx         ; manually to 0x07E0:0x0000 es:bx
    ;xor bx,bx          ; es = 0x07E0 & bx = 0x0000
    int 0x13
    jnc sucessRead      ;if no error jump to sucessRead

    mov si, drive_err   ;else print error and quit
    call printstr
    jmp end_prgm

sucessRead:
    jmp sector_1        ;let the CPU start excute from address sector_1 (automatically choosen)
    ;jmp 0x07E0:0x0000  ; optionaly if you set the address manually so you can call it
end_prgm:
    jmp $               ; Jump to your same location (meaning stay for infinity)

;---------------------------------------------------
;print the null-terminated string at starting at si
;---------------------------------------------------
printstr:
    push ax
    push bx
    push si
    mov ah, 0x0e
    xor bl, bl
    printstr_loop:
        lodsb
        cmp al , 0
            je short printstr_endl
        int 0x10
        jmp short printstr_loop
    printstr_endl:
    pop si
    pop bx
    pop ax
    ret

drive_err:    db  "Cant access drive",10,13

times 510-($-$$) db 0       ; 512 bytes for the bootloader with last two bytes 55AA
dw 0xaa55                   ; Boot signature














%define VRAM_START 0x8000  ; Point to safe RAM above the bootloader

;****************************************************
;---- Kernel Sector -----
;****************************************************
sector_1:

    xor ax,ax               ; We want a segment of 0 for DS for this question
    mov ds,ax               ;     Set AX to appropriate segment value for your situation
    mov es,ax               ; In this case we'll default to ES=DS
    mov bx,0x9000           ; Stack segment can be any usable memory

    cli                     ; Disable interrupts to circumvent bug on early 8088 CPUs
    mov ss,bx               ; This places it with the top of the stack @ 0x80000.
    mov sp,ax               ; Set SP=0 so the bottom of stack will be @ 0x8FFFF
    sti                     ; Re-enable interrupts
    cld                     ; Set the direction flag to be positive direction

    ; move to GFX mode 320x200
    mov ax, 13h     ; Set Video Mode
    int 10h         ; Call BIOS video interrupt
    
    push    VRAM_START
    pop     es
    call    Clean_CRT
    
    mov     word [show_counter], 0

    jmp screensync
    
    jmp $




;------------------------------------------
; Screen function that control composite A/V
; Facts:
;  Pal
;   Total Line: 64µs
;   Line blanking 12.05µs +/- 0.25µs
;   Line Sync: 4.7µs +/- 0.1µs
;   Back Porch: 5.8µs +/- 0.1µs
;   Active Video: 52.0µs +/- 0.1µs
;   Front Porch: 1.65µs +/- 0.1µs (This is the tiny gap before the next Sync)
;   lines: Total 312 lines (8 sync + 304 raster)
;
;  NTSC (RS-170 / M)
;   Total Line: 63.556µs (Often simplified to 63.5µs)
;   Line blanking: 10.9µs +/- 0.2µs
;   Line Sync: 4.7µs +/- 0.1µs
;   Back Porch: 4.7µs +/- 0.1µs
;   Active Video: 52.6µs +/- 0.1µs
;   Front Porch: 1.5µs +/- 0.1µs (The gap before the next Sync)
;   lines: Total 260 lines (8 sync + 252 raster)
;------------------------------------------
screensync:

    mov     ax, 0               ; ax: 0 = PAL 1 = NTSC
    call    setCRTTimingWithCPU

draw_frame:
    push    VRAM_START         ; 0x8000
    pop     es
    xor     di, di

    cli             ; Disable interrupts for perfect signal timing
    mov     dx, 0x378   ; Parallel Port Base Address

    ; --- SECTION A: VERTICAL SYNC (3 Lines of 0V) ---
    ; This tells the TV to reset the beam to the top of the screen
    mov     al, 0x00
    out     dx, al
    mov     ebx, [vertical_sync]  ; ~192us (3 lines * 64us / 0.838us)
.vertical_sync_delay:
    dec     ebx
    jnz     .vertical_sync_delay
    
    ; --- SECTION B: THE RASTER (304 Lines Remaining) ---
     mov    si, [lines_count]       ; PAL Total 312 lines (8 sync + 304 raster)
line_loop:
    ; 1. H-SYNC (0V)
    mov     al, 0x00                ; D0=0, D1=0
    out     dx, al
    mov     ebx, [line_sync]
.line_sync_delay:
    dec     ebx
    jnz     .line_sync_delay

;---- New under test Back Porch with color brust
; 2. BACK PORCH (Total target: 5.8us)

    ; 2. BACK PORCH (0.3V - Black Level)
    mov     al, 0x02                ; D0=1 (1k ohm pin) <------------ Now its 0v not 0.3 (crazy thing)
    out     dx, al
    mov     ebx, [back_porch]  ; Width of the bar On a 3GHz CPU, try starting here
.back_porch_delay:
    dec     ebx
    jnz     .back_porch_delay
;-----------------------------------

    
    mov     ah, 01
    mov     al, 02
    cmp     si, 152             ; Half the PAL (304 / 2) please revise for NTSC
    jae     .activedraw
    xchg    ah, al
    
.activedraw:
    ; 3. ACTIVE VIDEO (0.95V - White 0.3V - Black)
    ; If the screen is still too "hot", change this to 02h
    mov     cx, [pattern_number]     ; 16 patterns of black and white horizontally = 32 blocks per line
.another_pixel:
    mov     al, es:[di]
    out     dx, al
    inc     di
    loop    .another_pixel

    ; 4. FRONT PORCH (CRITICAL FOR STABILITY)
    ; This "buffer" prevents the pixels from crashing into the next line's sync
    mov     al, 0x01
    out     dx, al
    mov     ebx, [front_porch] ; Use the ~4950 we calculated
.fp_delay:
    dec     ebx
    jnz     .fp_delay
    
    dec     si
    jnz     line_loop               ; Next scanline

    ; --- SECTION C: FRAME END ---
    ; Briefly allow hardware interrupts if needed before next frame
    sti
    call    mainEntry               ; allow code to be excuted afgter every frame
    jmp     draw_frame


;////////////////////////////////////////////
; General Functions
;////////////////////////////////////////////

mainEntry:
    pusha
    
    mov     ax, [show_counter]
    cmp     ax, 1
    jne     .skip_checkerboard
    call    CreateCheckerboardCRT       ; this for test checker board view
    jmp     .continue
.skip_checkerboard:
    mov     ax, [show_counter]
    cmp     ax, 2
    jne     .skip_print0
    call    printPage0
    jmp     .continue
.skip_print0:
    mov     ax, [show_counter]
    cmp     ax, 3
    jne     .skip_print1
    call    printPage1
    jmp     .continue
.skip_print1:
    mov     ax, [show_counter]
    cmp     ax, 4
    jne     .skip_print2
    call    printPage2       ; this for test checker board view
    jmp     .continue
.skip_print2:
    mov     ax, [show_counter]
    cmp     ax, 5
    jne     .skip_print3
    call    printPage3
    jmp     .continue
.skip_print3:
    mov     ax, [show_counter]
    cmp     ax, 6
    jne     .skip_print4
    call    printPage4
    jmp     .continue
.skip_print4:
    mov     ax, [show_counter]
    cmp     ax, 7
    jne     .skip_print5
    call    printPage5       ; this for test checker board view
    jmp     .continue
.skip_print5:
    call    digitalAnalogClock

.continue:
    call    printCRTSyncData            ; for test on the PC Screen it self

    call   check_key                    ; to adjust CRT sync time with numbers on the pc screen
    
    popa
    ret


;-----------------------------------------------------
; bx = StartX for the 16 Segment Module (from left)
; dx = StartY for the 16 Segment Module (from top)
; al = Color
; ah = Number
;-----------------------------------------------------
printPage0:
    pusha
    
    mov     si, 6       ; width of single Character +1 (4 + 1)
    mov     di, 46      ; height of single character +2 (44 + 1)
    mov     dx, 40      ; Y
    mov     al, 2       ; color white
    mov     ah, 0x20    ; first character
.reloop:
    mov     bx, 2       ; X
    mov     bp, 6       ; number of characters per line
.stillInLine:
    call    write_digit_width_5            ; Call your character writer
    inc     ah
    cmp     ah, 0x40
    jae     .skipPrint
    add     bx, si
    dec     bp
    jnz     .stillInLine
    add     dx, di
    jmp     .reloop
.skipPrint:

    popa
    ret
 
;-----------------------------------------------------
; bx = StartX for the 16 Segment Module (from left)
; dx = StartY for the 16 Segment Module (from top)
; al = Color
; ah = Number
;-----------------------------------------------------
printPage1:
    pusha
    
    mov     si, 6       ; width of single Character +1 (4 + 1)
    mov     di, 46      ; height of single character +2 (44 + 1)
    mov     dx, 40      ; Y
    mov     al, 2       ; color white
    mov     ah, 0x40    ; first character
.reloop:
    mov     bx, 2       ; X
    mov     bp, 6       ; number of characters per line
.stillInLine:
    call    write_digit_width_5            ; Call your character writer
    inc     ah
    cmp     ah, 0x60
    jae     .skipPrint
    add     bx, si
    dec     bp
    jnz     .stillInLine
    add     dx, di
    jmp     .reloop
.skipPrint:

    popa
    ret
 
 ;-----------------------------------------------------
; bx = StartX for the 16 Segment Module (from left)
; dx = StartY for the 16 Segment Module (from top)
; al = Color
; ah = Number
;-----------------------------------------------------
printPage2:
    pusha
    
    mov     si, 6       ; width of single Character +1 (4 + 1)
    mov     di, 46      ; height of single character +2 (44 + 1)
    mov     dx, 40      ; Y
    mov     al, 2       ; color white
    mov     ah, 0x60    ; first character
.reloop:
    mov     bx, 2       ; X
    mov     bp, 6       ; number of characters per line
.stillInLine:
    call    write_digit_width_5            ; Call your character writer
    inc     ah
    cmp     ah, 0x80
    jae     .skipPrint
    add     bx, si
    dec     bp
    jnz     .stillInLine
    add     dx, di
    jmp     .reloop
.skipPrint:

    popa
    ret

;-----------------------------------------------------
; bx = StartX for the 16 Segment Module (from left)
; dx = StartY for the 16 Segment Module (from top)
; al = Color
; ah = Number
;-----------------------------------------------------
printPage3:
    pusha
    
    mov     si, 6       ; width of single Character +1 (4 + 1)
    mov     di, 46      ; height of single character +2 (44 + 1)
    mov     dx, 40      ; Y
    mov     al, 2       ; color white
    mov     ah, 0x20    ; first character
.reloop:
    mov     bx, 2       ; X
    mov     bp, 6       ; number of characters per line
.stillInLine:
    call    write_digit_width_4            ; Call your character writer
    inc     ah
    cmp     ah, 0x40
    jae     .skipPrint
    add     bx, si
    dec     bp
    jnz     .stillInLine
    add     dx, di
    jmp     .reloop
.skipPrint:

    popa
    ret
 
;-----------------------------------------------------
; bx = StartX for the 16 Segment Module (from left)
; dx = StartY for the 16 Segment Module (from top)
; al = Color
; ah = Number
;-----------------------------------------------------
printPage4:
    pusha
    
    mov     si, 6       ; width of single Character +1 (4 + 1)
    mov     di, 46      ; height of single character +2 (44 + 1)
    mov     dx, 40      ; Y
    mov     al, 2       ; color white
    mov     ah, 0x40    ; first character
.reloop:
    mov     bx, 2       ; X
    mov     bp, 6       ; number of characters per line
.stillInLine:
    call    write_digit_width_4            ; Call your character writer
    inc     ah
    cmp     ah, 0x60
    jae     .skipPrint
    add     bx, si
    dec     bp
    jnz     .stillInLine
    add     dx, di
    jmp     .reloop
.skipPrint:

    popa
    ret
 
 ;-----------------------------------------------------
; bx = StartX for the 16 Segment Module (from left)
; dx = StartY for the 16 Segment Module (from top)
; al = Color
; ah = Number
;-----------------------------------------------------
printPage5:
    pusha
    
    mov     si, 6       ; width of single Character +1 (4 + 1)
    mov     di, 46      ; height of single character +2 (44 + 1)
    mov     dx, 40      ; Y
    mov     al, 2       ; color white
    mov     ah, 0x60    ; first character
.reloop:
    mov     bx, 2       ; X
    mov     bp, 6       ; number of characters per line
.stillInLine:
    call    write_digit_width_4            ; Call your character writer
    inc     ah
    cmp     ah, 0x80
    jae     .skipPrint
    add     bx, si
    dec     bp
    jnz     .stillInLine
    add     dx, di
    jmp     .reloop
.skipPrint:

    popa
    ret

    
;-------------------------------------
; Print CRT Timing Details On The PC
;-------------------------------------
printCRTSyncData:
    pusha
    
    mov     dh, 0           ; DH=Row (13h)
    mov     dl, 2           ; DL=Column (20h)
    call    set_cursor
    lea     di, [cpu_mhz_text]
    mov     cl, [whiteColor]
    call    print_string

    mov     eax, [cpu_mhz]
    call    Dec2Ascii32
    lea     di, [outputDec]
    mov     cl, [whiteColor]
    call    print_string

    mov     dh, 1           ; DH=Row (13h)
    mov     dl, 2           ; DL=Column (20h)
    call    set_cursor

    lea     di, [vertical_sync_text]
    mov     cl, [whiteColor]
    call    print_string
    
    mov     eax, [vertical_sync]
    call    Dec2Ascii32
    lea     di, [outputDec]
    mov     cl, [whiteColor]
    call    print_string

    mov     dh, 2           ; DH=Row (13h)
    mov     dl, 2           ; DL=Column (20h)
    call    set_cursor

    lea     di, [line_sync_text]
    mov     cl, [whiteColor]
    call    print_string
    
    mov     eax, [line_sync]
    call    Dec2Ascii32
    lea     di, [outputDec]
    mov     cl, [whiteColor]
    call    print_string

    mov     dh, 3           ; DH=Row (13h)
    mov     dl, 2           ; DL=Column (20h)
    call    set_cursor

    lea     di, [back_porch_text]
    mov     cl, [whiteColor]
    call    print_string
    
    mov     eax, [back_porch]
    call    Dec2Ascii32
    lea     di, [outputDec]
    mov     cl, [whiteColor]
    call    print_string

    mov     dh, 4           ; DH=Row (13h)
    mov     dl, 2           ; DL=Column (20h)
    call    set_cursor

    lea     di, [active_video_width_text]
    mov     cl, [whiteColor]
    call    print_string
    
    mov     eax, [active_video_width]
    call    Dec2Ascii32
    lea     di, [outputDec]
    mov     cl, [whiteColor]
    call    print_string

    mov     dh, 5           ; DH=Row (13h)
    mov     dl, 2           ; DL=Column (20h)
    call    set_cursor

    lea     di, [pixel_cycles_text]
    mov     cl, [whiteColor]
    call    print_string
    
    mov     eax, [pixel_cycles]
    call    Dec2Ascii32
    lea     di, [outputDec]
    mov     cl, [whiteColor]
    call    print_string

    mov     dh, 6           ; DH=Row (13h)
    mov     dl, 2           ; DL=Column (20h)
    call    set_cursor

    lea     di, [pattern_number_text]
    mov     cl, [whiteColor]
    call    print_string

    mov     eax, [pattern_number]
    call    Dec2Ascii32
    lea     di, [outputDec]
    mov     cl, [whiteColor]
    call    print_string
    
    popa
    ret

;-------------------------------------
; location is es:[di]
; Locations A000:[(160 * Y) + X]
; bx = X
; dx = Y
; al = Color
;-------------------------------------
draw_point:
    pusha
    mov cl, al
    mov ax, dx      ; Y
    mov dx, 40
    mul dx
    add ax, bx      ; X di = (40 * Y) + X
    mov di, ax
    mov es:[di],cl
    popa
    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; cx = length of column
; al = Color
;-------------------------------------
makeColumn:
    push dx

    doColumn:
        call draw_point
        inc dx
        loop doColumn

    pop dx
    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; cx = length of row
; al = Color
;-------------------------------------
makeRow:
    push bx

    doRow:
        call draw_point
        inc bx
        loop doRow

    pop bx
    ret

;---------------------------------------------------------
; CreateCheckerboard (Safe 200-line version)
; input:
; ES: VRAM
;---------------------------------------------------------
CreateCheckerboardCRT:
    xor     di, di
    
    mov     bx, 0       ; Start X
    mov     dx, 0       ; Start Y
    mov     al, 02      ; White
    mov     ah, 01      ; Black
    
    mov     cx, 19      ; how many blocks vertically 19 x 16px = 304 pixels
.checkerColumnLoopCRT:
    push    ax
    push    cx
    mov     cx, 16       ; size of the block vertically 16 (16x2)
.checkerRowLoopCRT:
    push    cx
    mov     cx, 20       ;  how many blocks horizontally 20 x 2px = 40 pixels
.checkerLineLoopCRT:
    push    cx
    mov     al, al      ; no need for that
    mov     cx, 2       ; length of the H Segment 2
    call    makeRow
    
    add     bx, 2       ; step to position 2+
    
    xchg    ah, al      ; use color in AH
    mov     cx, 2       ; length of the 2nd H Segment 2
    call    makeRow
    
    xchg    ah, al      ; return ah and al to previous
    add     bx, 2
    
    pop     cx
    loop    .checkerLineLoopCRT
    
    mov     bx, 0       ; Start of line
    inc     dx          ; next row
    pop     cx
    loop    .checkerRowLoopCRT

    pop     cx
    pop     ax
    xchg ah, al         ; xchg ah, al
    loop    .checkerColumnLoopCRT
    ret

;-------------------------------------
; Clean CRT Tube Screen
;-------------------------------------
Clean_CRT:
    ; To clear the screen:
    push VRAM_START     ; Load the segment value
    pop  es             ; ES now points to the "VRAM" area
    xor di, di          ; DI = 0 (Start at the very beginning of the segment)

    mov cx, 40*304      ; 12,160 pixels
    mov al, 0x01        ; Black pixel (Standard Level)
    rep stosb           ; Fill [ES:DI] with AL, increment DI, repeat CX times
    ret

;--------------------------------------
; set_cursor
; DH=Row
; DL=Column (20h)
;--------------------------------------
set_cursor:
    pusha

    mov ah, 0x02           ; AH=02h (set cursor)
    mov bh, 0x00           ; BH=Page (0)
    int 10h

    popa
    ret


;--------------------------------------
; getCPUSpeed
; output:
;   [cpu_mhz]
;--------------------------------------
getCPUSpeed:
    ; 1. Get start cycles
    rdtsc
    push edx
    push eax

    ; 2. BIOS Wait (CX:DX = microseconds to wait)
    ; Let's wait for 65,536us (0.065 seconds)
    mov ah, 86h
    mov cx, 0x0001    ; High word
    mov dx, 0x0000    ; Low word (Total 65536us)
    int 15h

    ; 3. Get end cycles
    rdtsc
    pop ecx           ; Old Low
    pop ebx           ; Old High
    sub eax, ecx      ; EAX = Cycles elapsed during wait
    
    ; 4. Calculate Cycles Per Microsecond
    ; Since we waited 65,536us, we shift right by 16 bits (divide by 65536)
    ; This is a very "fast" way to divide in assembly!
    shr eax, 16       ; EAX is now your MHz (approx 3000 for E8400)
    
    mov [cpu_mhz], eax
    ret
 
;--------------------------------------
; setCRTTimingWithCPU
; input:
; ax: 0 = PAL 1 = NTSC
; output:
;   [cpu_mhz]
;   [vertical_sync]
;   [line_sync]
;   [back_porch]
;   [white_length]
;   [black_length]
;   [active_video_width]
;   [stabilizer]
;   [pixel_cycles]
;   [front_porch]
;   [lines_count]
;--------------------------------------
setCRTTimingWithCPU:
    
    push    eax
    
    call    getCPUSpeed
 
    ; Assuming EAX = 2970 (or measured MHz)
    mov [cpu_mhz], eax
    
    pop eax
    
    cmp     ax, 0
    je      .PAL
.NTSC:
    
    ; 1. Vertical Sync (190.5us)
    ; Math: (MHz * 48768) >> 8
    mov eax, [cpu_mhz]
    imul eax, 48768
    shr eax, 8
    mov [vertical_sync], eax
    
    ; 2. Line Sync (4.7us)
    ; Math: (MHz * 1203) >> 8
    mov eax, [cpu_mhz]
    imul eax, 1203
    shr eax, 8
    mov [line_sync], eax
    
    ; 3. Back Porch (4.7us)
    ; Math: (MHz * 1203) >> 8
    mov eax, [cpu_mhz]
    imul eax, 1203
    shr eax, 8
    mov [back_porch], eax
    
    ; 4. White Length (15us - adjustable)
    mov eax, [cpu_mhz]
    imul eax, 3840
    shr eax, 8
    mov [white_length], eax
    
    ; 5. Black Length (37.6us - fills the line)
    ; Math: (MHz * 9625) >> 8
    mov eax, [cpu_mhz]
    imul eax, 9625
    shr eax, 8
    mov [black_length], eax
    
    ; --- Getting Cycles per one line (width cycles) ---
    ; NTSC Active Video is 52.6us
    ; Math: (MHz * 13466) >> 8 (Result is approx 155,064 @ 2948MHz)
    mov eax, [cpu_mhz]
    imul eax, 13466
    shr eax, 8
    mov [active_video_width], eax
    
    ; --- CALCULATE PIXEL WIDTH (320x200px target) ---
    mov  eax, [active_video_width]
    imul eax, 205           ; Multiply by 205 (1/320 fixed point)
    shr  eax, 16            ; Result: ~484 for NTSC
    mov  [pixel_cycles], eax
    
    ; --- Calculate Front Porch (1.5us) ---
    mov eax, [cpu_mhz]      ; e.g., 3000
    mov ebx, 3
    mul ebx                 ; eax = 9000
    shr eax, 1              ; eax = 4500 (1.5us worth of cycles)
    mov [front_porch], eax

    mov dword [lines_count], 252

.PAL:
    ; 1. Vertical Sync (192us)
    mov eax, [cpu_mhz]
    imul eax, 49152
    shr eax, 8
    mov [vertical_sync], eax
    
    ; 2. Line Sync (4.7us)
    mov eax, [cpu_mhz]
    imul eax, 1203
    shr eax, 8
    mov [line_sync], eax
    
    ; 3. Back Porch (5.8us)
    mov eax, [cpu_mhz]
    imul eax, 1485
    shr eax, 8
    mov [back_porch], eax
    
    ; 4. White Length (15us - adjustable)
    mov eax, [cpu_mhz]
    imul eax, 3840
    shr eax, 8
    mov [white_length], eax
    
    ; 5. Black Length (37us - fills the line)
    mov eax, [cpu_mhz]
    imul eax, 9472
    shr eax, 8
    mov [black_length], eax
    
    ; --- Getting Cycles per one line (width cycles) ---
    mov eax, [cpu_mhz]
    mov ebx, 52                     ; --- Calculate Active Video width (52us) ---
    mul ebx                         ; EAX = MHz * 52
    mov [active_video_width], eax   ; Result is approx 153,296
    
    ; --- CALCULATE PIXEL WIDTH (320x200px target) ---
    ; Since we are avoiding DIV for ARM portability, we will use our Shift and Add trick. Dividing by 320 is the same as
    ; multiplying by 1/320. In fixed-point (scaling by 65536):
    ;   (1 / 320) * 65536 = around 205
    ; The Formula: Pixel_Cycles = (Active_Video_Width * 205) >> 16
    ; EAX = 153,296 (Your dynamic active_video_width)
    mov  eax, [active_video_width]
    imul eax, 205           ; Multiply by 205
    shr  eax, 16            ; Shift right by 16 (Result: ~479)
    mov  [pixel_cycles], eax ; Store for the loop
    
    ; --- Calculate Front Porch (1.65us) ---
    mov eax, [cpu_mhz]      ; e.g., 3000
    imul eax, 422           ; Multiply
    shr eax, 8             ; eax = 4950 (1.65us worth of cycles)
    mov [front_porch], eax
 
    mov dword [lines_count], 304

 .endSetCRT:
    ret

;-------------------------------------
; Clean Screen
;-------------------------------------
clean_GFX:
    ; clean screen
    mov ax, 0
    int 0x10

    ; move to GFX mode 320x200
    mov ax, 13h     ; Set Video Mode
    int 10h         ; Call BIOS video interrupt
    ret

;-------------------------------------
; Check if any key is pressed to toggle
; between analog and digital clock
;-------------------------------------
check_key:
    mov ah, 01h     ; Function to check keyboard buffer
    int 16h         ; Call BIOS keyboard interrupt

    jz .endkeycheck ; Jump if ZF is set (no key pressed)

    ; If ZF is clear, a key was pressed
    ; AL contains ASCII character, AH contains scan code
    ; Process the key here


    push    ax              ; Save The Key Scan

; --- 1. DETERMINE STEP SIZE (The "Speed" of tuning) ---
    
    mov ebx, 1              ; Default step = 1 (Fine tuning)

    mov ah, 02h             ; Get shift flags
    int 16h                 ; AL now contains flags

    and al, 00001111b       ; Mask out everything except Shift, Ctrl, Alt
    jz .endVariation        ; If no modifiers are pressed, keep ebx=1
    
    ; this is important to make sure any shift key would work left or right
    test al, 00000011b      ; if either shift keys clicked
    jz  .noshift
    or al, 00000011b        ; treat it as both clicked
    
.noshift:
    cmp al, 00001111b      ; is Shift + Ctrl + Alt pressed
    jne .notShiftCtrlAlt
    mov ebx, 10000000        ; Shift + Ctrl + Alt = Step by 10000000
    jmp .endVariation
.notShiftCtrlAlt:
    cmp al, 00001100b      ; is Ctrl + Alt pressed
    jne .notCtrlAlt
    mov ebx, 1000000        ; Ctrl + Alt = Step by 1000000
    jmp .endVariation
.notCtrlAlt:
    cmp al, 00001011b      ; is Shift + Alt pressed
    jne .notShiftAlt
    mov ebx, 100000         ; Shift + Alt = Step by 100000
    jmp .endVariation
.notShiftAlt:
    cmp al, 00000111b      ; is Shift + Ctrl pressed
    jne .notShiftCtrl
    mov ebx, 10000          ; Shift + Ctrl = Step by 10000
    jmp .endVariation
.notShiftCtrl:
    cmp al, 00001000b      ; is ALT pressed
    jne .notAlt
    mov ebx, 1000           ; Alt = Step by 1000
    jmp .endVariation
.notAlt:
    cmp al, 00000100b      ; Is Ctrl pressed?
    jne .notCtrl
    mov ebx, 100            ; Ctrl = Step by 100
    jmp .endVariation
.notCtrl:
    cmp al, 00000011b      ; Is both Shift pressed?
    jne .endVariation
    mov ebx, 10             ; Shift = Step by 10
    jmp .endVariation
.endVariation:

    pop     ax              ; restore the Key Scan

.checkSpace:
    cmp ah, 57  ;space
    jnz .checkTab
    call    Clean_CRT
    mov ax, [show_counter]
    inc ax
    cmp ax, 8
    jae  .do_zero
    mov word [show_counter], ax
    jmp .endkeycheck
.do_zero:
    mov word [show_counter], 0
    jmp .endkeycheck

.checkTab:
    cmp ah, 15  ;Tab
    jnz .checkT
    call    Clean_CRT
    mov ax, [mode_counter]
    inc ax
    cmp ax, 4
    jae  .m_zero
    mov word [mode_counter], ax
    jmp .endkeycheck
.m_zero:
    mov word [mode_counter], 0
    jmp .endkeycheck

.checkT:
    cmp ah, 20  ;T
    jnz .checkG
    add [line_sync], ebx
    jmp .endkeycheck

.checkG:
    cmp ah, 34  ;G
    jnz .checkH
    cmp ebx, [line_sync]
    ja  .endkeycheck
    sub [line_sync], ebx
    jmp .endkeycheck

.checkH:
    cmp ah, 35  ;H
    jnz .checkF
    add [back_porch], ebx
    jmp .endkeycheck

.checkF:
    cmp ah, 33  ;F
    jnz .checkW
    cmp ebx, [back_porch]
    ja  .endkeycheck
    sub [back_porch], ebx
    jmp .endkeycheck

.checkW:
    cmp ah, 17  ;W
    jnz .checkS
    add [pattern_number], ebx
    jmp .endkeycheck

.checkS:
    cmp ah, 31  ;S
    jnz .checkD
    cmp ebx, [pattern_number]
    ja  .endkeycheck
    sub [pattern_number], ebx
    jmp .endkeycheck

.checkD:
    cmp ah, 32  ;D
    jnz .checkA
    add [active_video_width], ebx
    jmp .endkeycheck

.checkA:
    cmp ah, 30  ;A
    jnz .checkC
    cmp ebx, [active_video_width]
    ja  .endkeycheck
    sub [active_video_width], ebx
    jmp .endkeycheck

.checkC:
    cmp ah, 46  ;C
    jnz .checkZ
    add [vertical_sync], ebx
    jmp .endkeycheck

.checkZ:
    cmp ah, 44  ;Z
    jnz .endkeycheck
    cmp ebx, [vertical_sync]
    ja  .endkeycheck
    sub [vertical_sync], ebx
    jmp .endkeycheck


.endkeycheck:
    call    clean_keyboard_buffer
    ret



;-------------------------------------
; Clean all previous pressed characters
;-------------------------------------
clean_keyboard_buffer:
    ; Loop to read and discard keys until buffer is empty
    .loop_start:
        mov ah, 01h       ; BIOS function to check for keypress
        int 16h           ; Call BIOS keyboard interrupt
        jz .loop_end      ; If ZF is set (no key), exit loop

        mov ah, 00h       ; BIOS function to read key
        int 16h           ; Call BIOS keyboard interrupt (discards key)
        jmp .loop_start   ; Continue looping

    .loop_end:
        ret               ; Return from the procedure


;--------------------------------------
; RTC_Read
; input:
;
; output:
;   [rtc_sec]
;   [rtc_min]
;   [rtc_hour]
;   [rtc_dow]
;   [rtc_day]
;   [rtc_month]
;   [rtc_year]
;   [rtc_century]
;--------------------------------------

%define RTC_ADDR 70h
%define RTC_DATA 71h

RTC_Read:
    
    ; 1. Wait for "Update in Progress" to clear
    ; This ensures we don't get inconsistent data (like 10:59:60)
.wait_update:
    mov al, 0Ah         ; Status Register A
    out RTC_ADDR, al
    in al, RTC_DATA
    test al, 80h        ; Check bit 7 (UIP)
    jnz .wait_update    ; If busy, keep waiting

    ; 2. Read the Time
    mov al, 00h         ; Seconds
    out RTC_ADDR, al
    in al, RTC_DATA
    mov [rtc_sec], al

    mov al, 02h         ; Minutes
    out RTC_ADDR, al
    in al, RTC_DATA
    mov [rtc_min], al

    mov al, 04h         ; Hours
    out RTC_ADDR, al
    in al, RTC_DATA
    mov [rtc_hour], al

    ; 3. Read the Date
    mov al, 06h         ; Day of Week
    out RTC_ADDR, al
    in al, RTC_DATA
    mov [rtc_dow], al

    mov al, 07h         ; Day of Month
    out RTC_ADDR, al
    in al, RTC_DATA
    mov [rtc_day], al

    mov al, 08h         ; Month
    out RTC_ADDR, al
    in al, RTC_DATA
    mov [rtc_month], al

    mov al, 09h         ; Year
    out RTC_ADDR, al
    in al, RTC_DATA
    mov [rtc_year], al

    ; 4. Check for Century (Optional, Port 32h on some systems)
    ;mov al, 32h
    ;out RTC_ADDR, al
    ;in al, RTC_DATA
    ;mov [rtc_century], al

    ret

;----------------------------------------------------------------
; Convert Decimal 3 bits 1-7 to Week Days 2 letters
; Input:
; al: Dec Value (1-7)
; Output:
; al: First Character
; bl: Second Character
;----------------------------------------------------------------
Dec2WeekDay:
    
    cmp     al, 1
    jne     .monday
    mov     al, 'S'
    mov     bl, 'u'
    jmp       .endD2W
.monday:
    cmp     al, 2
    jne     .tuesday
    mov     al, 'M'
    mov     bl, 'o'
    jmp       .endD2W
.tuesday:
    cmp     al, 3
    jne     .wednesday
    mov     al, 'T'
    mov     bl, 'u'
    jmp       .endD2W
.wednesday:
    cmp     al, 4
    jne     .thursday
    mov     al, 'W'
    mov     bl, 'd'
    jmp       .endD2W
.thursday:
    cmp     al, 5
    jne     .friday
    mov     al, 'T'
    mov     bl, 'h'
    jmp       .endD2W
.friday:
    cmp     al, 6
    jne     .saturday
    mov     al, 'F'
    mov     bl, 'r'
    jmp       .endD2W
.saturday:
    cmp     al, 7
    jne     .endD2W
    mov     al, 'S'
    mov     bl, 't'
    jmp       .endD2W

.endD2W:
    ret

;----------------------------------------------------------------
; Convert Decimal 4 bits 1-12 to Month 3 letters
; Input:
; al: Dec Value (1-12)
; Output:
; al: First Character
; bl: Second Character
; cl: Third Character
;----------------------------------------------------------------
Dec2Month:
    
    cmp     al, 1
    jne     .feb2
    mov     al, 'J'
    mov     bl, 'a'
    mov     cl, 'n'
    jmp       .endD2M
.feb2:
    cmp     al, 2
    jne     .mar3
    mov     al, 'F'
    mov     bl, 'e'
    mov     cl, 'b'
    jmp       .endD2M
.mar3:
    cmp     al, 3
    jne     .apr4
    mov     al, 'M'
    mov     bl, 'a'
    mov     cl, 'r'
    jmp       .endD2M
.apr4:
    cmp     al, 4
    jne     .may5
    mov     al, 'A'
    mov     bl, 'p'
    mov     cl, 'r'
    jmp       .endD2M
.may5:
    cmp     al, 5
    jne     .jun6
    mov     al, 'M'
    mov     bl, 'a'
    mov     cl, 'y'
    jmp       .endD2M
.jun6:
    cmp     al, 6
    jne     .jul7
    mov     al, 'J'
    mov     bl, 'u'
    mov     cl, 'n'
    jmp       .endD2M
.jul7:
    cmp     al, 7
    jne     .aug8
    mov     al, 'J'
    mov     bl, 'u'
    mov     cl, 'l'
    jmp       .endD2M
.aug8:
    cmp     al, 8
    jne     .sep9
    mov     al, 'A'
    mov     bl, 'u'
    mov     cl, 'g'
    jmp       .endD2M
.sep9:
    cmp     al, 9
    jne     .oct10
    mov     al, 'S'
    mov     bl, 'e'
    mov     cl, 'p'
    jmp       .endD2M
.oct10:
    cmp     al, 10
    jne     .nov11
    mov     al, 'O'
    mov     bl, 'c'
    mov     cl, 't'
    jmp       .endD2M
.nov11:
    cmp     al, 11
    jne     .dec12
    mov     al, 'N'
    mov     bl, 'o'
    mov     cl, 'v'
    jmp       .endD2M
.dec12:
    cmp     al, 12
    jne     .endD2M
    mov     al, 'D'
    mov     bl, 'e'
    mov     cl, 'c'
    jmp       .endD2M

.endD2M:
    ret

;////////////////////////////////////////////
; Digital / Analog Clock Section
;////////////////////////////////////////////
digitalAnalogClock:

display_loop_digital:
    ; Get current time
    call    RTC_Read
    mov ch, [rtc_hour]
    mov cl, [rtc_min]
    mov dh, [rtc_sec]

    cmp dh, [prevSecond]
    jz  .skipDraw               ; don`t draw unless the second have changed this work as exact 1 sec delay for draw
    
    mov [prevSecond], dh        ; save current second in a previous Second Buffer

    ;Set Time As 12h not 24
    cmp ch, 0x12
    jl .am
    mov ah, 1                   ; 1 = PM, 0 = AM
    mov [ampm], ah
    sub ch, 0x12
    cmp ch, 0x00                ; if ch - 12 = 0 (if ch = 12 PM)
    jne  .20h
    mov ch, 0x12                ; set the hour to 12
    jmp .12h

.20h:
    cmp ch, 0x0e                ; 8pm => 20 - 12 = E
    jne .21h
    sub ch, 0x06                ; E - 6 = 8
    jmp .12h

.21h:
    cmp ch, 0x0f                ; 9pm => 21 - 12 = F
    jne .12h
    sub ch, 0x06                ; F - 6 = 8
    jmp .12h

.am:
    mov ah, 0                   ; 1 = PM, 0 = AM
    mov [ampm], ah
    
    cmp ch, 0x00                ; if ch = 0 (if ch = 12 AM)
    jne  .12h
    mov ch, 0x12                ; set the hour to 12

.12h:
    mov [rtc_hour], ch          ; save new hours (12h mode)

    ;Get Time in ASCII
    mov al, [rtc_sec]
    call convert_BCD_to_ASCII
    mov [currentS0], ah         ; save ah into memory
    mov [currentS1], al         ; save al into memory

    mov al, [rtc_min]
    call convert_BCD_to_ASCII
    mov [currentM0], ah         ; save ah into memory
    mov [currentM1], al         ; save al into memory

    mov al, [rtc_hour]
    call convert_BCD_to_ASCII
    mov [currentH0], ah         ; save ah into memory
    mov [currentH1], al         ; save al into memory

    mov al, [rtc_dow]
    call BCD2HEX
    inc al
    call Dec2WeekDay
    mov [currentW0], al         ; save ah into memory
    mov [currentW1], bl         ; save al into memory

    mov al, [rtc_day]
    call convert_BCD_to_ASCII
    mov [currentD0], ah         ; save ah into memory
    mov [currentD1], al         ; save al into memory

    mov al, [rtc_month]
    call convert_BCD_to_ASCII
    mov [currentN0], ah         ; save ah into memory
    mov [currentN1], al         ; save al into memory
    
    mov al, [rtc_month]
    call BCD2HEX
    call Dec2Month
    mov [currentT0], al         ; save ah into memory
    mov [currentT1], bl         ; save al into memory
    mov [currentT2], cl         ; save al into memory
    
    
    mov al, [rtc_year]
    call convert_BCD_to_ASCII
    mov byte [currentY0], '2'   ; save ah into memory
    mov byte [currentY1], '0'   ; save al into memory
    mov [currentY2], ah         ; save ah into memory
    mov [currentY3], al         ; save al into memory

    
    ; ----- This Part related to Analog Clock -----
    mov ch, [rtc_hour]
    mov cl, [rtc_min]
    mov dh, [rtc_sec]

    mov [BCD_H], ch             ; save ch into memory
    mov [BCD_M], cl             ; save cl into memory
    mov [BCD_S], dh             ; save dh into memory
    
    mov al, ch
    call BCD2HEX
    mov [HEX_H], al
    
    mov al, cl
    call BCD2HEX
    mov [HEX_M], al
    
    mov al, dh
    call BCD2HEX
    mov [HEX_S], al


    mov bp, [mode_counter]
    cmp bp, 0       ; analog only
    je  .analogStart
    cmp bp, 1       ; digital only
    jne .mix
    mov bx, 3                   ; Starting x position
    mov dx, 100                 ; Starting y position
    jmp .displayDigi
.mix:
    mov bx, 3                   ; Starting x position
    mov dx, 170                 ; Starting y position

.displayDigi:
    ; Display Hour
    mov ah, 0x00                ; clear_digit
    call write_digit_width_4        ; empty digit in this position
    mov al, 02                  ; color
    mov ah, [currentH0]         ; digit
    call write_digit_width_4

    add bx, 5                   ; Shifting x position
    mov ah, 0x00
    call write_digit_width_4
    mov ah, [currentH1]         ; digit
    call write_digit_width_4

    add bx, 5
    call two_dots
    
    add bx, 2                   ; Shifting x position
    mov ah, 0x00
    call write_digit_width_4
    mov ah, [currentM0]         ; digit
    call write_digit_width_4

    add bx, 5                   ; Shifting x position
    mov ah, 0x00
    call write_digit_width_4
    mov ah, [currentM1]         ; digit
    call write_digit_width_4

    add bx, 5
    call two_dots
    
    add bx, 2                   ; Shifting x position
    mov ah, 0x00
    call write_digit_width_4
    mov ah, [currentS0]         ; digit
    call write_digit_width_4

    add bx, 5                   ; Shifting x position
    mov ah, 0x00
    call write_digit_width_4
    mov ah, [currentS1]         ; digit
    call write_digit_width_4
    
    mov bp, [mode_counter]
    cmp bp, 2       ; analog + digital Simple
    je  .analogStart
 
    ; Display Month
    mov bx, 3                   ; Starting x position
    add dx, 45                 ; Starting y position
    mov ah, 0x00                ; clear_digit
    call write_digit_width_5    ; empty digit in this position
    mov al, 02                  ; color
    mov ah, [currentT0]         ; digit
    call write_digit_width_5

    add bx, 6                   ; Shifting x position
    mov ah, 0x00
    call write_digit_width_5
    mov ah, [currentT1]         ; digit
    call write_digit_width_5

    add bx, 6                   ; Shifting x position
    mov ah, 0x00
    call write_digit_width_5
    mov ah, [currentT2]         ; digit
    call write_digit_width_5

    add bx, 1                   ; Space

    ; Display Day
    add bx, 6                   ; Shifting x position
    mov ah, 0x00                ; clear_digit
    call write_digit_width_4    ; empty digit in this position
    mov al, 02                  ; color
    mov ah, [currentD0]         ; digit
    call write_digit_width_4

    add bx, 5                   ; Shifting x position
    mov ah, 0x00
    call write_digit_width_4
    mov ah, [currentD1]         ; digit
    call write_digit_width_4

    ; Display Week
    mov bx, 3                   ; Starting x position
    add dx, 45                 ; Starting y position
    mov ah, 0x00                ; clear_digit
    call write_digit_width_5        ; empty digit in this position
    mov al, 02                  ; color
    mov ah, [currentW0]         ; digit
    call write_digit_width_5

    add bx, 6                   ; Shifting x position
    mov ah, 0x00
    call write_digit_width_5
    mov ah, [currentW1]         ; digit
    call write_digit_width_5

    add bx, 1                   ; Space

    ; Display Year
    add bx, 6                   ; Shifting x position
    mov ah, 0x00                ; clear_digit
    call write_digit_width_4        ; empty digit in this position
    mov al, 02                  ; color
    mov ah, [currentY0]         ; digit
    call write_digit_width_4

    add bx, 5                   ; Shifting x position
    mov ah, 0x00
    call write_digit_width_4
    mov ah, [currentY1]         ; digit
    call write_digit_width_4

    add bx, 5                   ; Shifting x position
    mov ah, 0x00
    call write_digit_width_4
    mov ah, [currentY2]         ; digit
    call write_digit_width_4

    add bx, 5                   ; Shifting x position
    mov ah, 0x00
    call write_digit_width_4
    mov ah, [currentY3]         ; digit
    call write_digit_width_4

    mov bp, [mode_counter]
    cmp bp, 1       ; Digital only
    je  .am_pm

    ;//)))))))))))))))))))))))))))))))))))))
    ;// Start The Analog Clock
    ;//)))))))))))))))))))))))))))))))))))))
.analogStart:

    mov dword [X0], 20
    cmp bp, 0       ; analog only
    jne .upClock
    mov dword [Y0], 160
    mov dword [radius], 17
    jmp .draw_clock
.upClock:
    mov dword [Y0], 100
    mov dword [radius], 16
.draw_clock:
    ; create a clock face (you may not need it as long as the clockColor is Black)
    mov bx, [X0]                ;Xcenter
    mov dx, [Y0]                ;Yccenter
    mov al, 01                  ;Black Color
    mov bp, 18                  ;Radius
    ;call create_disc           ;Draw filled circle IBM method

    ;jmp .skipDraw
    
    ; Create the dots around the clock
    mov si, [radius]
    mov di, 60
    mov al, 02                  ; light Green=0xA light Cyan=0xB, light Pink=0xC light Purple= 0xD Light Yellow=0xE
    call createDotsCircle

    ;// notice i intentionally makes the hands up side down cause
    ;// i wanted the long hands not to cover the short ones since i have not added thikness to the lines
    ;// so i put the seconds hands on the lower layer then the min then the hours on the upper
    ;// while in the normal clocks it is the other way

    call makingHoursHand

    call makingMinutesHand

    call makingSecondsHand

    ;//)))))))))))))))))))))))))))))))))))))
    ;// Start AM/PM & Pin
    ;//)))))))))))))))))))))))))))))))))))))
.am_pm:
    mov bp, [mode_counter]
    cmp  bp, 3
    jne   .centerAMPM
    call  draw_a_p
    jmp   .drawCenter
.centerAMPM:
    cmp  bp, 2
    jne  .above
    call draw_am_pm_below       ; draw the AM / PM Sign
    jmp  .drawCenter
.above:
    call draw_am_pm             ; draw the AM / PM Sign

.drawCenter:
    mov bp, [mode_counter]
    cmp  bp, 1
    je  .skipDraw
    mov bx, [X0]
    mov dx, [Y0]
    mov al, 02                  ; Light Purple
    call draw_center_dot

.skipDraw:
    ret

;-------------------------------------
;
;Making Hours Hand
;
;-------------------------------------
makingHoursHand:
    pusha

    mov al, [HEX_H]
    cmp al, [prevHEX_H]
    je  .skipClearH
    
    ; Clear old Hours Hand
    ;[X0] Xcenter
    ;[Y0] Yccenter
    mov bx, [prevDistHorX]
    mov dx, [prevDistHorY]
    mov [X1], bx
    mov [Y1], dx
    mov al, 01      ; Black
    mov ah, 5       ; thikness as dot 3-5-7
    call draw_line
    
.skipClearH:
    
    ;Adjust Hours Number to Location
    mov al, [HEX_H]             ; Load the hour Number into AL
    mov bl, 05                  ; every 1 hour reflect 5 min on Clock location
    mul bl                      ; bl * al and the result in ax
    ; at this point hours hand is stick at the hour number
    ; even if the min hand changes
    ; next we add the effect of the min Hand
    mov dl, al                  ; save al
    mov al, [HEX_M]             ; Load the Min Number into AL
    xor ah, ah
    mov bl, 12                  ; 60 min / 12 hours every 12 min the hour hand mov 1 tick
    div bl                      ; al / 12 => al & ah the fraction
    add dl, al                  ; add the min effect to the hour count
    mov al, dl                  ; put the new value of the hour habd in al
    
    mov [HEX_H], al
    mov [prevHEX_H], al ; save HEX_H to prevHEX_H
    
    ; Load Hour Hand Distination Point X , Y
    ; Y = (r * sin((n+45) * 6 * (pi/180)) + YCenter  rounded to integers
    ; X = (r * cos((n+45) * 6 * (pi/180)) + XCenter  rounded to integers
    
    add al, 45          ; Adjust n rotation 45º more
    cmp al, 60
    jl .continueH       ; make sure the result less than 60
    sub al, 60          ; else subtract 60 from result and it would be like back to zero
    
.continueH:
    mov [dbStore], al
    call db2dd          ; convert al Hours into ddStore for FPU Calc
    mov ax, 10
    mov [radius], ax    ; set Hours Hand Radius (Length)
    call sec2Loc        ;convertSecToLoc
    
    mov ax, [Y1]
    mov [prevDistHorY], ax      ; Save a copy to clear with next loop
    
    mov ax, [X1]             ; as X1 is Word size we put 00AL
    mov [prevDistHorX], ax      ; Save a copy to clear with next loop
    
    ; Draw The Hours Hand
    ;[X0] => Xcenter
    ;[Y0] => Yccenter
    ;[X1] => Xdist
    ;[Y1] => Ydist
    mov al, 02      ; white
    mov ah, 5       ; thikness as dot 3-5-3
    call draw_line

    popa
    ret

;-------------------------------------
;
;Making Minutes Hand
;
;-------------------------------------
makingMinutesHand:
    pusha

    mov al, [HEX_M]
    cmp al, [prevHEX_M]
    je  .skipClearM
    
    ; Clear old Min Hand
    ;[X0] Xcenter
    ;[Y0] Yccenter
    mov bx, [prevDistMinX]
    mov dx, [prevDistMinY]
    mov [X1], bx
    mov [Y1], dx
    mov al, 01      ; Black
    mov ah, 3       ; thikness as dot 1-3-1
    call draw_line
    
.skipClearM:
    mov al, [HEX_M]
    mov [prevHEX_M], al ; save HEX_M to prevHEX_M
    
    ; Load Sec Hand Distination Point X , Y
    ; Y = (r * sin((n+45) * 6 * (pi/180)) + YCenter  rounded to integers
    ; X = (r * cos((n+45) * 6 * (pi/180)) + XCenter  rounded to integers
    
    add al, 45          ; Adjust n rotation 45º more
    cmp al, 60
    jl .continueM       ; make sure the result less than 60
    sub al, 60          ; else subtract 60 from result and it would be like back to zero
    
.continueM:
    mov [dbStore], al
    call db2dd          ; convert al seocnds into ddStore for FPU Calc
    mov ax, 14          ; was 90
    mov [radius], ax    ; set Minutes Hand Radius (Length)
    call sec2Loc        ;convertSecToLoc
    
    mov ax, [Y1]
    mov [prevDistMinY], ax      ; Save a copy to clear with next loop
    
    mov ax, [X1]             ; as X1 is Word size we put 00AL
    mov [prevDistMinX], ax      ; Save a copy to clear with next loop
    
    ; Draw The Seconds Hand
    ;[X0] => Xcenter
    ;[Y0] => Yccenter
    ;[X1] => Xdist
    ;[Y1] => Ydist
    mov al, 02      ; white
    mov ah, 3       ; thikness as dot 1-3-1
    call draw_line
    
    popa
    ret

;-------------------------------------
;
;Making Seconds Hand
;
;-------------------------------------
makingSecondsHand:
    pusha

    mov al, [HEX_S]
    cmp al, [prevHEX_S]
    je  .skipClearS
    
    ; Clear old Sec Hand
    ;[X0] Xcenter
    ;[Y0] Yccenter
    mov bx, [prevDistSecX]
    mov dx, [prevDistSecY]
    mov [X1], bx
    mov [Y1], dx
    mov al, 01      ; Black
    mov ah, 0       ; No thikness
    call draw_line
    
.skipClearS:
    mov al, [HEX_S]
    mov [prevHEX_S], al ; save HEX_S to prevHEX_S
    
    ; Load Sec Hand Distination Point X , Y
    ; Y = (r * sin((n+45) * 6 * (pi/180)) + YCenter  rounded to integers
    ; X = (r * cos((n+45) * 6 * (pi/180)) + XCenter  rounded to integers
    
    add al, 45          ; Adjust n rotation 45º more
    cmp al, 60
    jl .continueS       ; make sure the result less than 60
    sub al, 60          ; else subtract 60 from result and it would be like back to zero
    
.continueS:
    mov [dbStore], al
    call db2dd          ; convert al seocnds into ddStore for FPU Calc
    mov ax, 16          ; was 95
    mov [radius], ax    ; set Seconds Hand Radius (Length)
    call sec2Loc        ;convertSecToLoc
    
    mov ax, [Y1]
    mov [prevDistSecY], ax      ; Save a copy to clear with next loop
    
    mov ax, [X1]             ; as X1 is Word size we put 00AL
    mov [prevDistSecX], ax      ; Save a copy to clear with next loop
    
    ; Draw The Seconds Hand
    ;[X0] => Xcenter
    ;[Y0] => Yccenter
    ;[X1] => Xdist
    ;[Y1] => Ydist
    mov al, 02      ; white
    mov ah, 0       ; no thikness
    call draw_line

    popa
    ret


;-------------------------------------
; Assume BCD_NUM contains the 8-bit packed BCD number (e.g., 52H for decimal 52)
; AL = input BCD Number
; Result will be stored in AL
;-------------------------------------
 BCD2HEX:
    ; Isolate and process the Most Significant Digit (MSD)
    push bx
    push cx
    push dx
    mov ah, al        ; Copy al to ah
    and al, 0x0f      ; Isolate the lower nibble (units digit)
    mov cl, al        ; save al
    shr ah, 4         ; Shift ah right by 4 to get the upper nibble (tens digit)
    mov al, ah        ; the multiplier
    mov bl, 10        ; Load 10 into bl for multiplication
    mul bl            ; Multiply al (tens digit) by 10. Result in ax (ah:al)
    add al, cl        ; Add the units digit (from original AL) to the result in AL
    mov ah, 0         ; result in al
    pop dx
    pop cx
    pop bx
    ret

;-------------------------------------
; convert seconds into locations on the rim of the Clock
; to be used as an end point for drawing a line from center
; x = Center x + [r * cos(n * Øº)]
; y = Center y + [r * sin(n * Øº)]
;   Inputs
; [X0]  = Center x 20
; [Y0]  = Center y 100
; [sAngle] = Øº 6º * (pi/180)
; [radius] = r  19
; [ddStore] = n (0..59)
;   Output
; [fResult] = n * Øº
; [X1] = x
; [Y1] = y
;-------------------------------------
sec2Loc:
    pusha                       ; Push All Save ALL
    
    ; n * Øº
    fld dword [sAngle]          ; float point load - Load sAngle into ST(0) = Øº
    fild dword [ddStore]        ; fpu integer load - Load secCounter into ST(0) = n & push segmentAngle to ST(1) = Øº)
    fmul                        ; Multiply ST(0) by ST(1), result in ST(0), pop ST(1) Now ST(0) = n * Øº
    fstp dword [fResult]        ; Store n * Øº to memory and pop ST(0)

    ; cos(n * Øº)
    fld dword [fResult]         ; result has n * Øº we just calculate so let ST(0) = n * Øº
    fcos                        ; Calculate cos(ST(0)) and Store it in ST(0)

    ; r * cos(n * Øº)
    fild word [radius]          ; Load radius into ST(0) & push ST(0) to ST(1)
    fmul                        ; Multiply ST(0) by ST(1), result in ST(0), pop ST(1) Now ST(0) = r * cos(n * Øº)
    fstp dword [ddStore]        ; output to X1
    
    ;add X center location to the ddStore 160
    fld dword [ddStore]
    fild word [X0]              ; ST(0) = 160, ST(1) = [ddStore]
    fadd                        ; ST(0) = ST(0) + ST(1), ST(1) is now empty
    fstp dword [ddStore]        ; Store ST(0) into [ddStore], pop ST(0)

    ; float2Int for [X1]
    fld dword [ddStore]         ; Load the double-precision float onto ST(0)
    fistp word [dwStore]        ; Convert ST(0) to integer
    mov bx, [dwStore]
    mov [X1], bx

    ; sin(n * Øº)
    fld dword [fResult]         ; still the result has n * Øº so ST(0) = n * Øº
    fsin                        ; Calculate sin(ST(0)) and Store it in ST(0)

    ; r * sin(n * Øº)
    fild word [radius]          ; Load radius into ST(0) & push ST(0) to ST(1)
    fmul                        ; Multiply ST(0) by ST(1), result in ST(0), pop ST(1) Now ST(0) = r * sin(n * Øº)
    fstp dword [ddStore]        ; output to Y1

    ; APPLY VERTICAL STRETCH HERE
    fld dword [ddStore]
    fild word [y_multiplier]    ; Load our scaling factor
    fmul                        ; Multiply Y component by scale
    fstp dword [ddStore]        ; Store ST(0) into [ddStore], pop ST(0)

    ;add Y center location to the ddStore 100
    fld dword [ddStore]
    fild word [Y0]              ; ST(0) = 100, ST(1) = [ddStore]
    fadd                        ; ST(0) = ST(0) + ST(1), ST(1) is now empty
    fstp dword [ddStore]        ; Store ST(0) into [ddStore], pop ST(0)

    ; Float2Int for [Y1]
    fld dword [ddStore]         ; Load the double-precision float onto ST(0)
    fistp word [dwStore]        ; Convert ST(0) to integer
    mov dx, [dwStore]
    mov [Y1], dx
    
    popa                        ; Pop All Restore All
    ret

;-------------------------------------
; convert db Integer into dd Float
;   Inputs
; [dbStore] = Byte defined Buffer
;   Output
; [ddStore] = Double word defined Buffer
;-------------------------------------
db2dd:
    pusha
    mov al, [dbStore]
    mov byte [ddStore], al
    mov byte [ddStore + 1], 0
    mov byte [ddStore + 2], 0
    mov byte [ddStore + 3], 0
    popa
    ret

;-------------------------------------
; convert dd Float into db Integer (considering the dd is less than 0x000000ff [255])
;   Inputs
; [ddStore] = Double word defined Buffer
;   Output
; [dbStore] = Byte defined Buffer
;-------------------------------------
dd2db:
    pusha
    fld dword [ddStore]           ; Load the double-precision float onto ST(0)
    fistp dword [ddStore]         ; Convert ST(0) to integer
    mov ax, word [ddStore]
    mov [dbStore], al       ; take the byte from the AX
    popa
    ret

;-------------------------------------
; convert dw Integer into dd Float
;   Inputs
; [dwStore] = Word defined Buffer
;   Output
; [ddStore] = Double word defined Buffer
;-------------------------------------
dw2dd:
    pusha
    mov ax, [dwStore]
    mov byte [ddStore], al
    mov byte [ddStore + 1], ah
    mov byte [ddStore + 2], 0
    mov byte [ddStore + 3], 0
    popa
ret

;-------------------------------------
; convert dd Float into dw Integer (considering the dd is less than 0x0000ffff [65535])
;   Inputs
; [ddStore] = Double word defined Buffer
;   Output
; [dwStore] = Word defined Buffer
;-------------------------------------
dd2dw:
    pusha
    fld dword [ddStore]           ; Load the double-precision float onto ST(0)
    fistp dword [ddStore]         ; Convert ST(0) to integer
    mov ax, word [ddStore]
    mov [dwStore], aX       ; take the byte from the AX
    popa
    ret

;-------------------------------------
; Bresenham Algorithm
; [X0] = StartX X0
; [X1] = EndX X1
; [Y0] = StartY Y0
; [Y1] = EndY Y1
; al = Color
; ah = Thickenes
;-------------------------------------
draw_line:
    pusha                           ;ax=x0,bx=x1,dl=y0,dh=y1,cl=col

    mov bx, [X0]
    mov [.newX], bx
    mov bx, [Y0]
    mov [.newY], bx

    xor si, si
    mov si,[X1]
    sub si,[X0]                     ; si = ∆X = X1 - X0 (distance on X Axis)) fits 32k
                                    ; ex. X1 = 32000 X0 = 0 (32000 - 0) = 32000 = 0x7d00 (16bit)
    xor di, di
    mov di, [Y1]
    sub di,[Y0]                     ; di = ∆Y = Y1 - Y0 (distance on Y Axis) fits 32k
                                    ; ex. Y1 = 32000 Y0 = 0 (32000 - 0) = 32000 = 0x7d00 (16bit)

        ; Start Assesment the Line Slope And direction
    xor bx, bx
    mov bx, 1                       ; Xi = X Axis index one pixel increase/decrease 1 = increase -1 = decrease
    xor dx, dx
    mov dx, 1                       ; Yi = X Axis index one pixel increase/decrease 1 = increase -1 = decrease

    mov word [.Sl], 1               ; SL is set to Positive Slope  Slope Direction (Default is Positive) 1 = Positive, 0 = Negative

    cmp  si, 0x8000                 ; This to get ABS(∆X) (make it positive if its negative value fits 32K+ Resolution)
    jb   .r0                        ; if ∆X is already positive value so we targeting >>> RIGHT <<< go to r0
                                    ; else (if ∆X is negative) so we targeting >>> LEFT <<<
    neg  si                         ; make si = ABS(∆X) Correct it to Positive again Aka distance on X Axis
    neg  bx                         ; make bx = -1/0 also make sure that AX has changed into X DECREMENTAL index
 .r0:
    cmp  di, 0x8000                 ; This to get ABS(∆Y) (make it positive if its negative value fits 32K+ Resolution)
    jb   .r1                        ; if ∆Y is already positive value so we targeting >>> DOWN <<< go to r1
                                    ; else (if ∆Y is negative) so we targeting >>> UP <<<
    neg  di                         ; make di = ABS(∆Y) Correct it to Positive again Aka distance on Y Axis
    neg  dx                         ; make dx = -1/0 make sure that dx has changed into Y DECREMENTAL index
 .r1:
    cmp  si, di                     ; Compare ABS(∆X) with ABS(∆Y (distance on Y Axis to distance on Y Axis)
                                    ; to get the slope direction (Positive / Negative)
    ja   .r2                        ; if ABS(∆X) > ABS(∆Y) So it is >>> POSITIVE <<< slope
                                    ; So Keep AX As Horizontal Index and BX As Vertical Index and go to r2

    xchg bx, dx                     ; else if it is >>> NEGATIVE <<< Slope so exchange Xi with Yi -> bx with dx
    xchg si, di                     ; and exchange also ∆X with ∆Y si, di
                                    ; hint: Positive Slope where the Line angel with X Axis is smaller than its angel with Y Axis
                                    ; as if its leaning more to X Axis and far from Y Axis
                                    ; Negative Slope where the Line angel with Y Axis is smaller then its angel with X Axis
                                    ; as if its leaning more to Y Axis and far from Y Axis
                                    ; check photos below for negative and positive slopes in all directions
     mov word [.Sl], 0              ; SL is set to Negative Slope 0 = Negative


        ;   POSITIVE Slope SL = 1 Conditions (ABS(∆X) > ABS(∆Y)         ;   NEGATIVE Slope SL = 0 Conditions (ABS(∆Y) ≥ ABS(∆X)
        ;               Çº < Øº Line lean to X                          ;            Øº ≤ Çº Line lean to Y
        ;                          -Y                                   ;                       -Y
        ;  bx = -(Xi), dx = -(Yi)   |  bx = Xi, dx = -(Yi)              ;               .        |        .
        ;                           |                                   ;                .       |       .
        ;                           |                                   ;  dx = -(Xi),    .      |      .  dx = Xi,
        ;       -(∆X) & -(∆Y)       |     +∆X & -(∆Y)                   ;  bx = -(Yi)      .     |     .   bx = -(Yi)
        ;   .                       |                       .           ;                   .    |    .
        ;         .                 |                 .                 ;                    .   |   .
        ;               .           | Øº        .                       ;                     .  |Øº.
        ;                     .     |     .                             ;   -(∆X) & -(∆Y)      . | .      +∆X & -(∆Y)
        ;                          .|.    Çº                            ;                       .|. Ç
        ;-X ------------------------|----------------------- +X         ;-X ---------------------|---------------------- +X
        ;                          .|.    Çº                            ;                       .|. Çº
        ;                     .     |     .                             ;                      . | .
        ;               .           |  Øº       .                       ;    dx = -(Xi),      .  |Øº.       dx = Xi,
        ;         .                 |                 .                 ;    bx = Yi         .   |   .      bx = Yi
        ;   .                       |                       .           ;                   .    |    .
        ;                           |                                   ;                  .     |     .
        ;   bx = -(Xi), dx = Yi     |   bx = Xi, dx = Yi                ;                 .      |      .
        ;                           |                                   ;   -(∆X) & +∆Y  .       |       .   +∆X & +∆Y
        ;       -(∆X) & +∆Y         |       +∆X & +∆Y                   ;               .        |        .
        ;                          +Y                                   ;                       +Y

 .r2:
        ; Drawing loop starts here after assesment of the line condition (slope, direction etc.)
    mov  [.ct], si                  ; .ct = save si what ever it is ∆X or if slope is negative ∆Y
    xor cx, cx                      ; make sure cx start at 0

 .l0:
        ; Draw Point According to Thikness
    push bx                        ; main point draw
    push dx
    mov  bx, [.newX]
    mov  dx, [.newY]
    cmp  ah, 3                      ; code for normal thickness Hand
    jz   .t3
    cmp  ah, 5                      ; code for a thick Hand
    jz   .t5
    cmp  ah, 7                      ; code for a Heavy thickening Hand
    jz   .t7
    call draw_point
    jmp .t0

    ; Line thickening
 .t3:
    call draw_diamond_4
    jmp  .t0
 .t5:
    call draw_diamond_6
    jmp  .t0
 .t7:
    call draw_diamond_8
 .t0:
    pop dx
    pop bx

    cmp word [.Sl], 1               ; Check Slope Direction
    jnz .flip2Y
    add [.newX], bx                 ; if Positive Slope
    jmp .cont
.flip2Y:
    add [.newY], bx                 ; if Negative Slope

.cont:
    sub cx, di                      ; Sub cx (starts at 0 1st loop) - ∆Y/∆X according to the ABS results
    jnc .r3                         ; if no carry so it is still within ∆X scope so draw anothe horizontal X Pixel at same row
    add cx, si                      ; else (if there is a carry) so it is out of ∆X (the screen width) so you go to next row
                                    ; add the dx with the ∆X/∆Y according to the ABS results but since is has a carry
                                    ; so it is definatly ∆Y so next pixel have to be on a new raw
    cmp word [.Sl], 1               ; Check Slope Direction
    jnz .flip2X
    add [.newY], dx
    jmp .r3
.flip2X:
    add [.newX], dx                 ; if egative Slope

 .r3:
    dec word [.ct]                  ; decrease the ∆Y/∆X according to the ABS results untill its zero
    jnz .l0                         ; loop for next pixel draw
    popa
    ret


 .ct:               dw 0            ; Internal Buffer to save ∆ values
 .newX:             dw 0
 .newY:             dw 0
 .Sl:               dw 0            ; Slope Direction (Default is Positive) 1 = Positive, 0 = Negative



;-------------------------------------------------------------------------------------------------------------
; Draw A line using FPU Triangility
; we get the angle of the line from the X Axis
; then we draw a dot on the rim of circle around the center (X0, Y0) using the angle
; then we repeat thease dots with different circle radiuses
; untill the radius became more than the length of the line
; [X0] = StartX X0 (center X0)
; [X1] = EndX X1
; [Y0] = StartY Y0 (center Y0)
; [Y1] = EndY Y1
; al = Color
; ah = Thikness
;-------------------------------------------------------------------------------------------------------------
draw_line_b:

        ;
        ;                             ∆X                X = X0 + [r * cos(Çº)]
        ;                       -Y (X1-X0)              Y = Y0 + [r * sin(Çº)]
        ;                        |<------>. (X1, Y1)
        ;                        |       .^
        ;                        |      . |
        ;                        |     .  |
        ;                        |    .   |  ∆Y (Y1 - Y0)
        ;                        |   .    |
        ;                        |  .     |
        ;                        | .      |
        ;                        |. Çº    v Çº = ATAN2(∆X, ∆Y)
        ;-X ---------------------|---------------------- +X
        ;                (X0, Y0)|
        ;                        | 1- get ∆`s
        ;                        | 2- get Çº
        ;                        | 3- get length √[∆X² + ∆Y²]
        ;                        | 4- get (X, Y) Positions At radius (r) = 0
        ;                        |     X = X0 + [r * cos(Çº)]
        ;                        |     Y = Y0 + [r * sin(Çº)]
        ;                        | 5- increase radius (r) and draw a dot at (X, Y)
        ;                        | 6- repeat from step 4 untill radius (r) is above Length
        ;                       +Y

    pusha
        mov bx, [X0]
        mov word [.X0], bx
        mov bx, [Y0]
        mov word [.Y0], bx
        mov bx, [X1]
        mov word [.X1], bx
        mov bx, [Y1]
        mov word [.Y1], bx

        ; 1st: we get the Deltas ∆X, ∆Y (distance between X1 and X0 , Y1 And Y0)
        ; ΔX = X1 - X0
        ; ΔY = Y1 - Y0
    
    ; Calculate ΔX = X1 - X0
    fild dword [.X1]                ; Load X1 as Integer
    fild dword [.X0]                ; Load X0 as Integer
    fsub                            ; ΔX = X1 - X0
    fistp dword [.∆X]               ; Store ΔX in buffer as Integer and clear st0

    ; Calculate ΔY = Y1 - Y0
    fild dword [.Y1]                ; Load Y1 as Integer
    fild dword [.Y0]                ; Load Y0 as Integer
    fsub                            ; ΔY = Y1 - Y0
    fistp dword [.∆Y]               ; Store ΔY in buffer as Integer and clear st0

        ; 2nd: get the line length  To have the Maximum radius of the invisible circles we draw a dot on each
        ; Length=√[∆X² +∆Y²]
 
    ; Calculate ∆X²
    fild dword [.∆X]                ; Load ΔX st0 as Integer
    fild dword [.∆X]                ; push ∆X to st1 & Load ΔX st0 as Integer
    fmul                            ; ΔX² st0 = (mul st0, st1)
    fistp dword [.tmp]              ; Store ∆X² in temp buffer and clear st0

    ; Calculate ∆Y²
    fild dword [.∆Y]                ; Load ΔY st0 as Integer
    fild dword [.∆Y]                ; push ∆Y to st1 & Load ΔY st0 as Integer
    fmul                            ; ΔY² st0 = (mul st0, st1)

    ; Add ∆X² + ∆Y²
    fild dword [.tmp]               ; push ΔY² to st1 and load ΔX² in st0
    fadd                            ; st0 = ΔX² + ΔY²

    ; Calculate the square root
    fsqrt                           ; st0 = √[∆X² + ∆Y²]

    fistp dword [.l]                ; Convert the length to integer and Store it and clear st0
    
        ; 3rd: get the angel of the line From X Axis
        ; Çº = ATAN2(∆X, ∆Y)
        ; where ∆X = X1 - X0
        ; and   ∆Y = Y1 - Y0
        ; Çº is the angel
        
    ; Load ΔY and ΔX onto the FPU stack
    fild dword [.∆Y]                ; Load ΔY
    fild dword [.∆X]                ; Load ΔX
    fpatan                          ; Compute angle in radians Çº = ATAN2(∆X, ∆Y)

    ; Store the result
    fstp dword [.Çº]                ; Store the result angel (radians) keep it Float ad do not convert to integer for hi resolution

        ; 4th: Draw Loop
        ; using this angel we draw several point from radius 0 to radius max (length of line)
        ;X = X0 + [r * cos(Çº)]
        ;Y = Y0 + [r * sin(Çº)]
        ; where X0,Y0 = center point (start of line)
        ; and   Çº is the angel
        ; r is the radius (change it from 0 to l)
        ; l length of line

    mov word [.r], 0

 .loopdraw:
    ; Load angle into FPU
    fld dword [.Çº]                 ; Load Çº st0
    fcos                            ; Compute cos(Çº) st0 = cos(Çº)

    fild dword [.r]                 ; push cos(Çº) to st1 & Load radius r to st0
    fmul                            ; st0 = r * cos(Çº)

    fild dword [.X0]                ; push r * cos(Çº) to st1 & Load X0 to st0
    fadd                            ; st0 = X0 + [r * cos(Çº)]
    fistp dword [.newX]             ; Store X = X0 + [r * cos(Çº)]

    ; Load angle again for sin(Ç)
    fld dword [.Çº]                 ; Load Ç st0
    fsin                            ; Compute sin(Çº) st0 = sin(Çº)

    fild dword [.r]                 ; push sin(Çº) to st1 & Load radius r to st0
    fmul                            ; st0 = r * sin(Çº)
    
    fild dword [.Y0]                ; push r * sin(Çº) to st1 & Load Y0 to st0
    fadd                            ; st0 = Y0 + [r * cos(Çº)]
    fistp dword [.newY]             ; Store Y = Y0 + [r * sin(Çº)]



        ; Draw Point According to Thikness
    xor bx, bx
    mov bx, word [.newX]
    xor dx, dx
    mov dx, word [.newY]
    cmp  ah, 3                      ; code for seconds Hand
    jz   .t3
    cmp  ah, 5                      ; code for minutes Hand
    jz   .t5
    cmp  ah, 7                      ; code for minutes Hand
    jz   .t7
    call draw_point
    jmp .t0
 .t3:
    call draw_diamond_4
    jmp  .t0
 .t5:
    call draw_diamond_6
    jmp  .t0
 .t7:
    call draw_diamond_8
    jmp .t0
 .t0:
    inc word [.r]                  ; add r + 1 get ready for next point
    
    mov cx, [.l]
    cmp word [.r], cx                   ; check if radius above the length to stop the loop
    jle .loopdraw                   ; else keep looping
    
    popa
    ret
    
 .X0:               dd 0            ; Internet Buffer to save a Word X0 into a Dword
 .X1:               dd 0            ; Internet Buffer to save a Word X1 into a Dword
 .Y0:               dd 0            ; Internet Buffer to save a Word Y0 into a Dword
 .Y1:               dd 0            ; Internet Buffer to save a Word Y1 into a Dword
 .∆X:               dd 0            ; Internal Buffer to save ∆X
 .∆Y:               dd 0            ; Internal Buffer to save ∆Y
 .Çº:               dd 0            ; Internal Buffer to save angel
 .r:                dd 0            ; Internal Buffer to save radius
 .l:                dd 0            ; Internal Buffer to save length
 .newX:             dd 0            ; next point of the line to be draws X
 .newY:             dd 0
 .tmp               dd 0



;-----------------------------
; Draw painted circle
; bx= Xc coordinate center
; dx= Yc coordinate center
; bp= r  radius
; al= colour
;-----------------------------
create_disc:

    ; Circle Drawing Theory:
    ; 1. Symmetry: Circles are symmetric. For any point '(x, y) on the circle,
    ;    there are symmetrical points at '(-x, y), (x, -y), (-x, -y), & (y, x).
    ;
    ; 2. Radius and Extents: In the code, 'Ye' (vertical extent) increases from
    ;    the center of the circle upward and downward, while 'Xe' (horizontal
    ;    extent) decreases as you move further away from the center vertically.
    ;    The relationship between radius 'r', vertical extent 'Ye', and horizontal
    ;    extent 'Xe' is based on the equation of a circle:' x² + y² = r².
    ;    When you increment 'Ye', the corresponding 'Xe' should be reduced to
    ;    maintain the circle`s shape, derived from ' Xe = √(r² - Ye²).
    ;
    ; 3. Why Reduce 'Xe'? As you go higher (or lower) from the center (increasing 'Ye'),
    ;    the maximum horizontal extent 'Xe' decreases. Thus, when drawing the filled
    ;    circle, after hitting certain vertical levels, the radius is adjusted
    ;    downward, and the horizontal extent is reduced to fill the circle correctly.
    ;
    ; This method effectively utilizes the circle's geometry to ensure that as
    ; you draw vertically, you correctly adjust the horizontal extent to maintain
    ; the filled circle shape.
    ;
    ;          0                   Xc - Xe
    ;         ---------------------------------------------------------------------------  X
    ;       0 |               5  4  3  2  1      1  2  3  4  5
    ;         |     🔲 🔲 🔲 🔲 🔲 🔲 🟨 🟨 🟩 ⬛️ ⬛️ 🔲 🔲 🔲 🔲 🔲 🔲  1) r:8 Xe:1 Ye:8 Pc:3 | 2)r:5 Xe:2 Ye:8 Pc:5 (2Xe + 1)
    ;         |     🔲 🔲 🔲 🔲 🟨 🟨 🟩 🟩 🟩 🟩 🟩 ⬛️ ⬛️ 🔲 🔲 🔲 🔲  3) r:15 Xe:3 Ye:7 Pc:7 (2Xe+1) | 4) r:8 Xe:4 Ye:7 Pc:9 (2Xe+1)
    ;         |     🔲 🔲 🔲 🟨 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲 🔲 🔲  5) r:12 Xe:5 Ye:6  Pc:11 (2Xe+1)
    ; Yc - Ye |   5 🔲 🔲 🟪 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲 🔲  5) r:12 Xe:6 Ye:5  Pc:13 (2Xe+1)
    ;         |   4 🔲 🟪 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲  4) r:8 Xe:7 Ye:4   Pc:15 (2Xe+1)
    ;         |   3 🔲 🟪 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲  3) r:15 Xe:7 Ye:3  Pc:15 (2Xe+1)
    ;         |   2 🟪 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️  2) r:5 Xe:8 Ye:2   Pc:17 (2Xe+1)
    ;         |   1 🟪 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️  1) r:8 Xe:8 Ye:1   Pc:17 (2Xe+1)
    ;         |   0 🟫 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟥 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️  0) r:8 Xe:8 Ye:0   Pc:17 (2Xe+1) <======= Start Here
    ;         |   1 🟦 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️  1) r:8 Xe:8 Ye:-1  Pc:17 (2Xe+1)
    ;         |   2 🟦 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️  2) r:5 Xe:8 Ye:-2  Pc:17 (2Xe+1)
    ;         |   3 🔲 🟦 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲  3) r:15 Xe:7 Ye:-3 Pc:15 (2Xe+1)
    ;         |   4 🔲 🟦 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲  4) r:8 Xe:7 Ye:-4  Pc:15 (2Xe+1)
    ;         |   5 🔲 🔲 🟦 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲 🔲  5) r:12 Xe:6 Ye:-5  Pc:13 (2Xe+1)
    ;         |     🔲 🔲 🔲 🟧 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 🟩 ⬛️ 🔲 🔲 🔲  5) r:12 Xe:5 Ye:-6  Pc:11 (2Xe+1)
    ;         |     🔲 🔲 🔲 🔲 🟧 🟧 🟩 🟩 🟩 🟩 🟩 ⬛️ ⬛️ 🔲 🔲 🔲 🔲  3) r:15 Xe:3 Ye:-7 Pc:7 (2Xe+1) | 4) r:8 Xe:4 Ye:7 Pc:9 (2Xe+1)
    ;         |     🔲 🔲 🔲 🔲 🔲 🔲 🟧 🟧 🟩 ⬛️ ⬛️ 🔲 🔲 🔲 🔲 🔲 🔲  1) r:8 Xe:1 Ye:-8 Pc:3 | 2)r:5 Xe:2 Ye:-8 Pc:5 (2Xe+1)
    ;         |               5  4  3  2  1      1  2  3  4  5
    ;         |
    ;         |
    ;         |
    ;         Y
    ;
    ;
    ;   Notes:
    ;   - Start drawing point is Calculated as (Xc - Xe) & (Yc - Ye)
    ;   - Each set is 4 rows, above and below start row then below and above top and bottom rows.
    ;   - init row is a single row set and is always drawn alone before any other rows
    ;   - After draw each set of lines we do this calculations:
    ;           a) is (r - [(2 * Ye) + 1]) > (Ye + 1) and we change r = ( r - [(2 * Ye) + 1]) and Ye = (Ye + 1)
    ;           b) if true do not reduce Xe next loop, if false change Xe and r before next set
    ;           c) we change Xe and r like so r = (r + [(2 * Xe) - 1]) and Xe = (Xe - 1)
    ;   - The length of each line Pc (Pixel count) Calculated as Pc = (2 * Xe) + 1
    ;   - The drawing Should Stop when Xe < Ye So we need to check this in every loop so when it happen we return
    ;   - Exact effect on r, Xe, Ye After drawing every set:
    ;     after 1) r = 5 =>(8-[(2*1)+1]), Ye = 2 => (1+1), Xe = 8 => (5 > 2 so no change)
    ;     after 2) r = 0 =>(5-[(2*2)+1]), Ye = 3 => (2+1), 0 < 3 => we will reduce Xe and change r
    ;              r = 15 =>(0+[2*8]-1]), Xe = 7 => (8-1), Ye = 3 (as it was) (we start loop set 3 with those values)
    ;     after 3) r = 8 =>(15-[(2*3)+1]), Ye = 4 => (3+1), Xe = 7 => (8 > 4 so no change)
    ;     after 4) r = -1 =>(8-[(2*4)+1]), Ye = 5 => (4+1), -1 < 5 => we will reduce Xe and change r
    ;              r = 12 =>((-1)+[2*7]-1]), Xe = 6 => (7-1), Ye = 5 (as it was) (we start loop set 5 with those values)
    ;     after 5) r = 1 =>(12-[(2*5)+1]), Ye = 6 => (5+1), 1 < 5 => we will reduce Xe and change r
    ;              r = 12 =>(1+[2*6]-1]), Xe = 5 => (6-1), Ye = 6 (as it was) (we do not draw anymore as Xe < Ye so we're done)
    ;
    ;    🟥 is the center Pixel of the Filled Circle (Your Start Point) Xc, Yc
    ;    🟫 is the Start of Center Row (1st Row) initial row, not related to other 4 sets drawing rows
    ;    🟪 is the Start of filled Row Upper Part
    ;    🟦 is the Start of filled Row Lower Part
    ;    🟨 is the Start of filled Row inverted Xe, Ye Upper Part
    ;    🟧 is the Start of filled Row inverted Xe, Ye Lower Part
    ;    🟩 is the rest of filled pixels
    ;    ⬛️ is the end Point of each horizontal drawing line

        ; 1st we draw Start Line Center line
    xor  di, di                                                     ; Ye = 0 Ye = Yextent to draw line up and down
    mov  si, bp                                                     ; Xe = Radius Xe = Xextent to draw line left and right
    call .drawLine                                                  ; draw first Horizontal line in the center Y
    
                                                                    ; Xe = Xextent to draw line left and right (r(99) till 1)
                                                                    ; Ye = Yextent to draw line up and down (1 till r(99) )
                                                                    
    mov  di,1                                                       ; start Ye from 1 till r(99)

 .loop:
        ; we draw 4 lines (up,down,top,bottom) all start from left to right
    call .drawUpDown
    xchg si, di         ; si = 0  di = 8                            ; Flipped Xe, Ye  so bp = Xe   si = Ye (to draw top ad bottom)
    call .drawUpDown
    xchg si, di         ; si = 8  di = 0                            ; Flipped bp = Ye   si = Xe (Back to original)
                                                                    ; Ye = radius so every time we increase the Ye with 1
                                                                    ; we change the r like this(r = r - (2 * Ye) + 1)
                                                                    ; example this circle r = 8 - (2 * 1) + 1 = 5

    sub  bp, di         ; 5 - 2 = 3  (Ex: after set 2)              ; r = r - Ye
    inc  di             ; di = 3                                    ; Ye += 1
    sub  bp, di         ; bp = 3 - 3 = 0                            ; r = r - Ye => r = r - (2 * Ye) + 1
    cmp  bp, di         ; bp = 0 di = 3  0 < 3                      ; if r > Ye so it is not yet time to shorten Xe sp lets draw
                                                                    ; 4 more lines with the same Xe extent
    jg   .doNotChangeXe
    
        ; we reduce the X extent (Xe) to draw next set with shorter drawing length
    add  bp, si         ; 0 + 8 = 8 (Ex: after set 2)               ; r = r + Xe
    dec  si             ; si = 7                                    ; Xe -= 1
    add  bp, si         ; 8 + 7 = 15 (start draw set 3)             ; r = r + Xe => r += Xe r = r + (2 * Xe) - 1
    
 .doNotChangeXe:
    cmp  si, di         ; si = 7, di = 3 => 7 > 3                    ; Repeat do another 4 lines until Xe < Ye
    jae  .loop
    ret

 .drawUpDown:
    pusha
    call .drawLine                                                  ; draw up
    neg di                                                          ; draw Down (flip Yn value)
    call .drawLine
    popa
    ret

 .drawLine: ; IN si = Xe di = Ye
    pusha
    sub bx, si       ;bx = 160 - 8 = 152                             ; X = Xc - Xe
    sub dx, di       ;dx = 100 - 1  = 99                             ; Y = Yc - Ye
    mov cx, si                                                       ;
    imul cx, 2
    inc cx                                                           ; Pc = (Xe * 2) + 1 (pixel count to make a row)
    call makeRow
    popa
    
    ret


;-------------------------------------------------------------------------------------------------------------
; Draw A Filled Circle using FPU Trangulation algorithm
; first we draw a dot on the rim of circle around the center (X0, Y0) using the angle of segment = 1 and start r = 0
; X = X0 + [r * cos(Çº)]
; Y = Y0 + [r * sin(Çº)]
; repeat those dots increasing Çº from 0 by adding 1º = 0.01745329 till 2π 3.14 x 2 = 6.28318531 (from 0 till 360 degree)
; when done we increase the circle radius by 1px
; then we repeat thease steps untill radius we apply above desired radius
; bx [X0] = StartX X0 (center X0)
; dx [Y0] = StartY Y0 (center Y0)
; bp [r] =  radius
; al eax = Color ,  al if 8 bit  ax if 16 bit color eax if 32 bit color
;-------------------------------------------------------------------------------------------------------------
draw_pie:
    pusha
    
    mov word [.X0], bx
    mov word [.Y0], dx
    mov word [.r], bp

        ; 1st: Calculate the circumference (how many dots on the surface)
        ; .cf = |r * 2π| + 1
    fld dword [two∏]            ; load 2π in st0
    fild dword [.r]             ; push 2π to st1 and load radius r in st0
    fmul
    fistp dword [.cf]           ; out as integer
    inc word [.cf]
        
        ; 2nd get the segment angel (angel between line connects from center to surface)
        ; .seg = 360 / .cf  and for best accurecy devide the number by 2
        ; .seg = (360 / .cf) / 2
    mov word [.tmp], 360
    fild dword [.tmp]
    fild dword [.cf]
    fdiv
    mov word [.tmp], 2
    fild dword [.tmp]
    fdiv
    fstp dword [.segº]
        
        ; 3rd: circle Loop
        ; using this angel we draw several point at radius 0 at angle 0 then we increase angle
        ; X = X0 + [r * cos(Çº)]
        ; Y = Y0 + [r * sin(Çº)]
        ; where X0,Y0 = center point (start of line)
        ; and Çº is the angel
        ; r is the radius (change it from 0 to length)

    mov word [.ri], 0
    
.loop_circle:
    
    mov dword [.Øº], 0
 
 .loop_dots:
    ; convert degree [.Øº] to radian [.Çº] = Øº * (∏ / 180) = Øº * 57.29577951
    fld dword [∏d]                 ; (∏ / 180) = 0.01745329
    fld dword [.Øº]                 ; push ∏d to s1 and load Øº to s0
    fmul
    fstp dword [.Çº]
     
    ; getting newX and newY
    fld dword [.Çº]                 ; Load Çº st0
    fcos                            ; Compute cos(Çº) st0 = cos(Çº)

    fild dword [.ri]                ; push cos(Çº) to st1 & Load radius r to st0
    fmul                            ; st0 = ri * cos(Çº)

    fild dword [.X0]                ; push r * cos(Çº) to st1 & Load X0 to st0
    fadd                            ; st0 = X0 + [ri * cos(Çº)]
    fistp dword [.newX]             ; Store X = X0 + [ri * cos(Çº)]

    ; Load angle again for sin(Ç)
    fld dword [.Çº]                 ; Load Ç st0
    fsin                            ; Compute sin(Çº) st0 = sin(Çº)

    fild dword [.ri]                ; push sin(Çº) to st1 & Load radius r to st0
    fmul                            ; st0 = r * sin(Çº)
    
    fild dword [.Y0]                ; push r * sin(Çº) to st1 & Load Y0 to st0
    fadd                            ; st0 = Y0 + [r * cos(Çº)]
    fistp dword [.newY]             ; Store Y = Y0 + [r * sin(Çº)]

        ; Draw Point
    mov bx, word [.newX]
    mov dx, word [.newY]
    call draw_point
    
    fld dword [.segº]
    fld dword [.Øº]
    fadd
    fstp dword [.Øº]                    ; Add Øº with segment angel
    
    fld dword [.Øº]
    fistp dword [.comparetor]           ; integer for comparison you cannot compare floats so we make an integer for the compare
    
    cmp word [.comparetor], 360         ; if we complete 360º
    jle  .loop_dots
    
    inc word [.ri]                      ; add r + 1 get ready for next point
    mov cx, word [.r]
    cmp word [.ri], cx                  ; check if radius above the length to stop the loop
    jle .loop_circle                    ; else keep looping

 .end:
    popa
    ret
    
 .X0:               dd 0            ; Internet Buffer to save a Word X0 into a Dword
 .Y0:               dd 0            ; Internet Buffer to save a Word X1 into a Dword
 .Øº:               dd 0.0          ; Internal Buffer to save incremented angel degrees
 .Çº:               dd 0.0          ; Internal Buffer to save incremented angel radians
 .r:                dd 0            ; Internal Buffer to save radius
 .ri:               dd 0            ; Internal Buffer to save incremented radius
 .newX:             dd 0            ; next point of the line to be draws X
 .newY:             dd 0
 .tmp:              dd 0
 .cf:               dd 0            ; |r * two∏| + 1
 .segº:             dd 0.0          ; 360 / number of pixels on the rim of the circles
 .comparetor        dd 0
 



;-----------------------------
; Draw painted circle
; si = radius
; di = count
; al = colour
;-----------------------------
createDotsCircle:
    pusha
    mov cx, 0
    mov [radius], si    ; set Circle Radius

.dotsLoop:
    mov [dbStore], cl   ; starts from 0 then up to 59
    call db2dd          ; convert al seocnds into ddStore for FPU Calc
    call sec2Loc        ; convertSecToLoc

    mov bx, [X1]
    mov dx, [Y1]
    call draw_point
    
    ; get a number that could get no fraction when devided over 5
    cmp cl, 0
    jne .not12
    jmp .big_dot
.not12:
    mov dl, al              ; save al
    mov al, cl              ; copy cl
    xor ah, ah              ; clear ah as it would take the reminder
    mov bl, 5
    div bl                  ; al / 5 => al and the remains in ah if any
    mov al, dl              ; restore al
    cmp ah, 0               ; Compare AH with 0
    jne  .fraction_found    ; if AH is 0, meaning no remainder/no fraction)

.big_dot:
    mov bx, [X1]
    mov dx, [Y1]
    call draw_diamond_4

.fraction_found:
    inc cx
    cmp cx, di          ; cmp to the end
    jl  .dotsLoop

    popa
    ret




;-------------------------------------
; Input:
; al = BCD 2 digit Number
; Return:
; ax = ASCII 2 Digits Number AH & AL
;-------------------------------------
convert_BCD_to_ASCII:
    ; For example AL contains packed BCD 23 (decimal)
    ; meaning AH has 20 and AL has 03 so AX is 2003

    ; Convert MSD (2)
    mov ah, al    ; Copy AL to AH
    shr ah, 4     ; Shift AH right by 4 to get 2 in lower nibble
    add ah, 0x30   ; Convert 2 to ASCII '2' 0x32

    ; Convert LSD (3)
    and al, 0x0f   ; Mask AL to get 3 in lower nibble make sure the 1st 4 digits is 0
    add al, 0x30   ; Convert 3 to ASCII '3' 0x33

    ret
       
    ; Now AH contains ASCII '9' and AL contains ASCII '8'
    ; You can then store these characters in memory or display them.


;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_seg_v:
    push bx
    push dx

    mov cx, 16  ; length of the V Segment, 2 * 8 = 16 considering 40 x 40
    call makeColumn
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_seg_h:
    push bx
    push dx

    mov cx, 3  ; length of the H Segment
    call makeRow

    inc dx      ; go to next row Y
    mov cx, 3   ; length of the H Segment
    call makeRow

    inc dx      ; go to next row Y
    mov cx, 3   ; length of the H Segment
    call makeRow

    inc dx      ; go to next row Y
    mov cx, 3   ; length of the H Segment
    call makeRow

    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_half_seg_h:
    push bx
    push dx

    mov cx, 1  ; length of the H Segment
    call makeRow

    inc dx      ; go to next row Y
    mov cx, 1   ; length of the H Segment
    call makeRow

    inc dx      ; go to next row Y
    mov cx, 1   ; length of the H Segment
    call makeRow

    inc dx      ; go to next row Y
    mov cx, 1   ; length of the H Segment
    call makeRow

    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_seg_t1:
    push bx
    push dx

    mov cx, 8  ; length of the V Segment, 2 * 8 = 16 considering 40 x 40
    call makeColumn

    inc bx
    add dx, 8
    mov cx, 8  ; length of the V Segment, 2 * 8 = 16 considering 40 x 40
    call makeColumn

    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_seg_t2:
    push bx
    push dx

    mov cx, 8  ; length of the V Segment, 2 * 8 = 16 considering 40 x 40
    call makeColumn

    dec bx
    add dx, 8
    mov cx, 8  ; length of the V Segment, 2 * 8 = 16 considering 40 x 40
    call makeColumn

    pop dx
    pop bx
    ret


;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_dot:
    pusha

    mov cx, 8   ; length of the V Segment
    call makeColumn
    
    popa
    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_center_dot:
    pusha
    
    dec bx

    mov cx, 8   ; length of the V Segment
    call makeColumn

    inc bx      ; go to next column X
    mov cx, 8   ; length of the V Segment
    call makeColumn

    popa
    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_diamond_4:
    pusha

    mov cx, 4   ; length of the V Segment
    call makeColumn
    
    popa
    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_diamond_6:
    pusha

    mov cx, 6   ; length of the V Segment
    call makeColumn
    
    popa
    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_diamond_8:
    pusha

    mov cx, 8   ; length of the V Segment
    call makeColumn
    
    popa
    ret


;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
two_dots:
    push dx

    add dx, 4
    call draw_dot

    add dx, 24
    call draw_dot

    pop dx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_a:
    push bx
    push dx

    add bx, 1   ; X += 1
    sub dx, 4   ; Y -= 1 (4)
    call draw_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_b:
    push bx

    add bx, 4       ; X += 1 + 3
    call draw_seg_v
    
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_c:
    push bx
    push dx

    add bx, 4   ; X += 1 + 3
    add dx, 20   ; Y += 0 + 16 + 4
    call draw_seg_v
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_d:
    push bx
    push dx

    add bx, 1     ; X += 1
    add dx, 36    ; Y += (16 * 2) + 4
    call draw_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_e:
    push dx

    add dx, 20   ; Y += 0 + 16 + 4
    call draw_seg_v
    
    pop dx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_f:
    call draw_seg_v
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_g:
    push bx
    push dx

    add bx, 1    ; X += 0 + 1
    add dx, 16   ; Y += 0 + 16
    call draw_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_a1:
    push bx
    push dx

    add bx, 1   ; X += 1
    sub dx, 4   ; Y -= 1 (4)
    call draw_half_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_a2:
    push bx
    push dx

    add bx, 3   ; X += 1 + 2
    sub dx, 4   ; Y -= 1 (4)
    call draw_half_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_d1:
    push bx
    push dx

    add bx, 1     ; X += 1
    add dx, 36    ; Y += (16 * 2) + 4
    call draw_half_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_d2:
    push bx
    push dx

    add bx, 3     ; X += 1 + 3
    add dx, 36    ; Y += (16 * 2) + 4
    call draw_half_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_g1:
    push bx
    push dx

    add bx, 1    ; X += 0 + 1
    add dx, 16   ; Y += 0 + 16
    call draw_half_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_g2:
    push bx
    push dx

    add bx, 3    ; X += 1 + 2
    add dx, 16   ; Y += 0 + 16
    call draw_half_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_h:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    call draw_seg_v
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_i:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    add dx, 20   ; Y += 0 + 16
    call draw_seg_v
    
    pop dx
    pop bx
    ret


;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_j:
    push bx

    add bx, 1    ; X += 0 + 1
    call draw_seg_t1
    
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_k:
    push bx

    add bx, 3    ; X += 0 + 1
    call draw_seg_t2
    
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_l:
    push bx
    push dx

    add bx, 2    ; X += 1 + 1
    add dx, 20   ; Y += 16 + 4
    call draw_seg_t1
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_m:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    add dx, 20   ; Y += 0 + 16
    call draw_seg_t2
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_dot0:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    sub dx, 4    ; Y -= 1 (4)
    call draw_diamond_4
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_dot1:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    add dx, 5    ; Y += 0 + 5
    call draw_diamond_4
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_dot2:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    add dx, 25   ; Y += 0 + 25
    call draw_diamond_4
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_dot3:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    add dx, 34   ; Y += 0 + 34
    call draw_diamond_4
    
    pop dx
    pop bx
    ret



;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
; ah = Number
;-------------------------------------
write_digit_width_5:
    pusha
    
    cmp     ah, 0x00
    jne     .sp
    push    ax     ; if ax 00h clean the 7 segment with black color
    mov     al,01   ; Black color 0.3v for CRT
    call    seg_a
    call    seg_b
    call    seg_c
    call    seg_d
    call    seg_e
    call    seg_f
    call    seg_g
    call    seg_a1
    call    seg_a2
    call    seg_d1
    call    seg_d2
    call    seg_g1
    call    seg_g2
    call    seg_j
    call    seg_k
    call    seg_l
    call    seg_m
    call    seg_h
    call    seg_i
    call    seg_dot0
    call    seg_dot3
    pop     ax
    jmp    .endn

.sp:
    cmp     ah, 0x20
    jne     .ex
    jmp    .endn

.ex:
    cmp     ah, 0x21
    jne     .dq
    call    seg_h
    call    seg_dot2
    jmp    .endn

.dq:
    cmp     ah, 0x22
    jne     .hs
    call    seg_h
    call    seg_b
    jmp    .endn

.hs:
    cmp     ah, 0x23
    jne     .ds
    call    seg_h
    call    seg_b
    call    seg_c
    call    seg_i
    call    seg_g
    call    seg_d
    jmp    .endn

.ds:
    cmp     ah, 0x24
    jne     .pr
    call    seg_a
    call    seg_d
    call    seg_f
    call    seg_g
    call    seg_c
    call    seg_h
    call    seg_i
    jmp    .endn

.pr:
    cmp     ah, 0x25
    jne     .an
    call    seg_a1
    call    seg_d2
    call    seg_f
    call    seg_g1
    call    seg_g2
    call    seg_c
    call    seg_h
    call    seg_i
    call    seg_k
    call    seg_m
    jmp    .endn

.an:
    cmp     ah, 0x26
    jne     .qt
    call    seg_a1
    call    seg_d
    call    seg_j
    call    seg_l
    call    seg_h
    call    seg_g1
    call    seg_e
    jmp    .endn

.qt:
    cmp     ah, 0x27
    jne     .b1
    call    seg_h
    jmp    .endn

.b1:
    cmp     ah, 0x28
    jne     .b2
    call    seg_k
    call    seg_l
    jmp    .endn

.b2:
    cmp     ah, 0x29
    jne     .st
    call    seg_j
    call    seg_m
    jmp    .endn

.st:
    cmp     ah, 0x2A
    jne     .pl
    call    seg_k
    call    seg_l
    call    seg_j
    call    seg_m
    call    seg_g1
    call    seg_g2
    call    seg_h
    call    seg_i
    jmp    .endn

.pl:
    cmp     ah, 0x2B
    jne     .cm
    call    seg_g1
    call    seg_g2
    call    seg_h
    call    seg_i
    jmp    .endn

.cm:
    cmp     ah, 0x2C
    jne     .mi
    call    seg_m
    jmp    .endn

.mi:
    cmp     ah, 0x2D
    jne     .dt
    call    seg_g
    jmp    .endn

.dt:
    cmp     ah, 0x2E
    jne     .sl
    call    seg_dot3
    jmp    .endn

.sl:
    cmp     ah, 0x2F
    jne     .0
    call    seg_k
    call    seg_m
    jmp    .endn
    
.0: cmp     ah, 0x30
    jne     .1
    call    seg_a
    call    seg_b
    call    seg_c
    call    seg_d
    call    seg_e
    call    seg_f
    call    seg_k
    call    seg_m
    jmp    .endn

.1: cmp     ah, 0x31
    jne     .2
    call    seg_b
    call    seg_c
    call    seg_k
    jmp    .endn

.2: cmp     ah, 0x32
    jne     .3
    call    seg_a
    call    seg_b
    call    seg_d
    call    seg_g
    call    seg_e
    jmp    .endn

.3: cmp     ah, 0x33
    jne     .4
    call    seg_a
    call    seg_b
    call    seg_c
    call    seg_d
    call    seg_g
    jmp    .endn

.4: cmp     ah, 0x34
    jne     .5
    call    seg_b
    call    seg_c
    call    seg_g
    call    seg_f
    jmp    .endn

.5: cmp     ah, 0x35
    jne     .6
    call    seg_a
    call    seg_d
    call    seg_f
    call    seg_g
    call    seg_c
    jmp    .endn

.6: cmp     ah, 0x36
    jne     .7
    call    seg_a
    call    seg_c
    call    seg_d
    call    seg_e
    call    seg_f
    call    seg_g
    jmp    .endn
    
.7: cmp     ah, 0x37
    jne     .8
    call    seg_a
    call    seg_b
    call    seg_c
    jmp    .endn
    
.8: cmp     ah, 0x38
    jne     .9
    call    seg_a
    call    seg_b
    call    seg_c
    call    seg_d
    call    seg_e
    call    seg_f
    call    seg_g
    jmp    .endn

.9: cmp     ah, 0x39
    jne     .2d
    call    seg_a
    call    seg_b
    call    seg_c
    call    seg_d
    call    seg_f
    call    seg_g
    jmp    .endn

.2d:
    cmp     ah, 0x3A
    jne     .sc
    call    seg_dot1
    call    seg_dot2
    jmp    .endn

.sc:
    cmp     ah, 0x3B
    jne     .gt
    call    seg_m
    call    seg_dot1
    jmp    .endn

.gt:
    cmp     ah, 0x3C
    jne     .eq
    call    seg_g1
    call    seg_k
    call    seg_l
    jmp    .endn

.eq:
    cmp     ah, 0x3D
    jne     .lt
    call    seg_g
    call    seg_d
    jmp    .endn

.lt:
    cmp     ah, 0x3E
    jne     .qm
    call    seg_g2
    call    seg_j
    call    seg_m
    jmp    .endn

.qm:
    cmp     ah, 0x3F
    jne     .at
    call    seg_a
    call    seg_b
    call    seg_g2
    call    seg_i
    call    seg_dot3
    jmp    .endn

.at:
    cmp     ah, 0x40
    jne     .A
    call    seg_a
    call    seg_b
    call    seg_g2
    call    seg_h
    call    seg_d
    call    seg_e
    call    seg_f
    jmp    .endn

.A: cmp     ah, 0x41
    jne     .B
    call    seg_a
    call    seg_b
    call    seg_c
    call    seg_f
    call    seg_e
    call    seg_g
    jmp    .endn

.B: cmp     ah, 0x42
    jne     .C
    call    seg_a1
    call    seg_a2
    call    seg_b
    call    seg_c
    call    seg_d1
    call    seg_d2
    call    seg_h
    call    seg_i
    call    seg_g2
    jmp    .endn

.C: cmp     ah, 0x43
    jne     .D
    call    seg_a
    call    seg_d
    call    seg_f
    call    seg_e
    jmp    .endn

.D: cmp     ah, 0x44
    jne     .E
    call    seg_a1
    call    seg_a2
    call    seg_b
    call    seg_c
    call    seg_d1
    call    seg_d2
    call    seg_h
    call    seg_i
    jmp    .endn

.E: cmp     ah, 0x45
    jne     .F
    call    seg_a
    call    seg_d
    call    seg_g1
    call    seg_f
    call    seg_e
    jmp    .endn

.F: cmp     ah, 0x46
    jne     .G
    call    seg_a
    call    seg_g1
    call    seg_f
    call    seg_e
    jmp    .endn

.G: cmp     ah, 0x47
    jne     .H
    call    seg_a
    call    seg_c
    call    seg_d
    call    seg_e
    call    seg_f
    call    seg_g2
    jmp    .endn

.H: cmp     ah, 0x48
    jne     .I
    call    seg_b
    call    seg_c
    call    seg_e
    call    seg_f
    call    seg_g
    jmp    .endn

.I: cmp     ah, 0x49
    jne     .J
    call    seg_h
    call    seg_i
    call    seg_a
    call    seg_d
    jmp    .endn

.J: cmp     ah, 0x4A
    jne     .K
    call    seg_b
    call    seg_c
    call    seg_d
    call    seg_e
    jmp    .endn

.K: cmp     ah, 0x4B
    jne     .L
    call    seg_k
    call    seg_l
    call    seg_g1
    call    seg_e
    call    seg_f
    jmp    .endn

.L: cmp     ah, 0x4C
    jne     .M
    call    seg_d
    call    seg_e
    call    seg_f
    jmp    .endn

.M: cmp     ah, 0x4D
    jne     .N
    call    seg_b
    call    seg_c
    call    seg_e
    call    seg_f
    call    seg_j
    call    seg_k
    jmp    .endn

.N: cmp     ah, 0x4E
    jne     .O
    call    seg_b
    call    seg_c
    call    seg_e
    call    seg_f
    call    seg_j
    call    seg_l
    jmp    .endn

.O: cmp     ah, 0x4F
    jne     .P
    call    seg_a
    call    seg_b
    call    seg_c
    call    seg_d
    call    seg_e
    call    seg_f
    jmp    .endn

.P: cmp     ah, 0x50
    jne     .Q
    call    seg_a
    call    seg_b
    call    seg_e
    call    seg_f
    call    seg_g
    jmp    .endn

.Q: cmp     ah, 0x51
    jne     .R
    call    seg_a
    call    seg_b
    call    seg_c
    call    seg_d
    call    seg_e
    call    seg_f
    call    seg_l
    jmp    .endn

.R: cmp     ah, 0x52
    jne     .S
    call    seg_a
    call    seg_b
    call    seg_l
    call    seg_f
    call    seg_e
    call    seg_g
    jmp    .endn

.S: cmp     ah, 0x53
    jne     .T
    call    seg_a
    call    seg_c
    call    seg_d
    call    seg_j
    call    seg_g2
    jmp    .endn

.T: cmp     ah, 0x54
    jne     .U
    call    seg_a
    call    seg_h
    call    seg_i
    jmp    .endn

.U: cmp     ah, 0x55
    jne     .V
    call    seg_b
    call    seg_c
    call    seg_d
    call    seg_e
    call    seg_f
    jmp    .endn

.V: cmp     ah, 0x56
    jne     .W
    call    seg_k
    call    seg_m
    call    seg_f
    call    seg_e
    jmp    .endn

.W: cmp     ah, 0x57
    jne     .X
    call    seg_b
    call    seg_c
    call    seg_e
    call    seg_f
    call    seg_l
    call    seg_m
    jmp    .endn

.X: cmp     ah, 0x58
    jne     .Y
    call    seg_j
    call    seg_k
    call    seg_l
    call    seg_m
    jmp    .endn

.Y: cmp     ah, 0x59
    jne     .Z
    call    seg_b
    call    seg_c
    call    seg_d
    call    seg_f
    call    seg_g
    jmp    .endn

.Z: cmp     ah, 0x5A
    jne     .b3
    call    seg_a
    call    seg_k
    call    seg_m
    call    seg_d
    jmp    .endn

.b3:
    cmp     ah, 0x5B
    jne     .dh
    call    seg_a2
    call    seg_h
    call    seg_i
    call    seg_d2
    jmp    .endn

.dh:
    cmp     ah, 0x5C
    jne     .b4
    call    seg_j
    call    seg_l
    jmp    .endn

.b4:
    cmp     ah, 0x5D
    jne     .eb
    call    seg_a1
    call    seg_h
    call    seg_i
    call    seg_d1
    jmp    .endn

.eb:
    cmp     ah, 0x5E
    jne     .us
    call    seg_l
    call    seg_m
    jmp    .endn
.us:
    cmp     ah, 0x5F
    jne     .co
    call    seg_d
    jmp    .endn

.co:
    cmp     ah, 0x60
    jne     .a
    call    seg_j
    jmp    .endn

.a: cmp     ah, 0x61
    jne     .b
    call    seg_i
    call    seg_g1
    call    seg_e
    call    seg_d1
    call    seg_d2
    jmp    .endn

.b: cmp     ah, 0x62
    jne     .c
    call    seg_f
    call    seg_e
    call    seg_g1
    call    seg_d1
    call    seg_i
    jmp    .endn

.c: cmp     ah, 0x63
    jne     .d
    call    seg_g1
    call    seg_d1
    call    seg_e
    jmp    .endn

.d: cmp     ah, 0x64
    jne     .e
    call    seg_b
    call    seg_c
    call    seg_g2
    call    seg_d2
    call    seg_i
    jmp    .endn

.e: cmp     ah, 0x65
    jne     .f
    call    seg_g1
    call    seg_m
    call    seg_e
    call    seg_d1
    jmp    .endn

.f: cmp     ah, 0x66
    jne     .g
    call    seg_a2
    call    seg_h
    call    seg_i
    call    seg_g1
    call    seg_g2
    jmp    .endn

.g: cmp     ah, 0x67
    jne     .h
    call    seg_a1
    call    seg_h
    call    seg_i
    call    seg_d1
    call    seg_g1
    call    seg_f
    jmp    .endn

.h: cmp     ah, 0x68
    jne     .i
    call    seg_i
    call    seg_g1
    call    seg_e
    call    seg_f
    jmp    .endn

.i: cmp     ah, 0x69
    jne     .j
    call    seg_i
    call    seg_dot1
    jmp    .endn

.j: cmp     ah, 0x6A
    jne     .k
    call    seg_h
    call    seg_i
    call    seg_d1
    call    seg_e
    call    seg_dot0
    jmp    .endn

.k: cmp     ah, 0x6B
    jne     .l
    call    seg_k
    call    seg_i
    call    seg_g1
    call    seg_e
    call    seg_f
    jmp    .endn

.l: cmp     ah, 0x6C
    jne     .m
    call    seg_e
    call    seg_f
    jmp    .endn

.m: cmp     ah, 0x6D
    jne     .n
    call    seg_c
    call    seg_e
    call    seg_i
    call    seg_g1
    call    seg_g2
    jmp    .endn

.n: cmp     ah, 0x6E
    jne     .o
    call    seg_e
    call    seg_i
    call    seg_g1
    jmp    .endn

.o: cmp     ah, 0x6F
    jne     .p
    call    seg_e
    call    seg_i
    call    seg_g1
    call    seg_d1
    jmp    .endn

.p: cmp     ah, 0x70
    jne     .q
    call    seg_a1
    call    seg_h
    call    seg_e
    call    seg_f
    call    seg_g1
    jmp    .endn

.q: cmp     ah, 0x71
    jne     .r
    call    seg_a1
    call    seg_g1
    call    seg_f
    call    seg_h
    call    seg_i
    jmp    .endn

.r: cmp     ah, 0x72
    jne     .s
    call    seg_g1
    call    seg_e
    jmp    .endn

.s: cmp     ah, 0x73
    jne     .t
    call    seg_a1
    call    seg_f
    call    seg_d1
    call    seg_i
    call    seg_g1
    jmp    .endn

.t: cmp     ah, 0x74
    jne     .u
    call    seg_g1
    call    seg_d1
    call    seg_e
    call    seg_f
    jmp    .endn

.u: cmp     ah, 0x75
    jne     .v
    call    seg_i
    call    seg_d1
    call    seg_e
    jmp    .endn

.v: cmp     ah, 0x76
    jne     .w
    call    seg_m
    call    seg_e
    jmp    .endn

.w: cmp     ah, 0x77
    jne     .x
    call    seg_c
    call    seg_e
    call    seg_l
    call    seg_m
    jmp    .endn

.x: cmp     ah, 0x78
    jne     .y
    call    seg_j
    call    seg_k
    call    seg_l
    call    seg_m
    jmp    .endn

.y: cmp     ah, 0x79
    jne     .z
    call    seg_h
    call    seg_i
    call    seg_d1
    call    seg_f
    call    seg_g1
    jmp    .endn

.z: cmp     ah, 0x7A
    jne     .b5
    call    seg_g1
    call    seg_m
    call    seg_d
    jmp    .endn

.b5: cmp     ah, 0x7B
    jne     .br
    call    seg_a2
    call    seg_d2
    call    seg_g1
    call    seg_h
    call    seg_i
    jmp    .endn

.br: cmp     ah, 0x7C
    jne     .b6
    call    seg_h
    call    seg_i
    jmp    .endn

.b6: cmp     ah, 0x7D
    jne     .wa
    call    seg_a1
    call    seg_d1
    call    seg_g2
    call    seg_h
    call    seg_i
    jmp    .endn

.wa: cmp     ah, 0x7E
    jne     .a_s
    call    seg_k
    call    seg_g
    call    seg_m
    jmp    .endn

.a_s: cmp     ah, 0x7F
    jne     .noCanDo
    call    seg_e
    call    seg_f
    call    seg_a1
    call    seg_h
    call    seg_g1
    call    seg_i
    jmp    .endn

.noCanDo:
    call    seg_b
    call    seg_c
    call    seg_e
    call    seg_f
    call    seg_a
    call    seg_d
    call    seg_g
    call    seg_h
    call    seg_i
    call    seg_j
    call    seg_k
    call    seg_l
    call    seg_m
    
.endn:
    popa
    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_seg_s_h:
    push bx
    push dx

    mov cx, 2  ; length of the H Segment
    call makeRow

    inc dx      ; go to next row Y
    mov cx, 2   ; length of the H Segment
    call makeRow

    inc dx      ; go to next row Y
    mov cx, 2   ; length of the H Segment
    call makeRow

    inc dx      ; go to next row Y
    mov cx, 2   ; length of the H Segment
    call makeRow

    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_seg_s_t1:

    mov cx, 8  ; length of the V Segment, 2 * 8 = 16 considering 40 x 40
    call makeColumn

    ret

;-------------------------------------
; bx = StartX
; dx = StartY
; al = Color
;-------------------------------------
draw_seg_s_t2:

    mov cx, 8  ; length of the V Segment, 2 * 8 = 16 considering 40 x 40
    call makeColumn

    ret


;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_a:
    push bx
    push dx

    add bx, 1   ; X += 1
    sub dx, 4   ; Y -= 1 (4)
    call draw_seg_s_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_b:
    push bx

    add bx, 3       ; X += 1 + 2
    call draw_seg_v
    
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_c:
    push bx
    push dx

    add bx, 3   ; X += 1 + 2
    add dx, 20   ; Y += 0 + 16 + 4
    call draw_seg_v
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_d:
    push bx
    push dx

    add bx, 1     ; X += 1
    add dx, 36    ; Y += (16 * 2) + 4
    call draw_seg_s_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_e:
    push dx

    add dx, 20   ; Y += 0 + 16 + 4
    call draw_seg_v
    
    pop dx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_f:
    call draw_seg_v
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_g:
    push bx
    push dx

    add bx, 1    ; X += 0 + 1
    add dx, 16   ; Y += 0 + 16
    call draw_seg_s_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_a1:
    push bx
    push dx

    add bx, 1   ; X += 1
    sub dx, 4   ; Y -= 1 (4)
    call draw_half_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_a2:
    push bx
    push dx

    add bx, 2   ; X += 1 + 1
    sub dx, 4   ; Y -= 1 (4)
    call draw_half_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_d1:
    push bx
    push dx

    add bx, 1     ; X += 1
    add dx, 36    ; Y += (16 * 2) + 4
    call draw_half_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_d2:
    push bx
    push dx

    add bx, 2     ; X += 1 + 1
    add dx, 36    ; Y += (16 * 2) + 4
    call draw_half_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_g1:
    push bx
    push dx

    add bx, 1    ; X += 0 + 1
    add dx, 16   ; Y += 0 + 16
    call draw_half_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_g2:
    push bx
    push dx

    add bx, 2    ; X += 1 + 1
    add dx, 16   ; Y += 0 + 16
    call draw_half_seg_h
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_h:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    call draw_seg_v
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_i:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    add dx, 20   ; Y += 0 + 16
    call draw_seg_v
    
    pop dx
    pop bx
    ret


;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_j:
    push bx

    add bx, 1    ; X += 0 + 1
    call draw_seg_s_t1
    
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_k:
    push bx

    add bx, 2    ; X += 1 + 1
    call draw_seg_s_t2
    
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_l:
    push bx
    push dx

    add bx, 2    ; X += 1 + 1
    add dx, 28   ; Y += 16 + 4
    call draw_seg_s_t1
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_m:
    push bx
    push dx

    add bx, 1    ; X += 0 + 1
    add dx, 28   ; Y += 0 + 16
    call draw_seg_s_t2
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_dot0:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    sub dx, 4    ; Y -= 1 (4)
    call draw_diamond_4
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_dot1:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    add dx, 5    ; Y += 0 + 5
    call draw_diamond_4
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_dot2:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    add dx, 25   ; Y += 0 + 25
    call draw_diamond_4
    
    pop dx
    pop bx
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
;-------------------------------------
seg_s_dot3:
    push bx
    push dx

    add bx, 2    ; X += 0 + 1
    add dx, 34   ; Y += 0 + 34
    call draw_diamond_4
    
    pop dx
    pop bx
    ret


;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
; ah = Number
;-------------------------------------
write_digit_width_4:
    pusha
    
    cmp     ah, 0x00
    jne     .sp
    push    ax     ; if ax 00h clean the 7 segment with black color
    mov     al,01   ; Black color 0.3v for CRT
    call    seg_s_a
    call    seg_s_b
    call    seg_s_c
    call    seg_s_d
    call    seg_s_e
    call    seg_s_f
    call    seg_s_g
    call    seg_s_a1
    call    seg_s_a2
    call    seg_s_d1
    call    seg_s_d2
    call    seg_s_g1
    call    seg_s_g2
    call    seg_s_j
    call    seg_s_k
    call    seg_s_l
    call    seg_s_m
    call    seg_s_h
    call    seg_s_i
    call    seg_s_dot0
    call    seg_s_dot3
    pop     ax
    jmp    .endn

.sp:
    cmp     ah, 0x20
    jne     .ex
    jmp    .endn

.ex:
    cmp     ah, 0x21
    jne     .dq
    call    seg_s_h
    call    seg_s_dot2
    jmp    .endn

.dq:
    cmp     ah, 0x22
    jne     .hs
    call    seg_s_h
    call    seg_s_b
    jmp    .endn

.hs:
    cmp     ah, 0x23
    jne     .ds
    call    seg_s_h
    call    seg_s_b
    call    seg_s_c
    call    seg_s_i
    call    seg_s_g
    call    seg_s_d
    jmp    .endn

.ds:
    cmp     ah, 0x24
    jne     .pr
    call    seg_s_a
    call    seg_s_d
    call    seg_s_f
    call    seg_s_g
    call    seg_s_c
    call    seg_s_h
    call    seg_s_i
    jmp    .endn

.pr:
    cmp     ah, 0x25
    jne     .an
    call    seg_s_a1
    call    seg_s_d2
    call    seg_s_f
    call    seg_s_g1
    call    seg_s_g2
    call    seg_s_c
    call    seg_s_h
    call    seg_s_i
    call    seg_s_k
    call    seg_s_m
    jmp    .endn

.an:
    cmp     ah, 0x26
    jne     .qt
    call    seg_s_a1
    call    seg_s_d
    call    seg_s_j
    call    seg_s_l
    call    seg_s_h
    call    seg_s_g1
    call    seg_s_e
    jmp    .endn

.qt:
    cmp     ah, 0x27
    jne     .b1
    call    seg_s_h
    jmp    .endn

.b1:
    cmp     ah, 0x28
    jne     .b2
    call    seg_s_k
    call    seg_s_l
    jmp    .endn

.b2:
    cmp     ah, 0x29
    jne     .st
    call    seg_s_j
    call    seg_s_m
    jmp    .endn

.st:
    cmp     ah, 0x2A
    jne     .pl
    call    seg_s_k
    call    seg_s_l
    call    seg_s_j
    call    seg_s_m
    call    seg_s_g1
    call    seg_s_g2
    call    seg_s_h
    call    seg_s_i
    jmp    .endn

.pl:
    cmp     ah, 0x2B
    jne     .cm
    call    seg_s_g1
    call    seg_s_g2
    call    seg_s_h
    call    seg_s_i
    jmp    .endn

.cm:
    cmp     ah, 0x2C
    jne     .mi
    call    seg_s_m
    jmp    .endn

.mi:
    cmp     ah, 0x2D
    jne     .dt
    call    seg_s_g
    jmp    .endn

.dt:
    cmp     ah, 0x2E
    jne     .sl
    call    seg_s_dot3
    jmp    .endn

.sl:
    cmp     ah, 0x2F
    jne     .0
    call    seg_s_k
    call    seg_s_m
    jmp    .endn
    
.0: cmp     ah, 0x30
    jne     .1
    call    seg_s_a
    call    seg_s_b
    call    seg_s_c
    call    seg_s_d
    call    seg_s_e
    call    seg_s_f
    call    seg_s_k
    call    seg_s_m
    jmp    .endn

.1: cmp     ah, 0x31
    jne     .2
    call    seg_s_b
    call    seg_s_c
    call    seg_s_k
    jmp    .endn

.2: cmp     ah, 0x32
    jne     .3
    call    seg_s_a
    call    seg_s_b
    call    seg_s_d
    call    seg_s_g
    call    seg_s_e
    jmp    .endn

.3: cmp     ah, 0x33
    jne     .4
    call    seg_s_a
    call    seg_s_b
    call    seg_s_c
    call    seg_s_d
    call    seg_s_g
    jmp    .endn

.4: cmp     ah, 0x34
    jne     .5
    call    seg_s_b
    call    seg_s_c
    call    seg_s_g
    call    seg_s_f
    jmp    .endn

.5: cmp     ah, 0x35
    jne     .6
    call    seg_s_a
    call    seg_s_d
    call    seg_s_f
    call    seg_s_g
    call    seg_s_c
    jmp    .endn

.6: cmp     ah, 0x36
    jne     .7
    call    seg_s_a
    call    seg_s_c
    call    seg_s_d
    call    seg_s_e
    call    seg_s_f
    call    seg_s_g
    jmp    .endn
    
.7: cmp     ah, 0x37
    jne     .8
    call    seg_s_a
    call    seg_s_b
    call    seg_s_c
    jmp    .endn
    
.8: cmp     ah, 0x38
    jne     .9
    call    seg_s_a
    call    seg_s_b
    call    seg_s_c
    call    seg_s_d
    call    seg_s_e
    call    seg_s_f
    call    seg_s_g
    jmp    .endn

.9: cmp     ah, 0x39
    jne     .2d
    call    seg_s_a
    call    seg_s_b
    call    seg_s_c
    call    seg_s_d
    call    seg_s_f
    call    seg_s_g
    jmp    .endn

.2d:
    cmp     ah, 0x3A
    jne     .sc
    call    seg_s_dot1
    call    seg_s_dot2
    jmp    .endn

.sc:
    cmp     ah, 0x3B
    jne     .gt
    call    seg_s_m
    call    seg_s_dot1
    jmp    .endn

.gt:
    cmp     ah, 0x3C
    jne     .eq
    call    seg_s_g1
    call    seg_s_k
    call    seg_s_l
    jmp    .endn

.eq:
    cmp     ah, 0x3D
    jne     .lt
    call    seg_s_g
    call    seg_s_d
    jmp    .endn

.lt:
    cmp     ah, 0x3E
    jne     .qm
    call    seg_s_g2
    call    seg_s_j
    call    seg_s_m
    jmp    .endn

.qm:
    cmp     ah, 0x3F
    jne     .at
    call    seg_s_a
    call    seg_s_b
    call    seg_s_g2
    call    seg_s_i
    call    seg_s_dot3
    jmp    .endn

.at:
    cmp     ah, 0x40
    jne     .A
    call    seg_s_a
    call    seg_s_b
    call    seg_s_g2
    call    seg_s_h
    call    seg_s_d
    call    seg_s_e
    call    seg_s_f
    jmp    .endn

.A: cmp     ah, 0x41
    jne     .B
    call    seg_s_a
    call    seg_s_b
    call    seg_s_c
    call    seg_s_f
    call    seg_s_e
    call    seg_s_g
    jmp    .endn

.B: cmp     ah, 0x42
    jne     .C
    call    seg_s_a1
    call    seg_s_a2
    call    seg_s_b
    call    seg_s_c
    call    seg_s_d1
    call    seg_s_d2
    call    seg_s_h
    call    seg_s_i
    call    seg_s_g2
    jmp    .endn

.C: cmp     ah, 0x43
    jne     .D
    call    seg_s_a
    call    seg_s_d
    call    seg_s_f
    call    seg_s_e
    jmp    .endn

.D: cmp     ah, 0x44
    jne     .E
    call    seg_s_a1
    call    seg_s_a2
    call    seg_s_b
    call    seg_s_c
    call    seg_s_d1
    call    seg_s_d2
    call    seg_s_h
    call    seg_s_i
    jmp    .endn

.E: cmp     ah, 0x45
    jne     .F
    call    seg_s_a
    call    seg_s_d
    call    seg_s_g1
    call    seg_s_f
    call    seg_s_e
    jmp    .endn

.F: cmp     ah, 0x46
    jne     .G
    call    seg_s_a
    call    seg_s_g1
    call    seg_s_f
    call    seg_s_e
    jmp    .endn

.G: cmp     ah, 0x47
    jne     .H
    call    seg_s_a
    call    seg_s_c
    call    seg_s_d
    call    seg_s_e
    call    seg_s_f
    call    seg_s_g2
    jmp    .endn

.H: cmp     ah, 0x48
    jne     .I
    call    seg_s_b
    call    seg_s_c
    call    seg_s_e
    call    seg_s_f
    call    seg_s_g
    jmp    .endn

.I: cmp     ah, 0x49
    jne     .J
    call    seg_s_h
    call    seg_s_i
    call    seg_s_a
    call    seg_s_d
    jmp    .endn

.J: cmp     ah, 0x4A
    jne     .K
    call    seg_s_b
    call    seg_s_c
    call    seg_s_d
    call    seg_s_e
    jmp    .endn

.K: cmp     ah, 0x4B
    jne     .L
    call    seg_s_k
    call    seg_s_i
    call    seg_s_g1
    call    seg_s_e
    call    seg_s_f
    jmp    .endn

.L: cmp     ah, 0x4C
    jne     .M
    call    seg_s_d
    call    seg_s_e
    call    seg_s_f
    jmp    .endn

.M: cmp     ah, 0x4D
    jne     .N
    call    seg_s_b
    call    seg_s_c
    call    seg_s_e
    call    seg_s_f
    call    seg_s_j
    call    seg_s_k
    jmp    .endn

.N: cmp     ah, 0x4E
    jne     .O
    call    seg_s_b
    call    seg_s_c
    call    seg_s_e
    call    seg_s_f
    call    seg_s_j
    call    seg_s_l
    jmp    .endn

.O: cmp     ah, 0x4F
    jne     .P
    call    seg_s_a
    call    seg_s_b
    call    seg_s_c
    call    seg_s_d
    call    seg_s_e
    call    seg_s_f
    jmp    .endn

.P: cmp     ah, 0x50
    jne     .Q
    call    seg_s_a
    call    seg_s_b
    call    seg_s_e
    call    seg_s_f
    call    seg_s_g
    jmp    .endn

.Q: cmp     ah, 0x51
    jne     .R
    call    seg_s_a
    call    seg_s_b
    call    seg_s_c
    call    seg_s_d
    call    seg_s_e
    call    seg_s_f
    call    seg_s_l
    jmp    .endn

.R: cmp     ah, 0x52
    jne     .S
    call    seg_s_a
    call    seg_s_b
    call    seg_s_l
    call    seg_s_f
    call    seg_s_e
    call    seg_s_g
    jmp    .endn

.S: cmp     ah, 0x53
    jne     .T
    call    seg_s_a
    call    seg_s_c
    call    seg_s_d
    call    seg_s_j
    call    seg_s_g2
    jmp    .endn

.T: cmp     ah, 0x54
    jne     .U
    call    seg_s_a
    call    seg_s_h
    call    seg_s_i
    jmp    .endn

.U: cmp     ah, 0x55
    jne     .V
    call    seg_s_b
    call    seg_s_c
    call    seg_s_d
    call    seg_s_e
    call    seg_s_f
    jmp    .endn

.V: cmp     ah, 0x56
    jne     .W
    call    seg_s_k
    call    seg_s_m
    call    seg_s_f
    call    seg_s_e
    jmp    .endn

.W: cmp     ah, 0x57
    jne     .X
    call    seg_s_b
    call    seg_s_c
    call    seg_s_e
    call    seg_s_f
    call    seg_s_l
    call    seg_s_m
    jmp    .endn

.X: cmp     ah, 0x58
    jne     .Y
    call    seg_s_j
    call    seg_s_k
    call    seg_s_l
    call    seg_s_m
    jmp    .endn

.Y: cmp     ah, 0x59
    jne     .Z
    call    seg_s_b
    call    seg_s_c
    call    seg_s_d
    call    seg_s_f
    call    seg_s_g
    jmp    .endn

.Z: cmp     ah, 0x5A
    jne     .b3
    call    seg_s_a
    call    seg_s_k
    call    seg_s_m
    call    seg_s_d
    jmp    .endn

.b3:
    cmp     ah, 0x5B
    jne     .dh
    call    seg_s_a2
    call    seg_s_h
    call    seg_s_i
    call    seg_s_d2
    jmp    .endn

.dh:
    cmp     ah, 0x5C
    jne     .b4
    call    seg_s_j
    call    seg_s_l
    jmp    .endn

.b4:
    cmp     ah, 0x5D
    jne     .eb
    call    seg_s_a1
    call    seg_s_h
    call    seg_s_i
    call    seg_s_d1
    jmp    .endn

.eb:
    cmp     ah, 0x5E
    jne     .us
    call    seg_s_l
    call    seg_s_m
    jmp    .endn
.us:
    cmp     ah, 0x5F
    jne     .co
    call    seg_s_d
    jmp    .endn

.co:
    cmp     ah, 0x60
    jne     .a
    call    seg_s_j
    jmp    .endn

.a: cmp     ah, 0x61
    jne     .b
    call    seg_s_i
    call    seg_s_g1
    call    seg_s_e
    call    seg_s_d1
    call    seg_s_d2
    jmp    .endn

.b: cmp     ah, 0x62
    jne     .c
    call    seg_s_f
    call    seg_s_e
    call    seg_s_g1
    call    seg_s_d1
    call    seg_s_i
    jmp    .endn

.c: cmp     ah, 0x63
    jne     .d
    call    seg_s_g1
    call    seg_s_d1
    call    seg_s_e
    jmp    .endn

.d: cmp     ah, 0x64
    jne     .e
    call    seg_s_b
    call    seg_s_c
    call    seg_s_g2
    call    seg_s_d2
    call    seg_s_i
    jmp    .endn

.e: cmp     ah, 0x65
    jne     .f
    call    seg_s_g1
    call    seg_s_m
    call    seg_s_e
    call    seg_s_d1
    jmp    .endn

.f: cmp     ah, 0x66
    jne     .g
    call    seg_s_a2
    call    seg_s_h
    call    seg_s_i
    call    seg_s_g1
    call    seg_s_g2
    jmp    .endn

.g: cmp     ah, 0x67
    jne     .h
    call    seg_s_a1
    call    seg_s_h
    call    seg_s_i
    call    seg_s_d1
    call    seg_s_g1
    call    seg_s_f
    jmp    .endn

.h: cmp     ah, 0x68
    jne     .i
    call    seg_s_i
    call    seg_s_g1
    call    seg_s_e
    call    seg_s_f
    jmp    .endn

.i: cmp     ah, 0x69
    jne     .j
    call    seg_s_i
    call    seg_s_dot1
    jmp    .endn

.j: cmp     ah, 0x6A
    jne     .k
    call    seg_s_h
    call    seg_s_i
    call    seg_s_d1
    call    seg_s_e
    call    seg_s_dot0
    jmp    .endn

.k: cmp     ah, 0x6B
    jne     .l
    call    seg_s_k
    call    seg_s_l
    call    seg_s_h
    call    seg_s_i
    jmp    .endn

.l: cmp     ah, 0x6C
    jne     .m
    call    seg_s_e
    call    seg_s_f
    jmp    .endn

.m: cmp     ah, 0x6D
    jne     .n
    call    seg_s_c
    call    seg_s_e
    call    seg_s_i
    call    seg_s_g1
    call    seg_s_g2
    jmp    .endn

.n: cmp     ah, 0x6E
    jne     .o
    call    seg_s_e
    call    seg_s_i
    call    seg_s_g1
    jmp    .endn

.o: cmp     ah, 0x6F
    jne     .p
    call    seg_s_e
    call    seg_s_i
    call    seg_s_g1
    call    seg_s_d1
    jmp    .endn

.p: cmp     ah, 0x70
    jne     .q
    call    seg_s_a1
    call    seg_s_h
    call    seg_s_e
    call    seg_s_f
    call    seg_s_g1
    jmp    .endn

.q: cmp     ah, 0x71
    jne     .r
    call    seg_s_a1
    call    seg_s_g1
    call    seg_s_f
    call    seg_s_h
    call    seg_s_i
    jmp    .endn

.r: cmp     ah, 0x72
    jne     .s
    call    seg_s_g1
    call    seg_s_e
    jmp    .endn

.s: cmp     ah, 0x73
    jne     .t
    call    seg_s_a1
    call    seg_s_f
    call    seg_s_d1
    call    seg_s_i
    call    seg_s_g1
    jmp    .endn

.t: cmp     ah, 0x74
    jne     .u
    call    seg_s_g1
    call    seg_s_d1
    call    seg_s_e
    call    seg_s_f
    jmp    .endn

.u: cmp     ah, 0x75
    jne     .v
    call    seg_s_i
    call    seg_s_d1
    call    seg_s_e
    jmp    .endn

.v: cmp     ah, 0x76
    jne     .w
    call    seg_s_m
    call    seg_s_e
    jmp    .endn

.w: cmp     ah, 0x77
    jne     .x
    call    seg_s_c
    call    seg_s_e
    call    seg_s_l
    call    seg_s_m
    jmp    .endn

.x: cmp     ah, 0x78
    jne     .y
    call    seg_s_j
    call    seg_s_k
    call    seg_s_l
    call    seg_s_m
    jmp    .endn

.y: cmp     ah, 0x79
    jne     .z
    call    seg_s_h
    call    seg_s_i
    call    seg_s_d1
    call    seg_s_f
    call    seg_s_g1
    jmp    .endn

.z: cmp     ah, 0x7A
    jne     .b5
    call    seg_s_g1
    call    seg_s_m
    call    seg_s_d1
    jmp    .endn

.b5: cmp     ah, 0x7B
    jne     .br
    call    seg_s_a2
    call    seg_s_d2
    call    seg_s_g1
    call    seg_s_h
    call    seg_s_i
    jmp    .endn

.br: cmp     ah, 0x7C
    jne     .b6
    call    seg_s_h
    call    seg_s_i
    jmp    .endn

.b6: cmp     ah, 0x7D
    jne     .wa
    call    seg_s_a1
    call    seg_s_d1
    call    seg_s_g2
    call    seg_s_h
    call    seg_s_i
    jmp    .endn

.wa: cmp     ah, 0x7E
    jne     .noCanDo
    call    seg_s_k
    call    seg_s_g
    call    seg_s_m
    jmp    .endn

.noCanDo:
    call    seg_s_b
    call    seg_s_c
    call    seg_s_e
    call    seg_s_f
    call    seg_s_a
    call    seg_s_d
    call    seg_s_g
    call    seg_s_h
    call    seg_s_i
    call    seg_s_j
    call    seg_s_k
    call    seg_s_l
    call    seg_s_m
    
.endn:
    popa
    ret



;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; [ampm] = AM/PM Condition in text Ascii
;-------------------------------------
draw_a_p:
    pusha

    mov bx, 2           ; Row (16)
    mov dx, 50           ; Column (13)

    mov al, [ampm]
    cmp al, 0x00
    jnz .drawP

    mov ah, 0x00                ; clear_digit
    call write_digit_width_5    ; empty digit in this position
    mov al, 02                  ; color
    mov ah,0x7F                 ; digit 'A' special
    call write_digit_width_5
    jmp .end

.drawP:
    mov ah, 0x00                ; clear_digit
    call write_digit_width_5    ; empty digit in this position
    mov al, 02                  ; color
    mov ah,'p'                  ; digit
    call write_digit_width_5

.end:
    popa
    ret


;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; [ampm] = AM/PM Condition in text Ascii
;-------------------------------------
draw_am_pm:
    pusha

    mov bx, 14           ; Row (16)
    mov dx, 50           ; Column (13)

    mov al, [ampm]
    cmp al, 0x00
    jnz .drawP

    mov ah, 0x00                ; clear_digit
    call write_digit_width_5    ; empty digit in this position
    mov al, 02                  ; color
    mov ah,'A'                  ; digit
    call write_digit_width_5
    jmp .drawM

.drawP:
    mov ah, 0x00                ; clear_digit
    call write_digit_width_5    ; empty digit in this position
    mov al, 02                  ; color
    mov ah,'P'                  ; digit
    call write_digit_width_5

.drawM:
    mov bx, 22
    mov dx, 50                  ; Column (13)
    mov ah, 0x00                ; clear_digit
    call write_digit_width_5    ; empty digit in this position
    mov al, 02                  ; color
    mov ah,'M'                  ; digit
    call write_digit_width_5

    popa
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; [ampm] = AM/PM Condition in text Ascii
;-------------------------------------
draw_am_pm_below:
    pusha

    mov bx, 14           ; Row (16)
    mov dx, 250           ; Column (13)

    mov al, [ampm]
    cmp al, 0x00
    jnz .drawP

    mov ah, 0x00                ; clear_digit
    call write_digit_width_5    ; empty digit in this position
    mov al, 02                  ; color
    mov ah,'A'                  ; digit
    call write_digit_width_5
    jmp .drawM

.drawP:
    mov ah, 0x00                ; clear_digit
    call write_digit_width_5    ; empty digit in this position
    mov al, 02                  ; color
    mov ah,'P'                  ; digit
    call write_digit_width_5

.drawM:
    mov bx, 22
    mov dx, 250                  ; Column (13)
    mov ah, 0x00                ; clear_digit
    call write_digit_width_5    ; empty digit in this position
    mov al, 02                  ; color
    mov ah,'M'                  ; digit
    call write_digit_width_5

    popa
    ret

;-------------------------------------
; bx = StartX for the 7 Segment Module (from left)
; dx = StartY for the 7 Segment Module (from top)
; al = Color
; [string] = AM/PM Condition in text Ascii
;-------------------------------------
draw_TwoDigits:
    pusha

    mov dh, 0x4           ; DH=Row (13h)
    mov dl, 0x13           ; DL=Column (20h)

    ; set cursor to Right
    mov ah, 0x02           ; AH=02h (set cursor)
    mov bh, 0x00           ; BH=Page (0)
    int 10h

    mov bl, 0x04            ; color red
    push bx
    mov ah, 0x0e            ; teletype Print character in GFX mode 13h
    mov al, 0x50            ; "P"
    mov bh, 0x00            ; page number 0
    int 10h
    pop bx

    mov ah, 0x0e            ; teletype Print character in GFX mode 13h
    mov al, 0x4d            ; "M"
    mov bh, 0x00            ; page number 0
    int 10h

    popa
    ret
    
;-------------------------------------
; print_string
; di = [string]
; cl = color
; Output is ASCII Presentation of the string
;-------------------------------------
print_string:
    pusha
    mov si, di              ; address of text
    mov ah, 0x0E            ; BIOS Teletype output function
    mov bl, cl              ; color green
    mov bh, 0x00            ; page number 0

.loop:
    lodsb            ; Load byte from SI into AL, increment SI
    cmp al, 0        ; Check for null terminator
    je .done
    int 0x10         ; Call BIOS video interrupt
    jmp .loop
.done:
    popa
    ret

    
;----------------------------------------------------------------
; Assume ax contains the 16-bit hexadecimal value (0x00 - 0xffff)
; Destination buffer for 4-bytes ASCII string: 'outputHex' (4 ASCII)
; Input: ax
; Output: [outputHex]
;----------------------------------------------------------------
Hex2Ascii:
    pusha

    ; empty the output buffer

    mov si, 4
.empty:
    lea bx, [outputHex]
    add bx, si
    mov byte [bx], 0x30
    dec si
    jns .empty

    mov di, ax                          ; Copy RAX to RDI for processing
    mov si, 4                           ; Counter for 16 digits (0 to 15) x 2
.loop:
    mov dx, di                          ; Copy current value to RDX
    and dx, 0xF                         ; Isolate the least significant nibble
    lea bx, [HEX_TO_ASCII_TABLE]
    add bx, dx
    mov cl, [bx]                        ; Get Ascii character from table

    lea bx, [outputHex]
    add bx, si
    mov byte [bx], cl                   ; store Ascii at the 1st byte
    shr di, 4                           ; Shift di right by 4 bits to process the next nibble
    dec si
    jns .loop                           ; Continue if counter is not negative (all 31 digits processed)
    
    popa

    ret

    HEX_TO_ASCII_TABLE:         db `0123456789abcdef`


;-------------------------------------
; Assume rax contains the 16 bits to convert (0 - 65535) (0x00 - 0xffff)
; Destination buffer for 5-bytes ASCII string: 'outputDec' (5 ASCII)
; Input: ax
; Output: [outputDec]
;-------------------------------------
Dec2Ascii:
    pusha

    ; empty the output buffer
    mov si, 5
.empty:
    lea bx, [outputDec]
    add bx, si
    mov byte [bx], 0x30
    dec si
    jns .empty


    lea di, [outputDec]
    add di, 5

.conv_loop:
    xor dx, dx                  ; Clear RDX for DIV instruction
    mov bx, 10                  ; Divisor (10)
    div bx                      ; AX = AX / 10 and DL = AX % 10
                                ; in other word AX carry the number
                                ; and DL carry the fraction
                                ; example: if AX: 8559 decimal / 10 = 885.9
                                ; AX = 855, DL = 9 (it wont exceed 9)
    add dl, 0x30                ; Convert remainder to ASCII digit 30h added
    mov byte [di], dl          ; Store digit in buffer
    dec di                     ; Move to the previous byte
    cmp ax, 0                   ; Check if quotient is zero
    jne .conv_loop              ; Loop if not zero
    
    popa
    ret

;-------------------------------------
; Assume rax contains the 32 bits to convert (0 - 65535) (0x00 - 0xffff)
; Destination buffer for 5-bytes ASCII string: 'outputDec' (5 ASCII)
; Input: eax
; Output: [outputDec]
;-------------------------------------
Dec2Ascii32:
    pusha

    ; empty the output buffer
    mov si, 10
.empty:
    lea bx, [outputDec]
    add bx, si
    mov byte [bx], 0x30
    dec si
    jns .empty


    lea di, [outputDec]
    add di, 10

.conv_loop:
    xor edx, edx                ; Clear eDX for DIV instruction
    mov ebx, 10                 ; Divisor (10)
    div ebx                     ; EAX = EAX / 10 and EDX = EAX % 10
                                ; in other word EAX carry the number
                                ; and EDX carry the fraction
                                ; example: if EAX: 8559 decimal / 10 = 885.9
                                ; EAX = 855, EDX = 9 (it wont exceed 9)
    add dl, 0x30                ; Convert remainder to ASCII digit 30h added
    mov byte [di], dl           ; Store digit in buffer
    dec di                      ; Move to the previous byte
    cmp eax, 0                  ; Check if quotient is zero
    jne .conv_loop              ; Loop if not zero
    
    popa
    ret


;*************************************
;
; DATA Section
;
;*************************************
    empty:          dq 0

    ampm:           db 0  ; 1 = PM, 0 = AM

    currentS0:      db "0"
    currentS1:      db "0"
    currentM0:      db "0"
    currentM1:      db "0"
    currentH0:      db "0"
    currentH1:      db "0"
    currentW0:      db "0"
    currentW1:      db "0"
    currentD0:      db "0"
    currentD1:      db "0"
    currentN0:      db "0"
    currentN1:      db "0"
    currentT0:      db "0"
    currentT1:      db "0"
    currentT2:      db "0"
    currentY0:      db "0"
    currentY1:      db "0"
    currentY2:      db "0"
    currentY3:      db "0"

    result_buffer:  db 0,0,0,0,0,0,0,0 ;Buffer + null terminator
    
    BCD_S:          db 0
    BCD_M:          db 0
    BCD_H:          db 0
    
    prevSecond:     db 0
    
    HEX_S:          db 0
    HEX_M:          db 0
    HEX_H:          db 0
    
    prevHEX_S:      db 0
    prevHEX_M:      db 0
    prevHEX_H:      db 0
    
    prevDistSecX:   dw 20     ; value at 12AM
    prevDistSecY:   dw 5
    
    prevDistMinX:   dw 20
    prevDistMinY:   dw 10
    
    prevDistHorX:   dw 20
    prevDistHorY:   dw 40
    
    X0:             dw  20
    Y0:             dw  152
    
    X1:             dw 0
    Y1:             dw 0

    toggle:         db 0

    clockColor:     db 0b00000001       ;Blue
    dotsColor:      db 0b00001011       ;Light Cyan
    secondsColor:   db 0b00001100       ;Light Red
    minsColor:      db 0b00001010       ;light Green
    hoursColor:     db 0b00001110       ;light Yellow
    centerColor:    db 0b00001101       ;light Purple
    blackColor:     db 0b00000000       ;Black
    whiteColor:     db 0b00000111       ;white
    blueColor:      db 0b00000001       ;Blue
    cyanColor:      db 0b00000011       ;Cyan
    redColor:       db 0b00000100       ;Red
    greenColor:     db 0b00000010       ;Green
    yellowColor:    db 0b00000110       ;Yellow
    purpleColor:    db 0b00000101       ;Purple
    whiteBColor:    db 0b00001111       ;Bright white
    blueBColor:     db 0b00001001       ;Bright Blue
    cyanBColor:     db 0b00001011       ;Bright Cyan
    redBColor:      db 0b00001100       ;Bright Red
    greenBColor:    db 0b00001010       ;Bright Green
    yellowBColor:   db 0b00001110       ;Bright Yellow
    purpleBColor:   db 0b00001101       ;Bright Purple

    ;------ FPU x87 ------
    pi_val:         dq 3.141592653589793
    pi:             dd 3.14159265359
    diam:           dw 180
    cAngle:         dw 6
    cResult:        dd 0
    ∏d:             dd 0.01745329       ; ∏ / 180 ===> fit for degree to radian
    two∏:           dd 6.28318531       ; 2 * ∏


    sAngle:         dd 0.10471976    ; 6º * (pi /180)  360º/60 = 6º
    radius:         dw 19
    fResult         dd 0
    dbStore         db 0
    dwStore         dw 0
    ddStore         dd 0
    
    y_multiplier:   dw 4
    
    show_counter:   dw  0
    mode_counter:   dw  0

    rtc_sec         db 0
    rtc_min         db 0
    rtc_hour        db 0
    rtc_dow         db 0    ; week day
    rtc_day         db 0
    rtc_month       db 0
    rtc_year        db 0
    rtc_century     db 0


    ;------ CRT Sync Timing Data ---------
    cpu_mhz:                    dd  0
    vertical_sync:              dd  576000
    line_sync:                  dd  14100           ;For Color TV (set to 104100)
    back_porch:                 dd  17400
    white_length:               dd  56000
    black_length:               dd  100000
    stabilizer:                 dd  1003
    active_video_width:         dd  44000000      ;(52ms * 3ghz)   153764 at 2.957ghz less than 8 blocks
                                    ;247,000 (217,000 - 267,000) 8 blocks
                                    ;1,400,000 (1,200,000 - 1,600,000) 16 blocks
                                    ;44,000,000 (12,000,000 - 76,000,000) 32 blocks
    pixel_cycles:               dd  1375000
                                    ;34,250 = 247,000/8 8 blocks
                                    ;87,500 = 1,400,000/16 16 blocks
                                    ;1,375,000 = 44,000,000/32 32 blocks
    pattern_number:             dd  40          ; maximum width for Parallel Port is 40 pixel with no delay at all

    front_porch:                dd  4500
    
    lines_count:                dd  304

    cpu_mhz_text:               db `CPU Speed: \0`
    vertical_sync_text:         db `Vertical Sync: \0`
    line_sync_text:             db `Line Sync: \0`
    back_porch_text:            db `Back Porch: \0`
    white_length_text:          db `White Length: \0`
    black_length_text:          db `Black Length: \0`
    active_video_width_text:    db `Active Video Width: \0`
    stabilizer_text:            db `Stabilizer: \0`
    pixel_cycles_text:          db `Pixel Cycles Time: \0`
    front_porch_text:           db `Front Porch: \0`
    pattern_number_text:        db `Patterns: \0`

    outputHex:                  db  `0000  \r\0`             ; Used by Hex2UTF16
    outputDec:                  db  `00000000000  \r\0`         ; Used by Dec2UTF16
    endOfLine:                  db  `\n\r\0`
    return:                     db  `\n\r\0`

    hello:                      db `hello world! \0`
    fineRot:                    dw 45

times 16384 - ($-sector_1)       db  0 ; 32 sectors 512 x 32 = 16K (if you wanrt more you need to load more sectors)(*)
