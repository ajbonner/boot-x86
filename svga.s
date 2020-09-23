[BITS 16]

section .text
  global SVGAInfo

SVGAInfo:  
  mov ah, 4Fh             ; Super VGA support
  mov al, 00h             ; Return Super VGA information
  mov es:di, vgainfoblock ; pointer to 256 byte buffer

section .bss
vgainfoblock: resb 256

; http://www.monstersoft.com/tutorial1/VESA_intro.html#2.1
; VgaInfoBlock    STRUC
;       VESASignature   db   'VESA'      ; 4 signature bytes
;       VESAVersion     dw   ?           ; VESA version number
;       OEMStringPtr    dd   ?           ; Pointer to OEM string
;       Capabilities    db   4 dup(?)    ; capabilities of the video environment
;       VideoModePtr    dd   ?           ; pointer to supported Super VGA modes
;       TotalMemory     dw   ?           ; Number of 64kb memory blocks on board
;       Reserved        db   236 dup(?)  ; Remainder of VgaInfoBlock
; VgaInfoBlock    ENDS