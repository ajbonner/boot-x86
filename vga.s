[BITS 16]
[ORG 0x7C00]

  section .text

  global main

main:
  jmp short start     ; jump to beginning of code
  nop
  
bootsector:
  iOEM:         db  "AaronsOS"      ; OEM String
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
  iVolID        db  "DISK"          ; disk serial
  acVolumeLabel db  "BOOT       "   ; volume label
  acFSType      db  "FAT16   "      ; file system type

WriteString:
  lodsb                   ; load byte at ds:si into al (advancing si)
  or     al, al           ; test if character is 0 (end)
  jz     WriteString_done ; jump to end if 0.
 
  mov    ah, 0xE      ; Subfunction 0xe of int 10h (video teletype output)
  mov    bx, 0xA      ; Set bh (page nr) to 0, and bl (attribute) to white (9)
  int    0x10         ; call BIOS interrupt.
 
  jmp    WriteString  ; Repeat for next character.
 
WriteString_done:
  ret		  ; return
 
SetVidMode:
  ;mov  ax, 12h       ; ah=0x00, al=0x12 use vga 16 color 640x480, text=80x25 mode
  mov  ax, [vidmode]  ; ah=0x00, al=0x12 use vga 16 color 640x480, text=80x25 mode
  int  10h            ; switch mode
  inc byte [vidmode]
  ret

SetVBEMode:
  mov ah, 0x4f        ; VBE function space
  mov al, 0x02        ; VBE set mode function
  mov bx, 0x0118      ; VBE mode number
  int 10h
  inc byte [vidmode]
  ret
  
Reboot:
  call SetVBEMode

  lea  si, [rebootmsg] ; Load address of reboot message into si
  call WriteString    ; print the string
  xor  ax, ax         ; subfuction 0
  int  0x16           ; call bios to wait for key

  cmp  byte [vidmode], 0x16
  jle  Reboot

  db   0xEA           ; unassembled machine language to jump to FFFF:0000 (reboot)
  dw   0x0000
  dw   0xFFFF
 
start:
  ; Setup segments:
  cli
  mov  [iBootDrive], dl  ; save what drive we booted from (should be 0x0)
  mov  ax, cs         ; CS = 0x0, since that's where boot sector is (0x07c00)
  mov  ds, ax         ; DS = CS = 0x0
  mov  es, ax         ; ES = CS = 0x0
  mov  ss, ax         ; SS = CS = 0x0
  mov  sp, 0x7C00     ; Stack grows down from offset 0x7C00 toward 0x0000.
  sti  

  ; Setup initial vidmode
  mov byte [vidmode], 0x00
  call SetVBEMode
 
  ; Display "loading" message:
  lea  si, [loadmsg]
  call WriteString
 
  ; Reset disk system.
  ; Jump to bootFailure on error.
  mov  dl, [iBootDrive]  ; drive to reset
  xor  ax, ax         ; subfunction 0
  int  0x13           ; call interrupt 13h
  jc   bootFailure    ; display error message if carry set (error)  
 
  ; End of loader, for now. Reboot.
  call Reboot

bootFailure:
  lea  si, [diskerror]
  call WriteString
  call Reboot
 
loadmsg:    db "Loading OS...", 0x0A, 0x0D, 0x00
diskerror:  db "Disk error.", 0x00
rebootmsg:  db "Press any key to reboot.", 0x0A, 0x0D, 0x00

times 510 - ( $ - $$ ) db 1 ; Pad with nulls up to 510 bytes (excl. boot magic)
BootMagic: dw 0xAA55  ; magic word for BIOS

  section .bss
vidmode: resb 1

