[BITS 16]
[ORG 0x7C00]

section .text
  global main

main:
  jmp short start   ; jump to beginning of code
  nop
  
bootsector:
  iOEM:         db  "DevOS   "      ; OEM String
  iSectSize     dw  0x200           ; bytes per sector
  iClustSize    db  1               ; num sectors per cluster
  iResSect      dw  1               ; num reservced sectors
  iFatCnt       db  2               ; fat copy count
  iRootSize     dw  224             ; size of root directory
  iTotalSect    dw  2880            ; total num of secotrs if over 32 MB
  iMedia        db  0xF0            ; media decriptor
  iFatSize      dw  9               ; size of each FAT
  iTrackSect    dw  9               ; sectors per track
  iHeadCnt      dw  2               ; number of read-write heads
  iHiddenSect   dd  0               ; number of hidden sectors (e.g. bad sectors) 
  iSect32       dd  0               ; number of secutors for over 32 MB
  iBootDrive    db  0               ; holds drive that boot sector came from
  iReserved     db  0               ; reserved, empty
  iBootSign     db  0x29            ; extended boot sector signature
  iVolID        db  "seri"          ; disk serial
  acVolumeLabel db  "MYVOLUME   "   ; volume label
  acFSType      db  "FAT16   "      ; file system type
 
start:
  ; Setup segments:
  cli
  mov  [iBootDrive], dl  ; save what drive we booted from (should be 0x0)
  mov  ax, cs          ; CS = 0x0, since that's where boot sector is (0x07c00)
  mov  ds, ax          ; DS = CS = 0x0
  mov  es, ax          ; ES = CS = 0x0
  mov  ss, ax          ; SS = CS = 0x0
  mov  sp, 0x7C00      ; Stack grows down from offset 0x7C00 toward 0x0000.
  sti  
 
  ; Display "loading" message:
  lea  si, [loadmsg]
  call WriteString
 
  ; Reset disk system.
  ; Jump to bootFailure on error.
  mov  dl, [iBootDrive]  ; drive to reset
  xor  ax, ax          ; subfunction 0
  int  13h             ; call interrupt 13h
  jc   BootFailure     ; display error message if carry set (error)  
 
  ; End of loader, for now. Reboot.
  lea  si, [rebootpromptmsg]  ; Load address of reboot message into si
  call WriteString      ; print the string
  call KeypressWaitLoop
  call Reboot
  hlt
 
BootFailure:
  lea  si, [diskerror]
  call WriteString

KeypressWaitLoop:
  xor ax, ax  ; zero ax
  mov ah, 0h  ; 
  int 16h
  ret
 
 SleepSecond:
  ; bios wait service expects 16bit wait period setup in cx (high byte) and dx (low byte) registers 
  ; actual value is concatenation of high + low in hex to set wait period in microseconds
  ; https://dos4gw.org/INT_15H_86H_Wait
  mov     cx, 0x001E  ; high byte
  mov     dx, 0x4240  ; low byte

  xor     ax, ax      ; zero out ax
  mov     ah, 86h     ; wait subfunction
  int     15h         ; trigger bios service
  ret

WriteString:
  lodsb                   ; load byte at ds:si into al (advancing si)
  or     al, al           ; test if character is 0 (end)
  jz     WriteStringDone ; jump to end if 0.
 
  mov    ah, 0Eh          ; Subfunction 0xe of int 10h (video teletype output)
  mov    bx, 9            ; Set bh (page nr) to 0, and bl (attribute) to white (9)
  int    10h              ; call BIOS interrupt.
 
  jmp    WriteString      ; Repeat for next character.
 
WriteStringDone:
  ret		  ; return
 
Reboot:
  lea si, [rebootmsg]
  call WriteString
  call SleepSecond
  db   0xEA             ; unassembled machine language to jump to FFFF:0000 (reboot)
  dw   0x0000
  dw   0xFFFF

loadmsg:    db "Loading OS...", 0Ah, 0Dh, 00h
diskerror:  db "Disk error.", 00h
rebootpromptmsg:  db "Press any key to reboot.", 0Ah, 0Dh, 00h
rebootmsg:  db "Rebooting...", 0Ah, 0Dh, 00h

times 510 - ( $ - $$ ) db 0 ; Pad with nulls up to 510 bytes (excl. boot magic)
bootmagic: dw 0xAA55 ; magic word for BIOS
