%include "pm.inc"

org 07c00h

jmp BEGIN

;设置GDT描述符
[SECTION .gdt]
LABEL_GDT: Descriptor 0, 0, 0
LABEL_DESC_CODE32: Descriptor 0, SegCode32len - 1, DA_C + DA_32
LABEL_DESC_VIDEO: Descriptor 0B8000h, 0ffffh, DA_DRW

GDT_LEN equ $ - LABEL_GDT

;设置GDTR
GDTR_Addr equ GDT_LEN - 1   ;gdtr limit
resd 1    ;gdt 基地址,也可以dd 0

;设置选择子
SelectorCode32 equ LABEL_DESC_CODE32 - LABEL_GDT
SelectorVideo equ LABEL_DESC_VIDEO - LABEL_GDT

[SECTION .s16]
[BITS   16]
BEGIN:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 01000h
    
    ;填充GDT描述符
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32
    mov word [LABEL_DESC_CODE32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32 + 4], al
    mov byte [LABEL_DESC_CODE32 + 7], ah
    
    ;加载gdt
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_GDT  ;GDT的基地址
    
    mov dword [GDTR_Addr + 2], eax
    lgdt [GDTR_Addr]
    
    cli
    
	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al
    
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    jmp dword SelectorCode32 : 0

[SECTION .s32]; 32 位代码段. 由实模式跳入.
[BITS   32]
LABEL_SEG_CODE32:
	mov	ax, SelectorVideo
	mov	gs, ax			; 视频段选择子(目的)

	mov	edi, (80 * 11 + 79) * 2	; 屏幕第 11 行, 第 79 列。
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	al, 'P'
	mov	[gs:edi], ax

	; 到此停止
	jmp	$

SegCode32len equ  $ - LABEL_SEG_CODE32
