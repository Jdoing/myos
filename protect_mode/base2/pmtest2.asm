%include "pm.inc"

org 0100h

jmp BEGIN

;设置GDT描述符
[SECTION .gdt]
LABEL_GDT: Descriptor 0, 0, 0
LABEL_DESC_NORMAL: Descriptor    0,         0ffffh, DA_DRW    ; Normal 描述符
LABEL_DESC_CODE32: Descriptor 0, SegCode32len - 1, DA_C + DA_32
LABEL_DESC_CODE16: Descriptor    0,         0ffffh, DA_C      ; 非一致代码段, 16
LABEL_DESC_DATA :Descriptor 0, DataLen - 1, DA_DRW
LABEL_DESC_STACK:  Descriptor    0,     TopOfStack, DA_DRWA+DA_32; Stack, 32 位
LABEL_DESC_TEST:   Descriptor 0500000h,     0ffffh, DA_DRW
LABEL_DESC_VIDEO: Descriptor 0B8000h, 0ffffh, DA_DRW

GDT_LEN equ $ - LABEL_GDT

;设置GDTR
GDTR_Addr equ GDT_LEN - 1   ;gdtr limit
resd 1    ;gdt 基地址,也可以dd 0

;设置GDT选择子
SelectorNormal		equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorCode16		equ	LABEL_DESC_CODE16	- LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA		- LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK	- LABEL_GDT
SelectorTest		equ	LABEL_DESC_TEST		- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
; END of [SECTION .gdt]

[SECTION .data1]	 ; 数据段
ALIGN	32
[BITS	32]
LABEL_DATA:
SPValueInRealMode	dw	0
; 字符串
PMMessage:		db	"In Protect Mode now. ^-^", 0	; 在保护模式中显示
OffsetPMMessage equ	PMMessage - $$
StrTest:		db	"ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0 ;0表示字符串结束
OffsetStrTest		equ	StrTest - $$
DataLen			equ	$ - LABEL_DATA
; END of [SECTION .data1]

; 全局堆栈段
[SECTION .gs]
ALIGN 32
[BITS 32]
LABEL_STACK:
    time 512 db 0
TopOfStack equ $ - LABEL_STACK -1


[SECTION .s16]
[BITS   16]
BEGIN:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 01000h
    
    ;先保存段寄存器cs的值
    mov	[LABEL_GO_BACK_TO_REAL+3], ax
	mov	[SPValueInRealMode], sp ;在数据段中保存值01000h
    
    ; 初始化 32 位代码段描述符
    mov ax, cs
    movzx	eax, ax ;无符号扩展传送
    shl eax, 4
    add eax, LABEL_SEG_CODE16   ;代码段基地址
    mov word [LABEL_DESC_CODE16 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE16 + 4],,al
    mov byte [LABEL_DESC_CODE16 + 7], ah
    
    ;填充GDT描述符
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32
    mov word [LABEL_DESC_CODE32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32 + 4], al
    mov byte [LABEL_DESC_CODE32 + 7], ah
    
    ; 初始化数据段描述符
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_DATA
	mov	word [LABEL_DESC_DATA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_DATA + 4], al
	mov	byte [LABEL_DESC_DATA + 7], ah

	; 初始化堆栈段描述符
    xor eax, eax
    mov ax, ds
	shl	eax, 4
	add	eax, LABEL_STACK
	mov	word [LABEL_DESC_STACK + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_STACK + 4], al
	mov	byte [LABEL_DESC_STACK + 7], ah
    
    ;加载gdt
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_GDT  ;GDT的基地址
    mov dword [GDTR_Addr + 2], eax
    
    ; 加载 GDTR
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

LABEL_REAL_ENTRY:		; 从保护模式跳回到实模式就到了这里
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
    
    ;恢复保存的sp=01000h
	mov	sp, [SPValueInRealMode]
    
	in	al, 92h		; `.
	and	al, 11111101b	;  | 关闭 A20 地址线
	out	92h, al		; 
    
	sti			; 开中断
    
    ;ah=4c的功能表示返回DOS, 可以写为mov ah, 4ch
	mov	ax, 4c00h	; `.
	int	21h		; 回到 DOS
; END of [SECTION .s16]



[SECTION .s32]; 32 位代码段. 由实模式跳入.
[BITS   32]
LABEL_SEG_CODE32:
	mov	ax, SelectorData
	mov	ds, ax			; 数据段选择子
	mov	ax, SelectorTest
	mov	es, ax			; 测试段选择子
	mov	ax, SelectorVideo
	mov	gs, ax			; 视频段选择子

	mov	ax, SelectorStack
	mov	ss, ax			; 堆栈段选择子

	mov	esp, TopOfStack
    
    ; 下面显示一个字符串
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	xor	esi, esi
	xor	edi, edi

    mov esi, OffsetPMMessage    ;数据段偏移量
    mov	edi, (80 * 10 + 0) * 2	; 目的数据偏移。屏幕第 10 行, 第 0 列。
    
    cld
.1:
    lodsb
    test al, al
    jz .2   ;如果零位标志被设置,说明al都为0,字符串已经结束,跳转到.2
    mov	[gs:edi], ax
    add edi, 2
    jmp .1
.2: ;显示完毕
	call	DispReturn
    
    
	mov	edi, (80 * 11 + 79) * 2	; 屏幕第 11 行, 第 79 列。
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	al, 'P'
	mov	[gs:edi], ax

	; 到此停止
	jmp	$

SegCode32len equ  $ - LABEL_SEG_CODE32
