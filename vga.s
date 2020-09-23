[BITS 16]
[ORG 0x7C00]

start:
  jmp short main

bootsector:
  iOEM:         db  "AaronsOS"    ; OEM String
  iSectSize     dw  0200h         ; bytes per sector
  iClustSize    db  1             ; num sectors per cluster
  iResSect      dw  1             ; num reservced sectors
  iFatCnt       db  2             ; fat copy count
  iRootSize     dw  224           ; size of root directory
  iTotalSect    dw  2880          ; total num of secotrs if over 32 MB
  iMedia        db  0F0h          ; media decriptor
  iFatSize      dw  9             ; size of each FAT
  iTrackSect    dw  9             ; sectors per track
  iHeadCnt      dw  2             ; number of read-write heads
  iHiddenSect   dd  0             ; number of hidden sectors (e.g. bad sectors)
  iSect32       dd  0             ; number of secutors for over 32 MB
  iBootDrive    db  0             ; holds drive that boot sector came from
  iReserved     db  0             ; reserved, empty
  iBootSign     db  029h          ; extended boot sector signature
  iVolID        db  "DISK"        ; disk serial
  acVolumeLabel db  "BOOT       " ; volume label
  acFSType      db  "FAT16   "    ; file system type

main:
  ; Setup segments:
  cli
  mov  [iBootDrive], dl           ; save what drive we booted from (should be 0x0)
  mov  ax, cs                     ; CS = 0x0, since that's where boot sector is (0x07c00)
  mov  ds, ax                     ; DS = CS = 0x0
  mov  es, ax                     ; ES = CS = 0x0
  mov  ss, ax                     ; SS = CS = 0x0
  mov  di, ax
  mov  sp, 07C00h                 ; Stack grows down from offset 0x7C00 toward 0x0000.
  sti

  ; Setup initial vidmode
  ; e.g. ah=0x00, al=0x12 use vga 16 color 640x480, text=80x25, refresh=60hz
  mov byte [vidmode], 03h
  ; call SetVBEMode
  call SetVidMode

  ; Display "loading" message:
  lea  si, [loadmsg]
  call WriteString

  ; Reset disk system.
  ; Jump to bootFailure on error.
  mov  dl, [iBootDrive]           ; drive to reset
  xor  ax, ax                     ; subfunction 0
  int  13h                        ; call interrupt 13h
  jc   BootFailure                ; display error message if carry set (error)

  lea  si, [osnotfounderror]      ; load address of no os found error into si
  call WriteString
  lea  si, [rebootpromptmsg]      ; Load address of reboot message into si
  call WriteString                ; print the string
  call KeypressWaitLoop
  call Reboot
  hlt

WriteString:
  mov   ah, 0Ah                   ; set vga text attrs
  mov   bx, 0b800h
  mov   es, bx

WriteString_loop:
  lodsb                           ; load byte at ds:si into al (advancing si)

  or     al, al                   ; test if character is 0 (end)
  jz     WriteString_done         ; if nul reached return otherwise continue

  cmp    al, 0Ah
  jz     WriteNewline

  cmp    al, 0Dh
  jz     WriteCarriageReturn

  mov    [es:di], ax              ; write word to vga text buffer
  times 2 inc di                  ; 2 bytes need to be written to the vga text buffer per character
  jmp    WriteString_loop         ; Repeat for next character.

WriteNewline:
  add di, 80*2
  jmp WriteString_loop

WriteCarriageReturn:
  push ax                         ; save registers
  push bx
  push dx

  mov ax, di                      ; divisor low word
  mov dx, 0                       ; divisor high word
  mov bx, 80                      ; dividend
  div bx

  mov bx, 80                      ; number of text columns
  mul bx                          ; multiply the number rows written by the column count to get the buffer position

  mov di, ax

  pop dx
  pop bx                          ; restore registers
  pop ax

  call UpdateCursor
  jmp WriteString_loop

WriteString_done:
  call SleepSecond

  ret                             ; Return to calling subroutine

SetVidMode:
  xor  ax, ax                     ; Rub out anything in ax
  mov  al, [vidmode]              ; Set the predefined vga vidmode in the low byte of ax
  mov  bx, 0Fh                    ; Set bh (page nr) to 0, and bl (attribute) to white (F)
  int  10h                        ; switch mode

  ret

SetVBEMode:
  mov ah, 0x4f                    ; VBE function space
  mov al, 0x02                    ; VBE set mode function
  mov bx, 0x0118                  ; VBE mode number
  int 10h

  ret

Reboot:
  lea  si, [rebootmsg]            ; Load address of reboot message into si
  call WriteString                ; print the string

  db   0xEA                       ; unassembled machine language to jump to FFFF:0000 (reboot)
  dw   0x0000
  dw   0xFFFF

 SleepSecond:
  ; bios wait service expects 16bit wait period setup in cx (high byte) and dx (low byte) registers
  ; actual value is concatenation of high + low in hex to set wait period in microseconds
  ; https://dos4gw.org/INT_15H_86H_Wait
  mov     cx, 000Fh              ; high byte
  mov     dx, 04240h              ; low byte

  xor     ax, ax                  ; zero out ax
  mov     ah, 86h                 ; wait subfunction
  int     15h                     ; trigger bios service
  ret

KeypressWaitLoop:
  xor  ax, ax                     ; subfuction 0
  int  16h                        ; call bios to wait for key
  ret

  ; VGA CRTC registers 14 and 15 contain the MSB and LSB of the cursor position, relative to B8000h or B0000h, in units of characters.
UpdateCursor:
  ; save registers on the stack
  push ax
  push bx
  push cx
  push dx

  ; move cursor column index into bx(bl actually), di = current memory pos of vga text buffer, with 2 bytes per char written, 
  ; to get cursor pos memory pos needs to be divided by 2
  mov ax, di                    ; current textmode memory pos as dividend
  mov dx, 0
  mov bx, 2                     ; divisor
  div bx
  mov bx, ax                    ; ax has the 16 bit quotient result

  mov dx, [crtcreg]             ; write 16bit crtc base io port address to dx (index register)
  mov al, 0Fh                   ; set address index 15 (cursor pos low byte)
  out dx, al                    ; write to io port

  inc dl                        ; vga data register is crtc port + 1
  mov al, bl                    ; send low byte of cursor position to crtc data register
  out dx, al                    ; write to io port

  dec dl                        ; revert back to crtc base io port address
  mov al, 0x0E                  ; select index 10 (cursor pos high byte)
  out dx, al                    ; write to io port

  inc dl                        ; select data port address
  mov al, bh                    ; send high byte of cursor position to crtc data register
  out dx, al                    ; write to io port

  ; restore registers
  pop dx                        
  pop cx
  pop bx
  pop ax

  ret

BootFailure:
  lea  si, [diskerror]
  call WriteString
  call Reboot

loadmsg:          db "Loading OS...", 0Ah, 0Dh, 00h
diskerror:        db "Disk error.", 00h
rebootpromptmsg:  db "Press any key to reboot.", 0Ah, 0Dh, 00h
rebootmsg:        db "Rebooting...", 0Ah, 0Dh, 00h
osnotfounderror:  db "No operating system found.", 0Ah, 0Dh, 00h

crtcreg:    dw 03D4h

times 510 - ( $ - $$ ) db 0h      ; Pad with nulls up to 510 bytes (excl. boot magic)
bootmagic: dw 0AA55h              ; magic word for BIOS

section .bss
vidmode: resb 1