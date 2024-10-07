	.code16
# rewrite with AT&T syntax by falcon <wuzhangjin@gmail.com> at 081012
#
#	setup.s		(C) 1991 Linus Torvalds
#
# setup.s is responsible for getting the system data from the BIOS,
# and putting them into the appropriate places in system memory.
# both setup.s and system has been loaded by the bootblock.
#
# This code asks the bios for memory/disk/other parameters, and
# puts them in a "safe" place: 0x90000-0x901FF, ie where the
# boot-block used to be. It is then up to the protected mode
# system to read them from there before the area is overwritten
# for buffer-blocks.
#

# NOTE! These had better be the same as in bootsect.s!

	.equ INITSEG, 0x9000	# we move boot here - out of the way
	.equ SYSSEG, 0x1000	# system loaded at 0x10000 (65536).
	.equ SETUPSEG, 0x9020	# this is the current segment

	.global _start, begtext, begdata, begbss, endtext, enddata, endbss
	.text
	begtext:
	.data
	begdata:
	.bss
	begbss:
	.text

	ljmp $SETUPSEG, $_start
_start:
	mov	$0x03, %ah		# read cursor pos
	xor	%bh, %bh
	int	$0x10

	mov	$25, %cx
	mov	$0x0007, %bx		# page 0, attribute 7 (normal)
	# lea	msg1, %bp
	mov $msg, %bp
	mov %cs, %ax
	mov %ax, %es # es:bp 此寄存器对指向要显示的字符串起始位置处,es在新汇编文件中要重置为正确值
	mov	$0x1301, %ax		# write string, move cursor
	int	$0x10

# ok, the read went well so we get current cursor position and save it for
# posterity.

	mov	$INITSEG, %ax	# this is done in bootsect already, but...
	mov	%ax, %ds
	mov	$0x03, %ah	# read cursor pos
	xor	%bh, %bh
	int	$0x10		# save it in known place, con_init fetches
	mov	%dx, %ds:0	# it from 0x90000.
# Get memory size (extended mem, kB)

	mov	$0x88, %ah
	int	$0x15
	mov	%ax, %ds:2

# Get video-card data:

	mov	$0x0f, %ah
	int	$0x10
	mov	%bx, %ds:4	# bh = display page
	mov	%ax, %ds:6	# al = video mode, ah = window width

# check for EGA/VGA and some config parameters

	mov	$0x12, %ah
	mov	$0x10, %bl
	int	$0x10
	mov	%ax, %ds:8
	mov	%bx, %ds:10
	mov	%cx, %ds:12

# Get hd0 data

	mov	$0x0000, %ax
	mov	%ax, %ds
	lds	%ds:4*0x41, %si
	mov	$INITSEG, %ax
	mov	%ax, %es
	mov	$0x0080, %di
	mov	$0x10, %cx
	rep
	movsb

# Get hd1 data

	mov	$0x0000, %ax
	mov	%ax, %ds
	lds	%ds:4*0x46, %si
	mov	$INITSEG, %ax
	mov	%ax, %es
	mov	$0x0090, %di
	mov	$0x10, %cx
	rep
	movsb

# 显示在0x9000 保存的各项硬件参数
	mov %cs, %ax
	mov %ax, %es # es:bp 此寄存器对指向要显示的字符串起始位置处,es在新汇编文件中要重置为正确值
	mov $INITSEG, %ax
	mov %ax, %dx
#打印光标位置
	call print_nl
	mov $0x00, %bp
	call print_hex



	mov	$0x03, %ah		# read cursor pos
	xor	%bh, %bh
	int	$0x10
	mov	$13, %cx
	mov	$0x0007, %bx		# page 0, attribute 7 (normal)
	mov $msg_cursor, %bp
	mov	$0x1301, %ax		# write string, move cursor
	int	$0x10

    mov $0x02, %bp
	call print_hex


# memory size
	mov	$0x03, %ah		#
	xor	%bh, %bh
	int	$0x10
	mov	$14, %cx
	mov	$0x0007, %bx		# page 0, attribute 7 (normal)
	mov $msg_memorySize, %bp
	mov	$0x1301, %ax		# write string, move cursor
	int	$0x10

	mov $0x80, %bp
	call print_hex
# KB
	mov	$0x03, %ah		#
	xor	%bh, %bh
	int	$0x10
	mov	$3, %cx
	mov	$0x0007, %bx		# page 0, attribute 7 (normal)
	mov $msg_KB, %bp
	mov	$0x1301, %ax		# write string, move cursor
	int	$0x10

# HD info
	mov	$0x03, %ah		#
	xor	%bh, %bh
	int	$0x10
	mov	$9, %cx
	mov	$0x0007, %bx		# page 0, attribute 7 (normal)
	mov $msg_HD_info, %bp
	mov	$0x1301, %ax		# write string, move cursor
	int	$0x10

# Cycls
	mov	$0x03, %ah		#
	xor	%bh, %bh
	int	$0x10
	mov	$12, %cx
	mov	$0x0007, %bx		# page 0, attribute 7 (normal)
	mov $msg_Cylinders, %bp
	mov	$0x1301, %ax		# write string, move cursor
	int	$0x10

	mov $0x82, %bp
	call print_hex

#headers
	mov	$0x03, %ah		#
	xor	%bh, %bh
	int	$0x10
	mov	$10, %cx
	mov	$0x0007, %bx		# page 0, attribute 7 (normal)
	mov $msg_Headers, %bp
	mov	$0x1301, %ax		# write string, move cursor
	int	$0x10

	mov $0x8e, %bp
	call print_hex

# sector
	mov	$0x03, %ah		#
	xor	%bh, %bh
	int	$0x10
	mov	$10, %cx
	mov	$0x0007, %bx		# page 0, attribute 7 (normal)
	mov $msg_Sectors, %bp
	mov	$0x1301, %ax		# write string, move cursor
	int	$0x10

	mov $0x80, %bp
	call print_hex
inf_loop:
    jmp inf_loop

# Check that there IS a hd1 :-)

	mov	$0x01500, %ax
	mov	$0x81, %dl
	int	$0x13
	jc	no_disk1
	cmp	$3, %ah
	je	is_disk1
no_disk1:
	mov	$INITSEG, %ax
	mov	%ax, %es
	mov	$0x0090, %di
	mov	$0x10, %cx
	mov	$0x00, %ax
	rep
	stosb
is_disk1:

# now we want to move to protected mode ...

	cli			# no interrupts allowed !

# first we move the system to it's rightful place

	mov	$0x0000, %ax
	cld			# 'direction'=0, movs moves forward
do_move:
	mov	%ax, %es	# destination segment
	add	$0x1000, %ax
	cmp	$0x9000, %ax
	jz	end_move
	mov	%ax, %ds	# source segment
	sub	%di, %di
	sub	%si, %si
	mov 	$0x8000, %cx
	rep
	movsw
	jmp	do_move

# then we load the segment descriptors

end_move:
	mov	$SETUPSEG, %ax	# right, forgot this at first. didn't work :-)
	mov	%ax, %ds
	lidt	idt_48		# load idt with 0,0
	lgdt	gdt_48		# load gdt with whatever appropriate

# that was painless, now we enable A20

	#call	empty_8042	# 8042 is the keyboard controller
	#mov	$0xD1, %al	# command write
	#out	%al, $0x64
	#call	empty_8042
	#mov	$0xDF, %al	# A20 on
	#out	%al, $0x60
	#call	empty_8042
	inb     $0x92, %al	# open A20 line(Fast Gate A20).
	orb     $0b00000010, %al
	outb    %al, $0x92

# well, that went ok, I hope. Now we have to reprogram the interrupts :-(
# we put them right after the intel-reserved hardware interrupts, at
# int 0x20-0x2F. There they won't mess up anything. Sadly IBM really
# messed this up with the original PC, and they haven't been able to
# rectify it afterwards. Thus the bios puts interrupts at 0x08-0x0f,
# which is used for the internal hardware interrupts as well. We just
# have to reprogram the 8259's, and it isn't fun.

	mov	$0x11, %al		# initialization sequence(ICW1)
					# ICW4 needed(1),CASCADE mode,Level-triggered
	out	%al, $0x20		# send it to 8259A-1
	.word	0x00eb,0x00eb		# jmp $+2, jmp $+2
	out	%al, $0xA0		# and to 8259A-2
	.word	0x00eb,0x00eb
	mov	$0x20, %al		# start of hardware int's (0x20)(ICW2)
	out	%al, $0x21		# from 0x20-0x27
	.word	0x00eb,0x00eb
	mov	$0x28, %al		# start of hardware int's 2 (0x28)
	out	%al, $0xA1		# from 0x28-0x2F
	.word	0x00eb,0x00eb		#               IR 7654 3210
	mov	$0x04, %al		# 8259-1 is master(0000 0100) --\
	out	%al, $0x21		#				|
	.word	0x00eb,0x00eb		#			 INT	/
	mov	$0x02, %al		# 8259-2 is slave(       010 --> 2)
	out	%al, $0xA1
	.word	0x00eb,0x00eb
	mov	$0x01, %al		# 8086 mode for both
	out	%al, $0x21
	.word	0x00eb,0x00eb
	out	%al, $0xA1
	.word	0x00eb,0x00eb
	mov	$0xFF, %al		# mask off all interrupts for now
	out	%al, $0x21
	.word	0x00eb,0x00eb
	out	%al, $0xA1

# well, that certainly wasn't fun :-(. Hopefully it works, and we don't
# need no steenking BIOS anyway (except for the initial loading :-).
# The BIOS-routine wants lots of unnecessary data, and it's less
# "interesting" anyway. This is how REAL programmers do it.
#
# Well, now's the time to actually move into protected mode. To make
# things as simple as possible, we do no register set-up or anything,
# we let the gnu-compiled 32-bit programs do that. We just jump to
# absolute address 0x00000, in 32-bit protected mode.
	#mov	$0x0001, %ax	# protected mode (PE) bit
	#lmsw	%ax		# This is it!
	mov	%cr0, %eax	# get machine status(cr0|MSW)
	bts	$0, %eax	# turn on the PE-bit
	mov	%eax, %cr0	# protection enabled

				# segment-descriptor        (INDEX:TI:RPL)
	.equ	sel_cs0, 0x0008 # select for code segment 0 (  001:0 :00)
	ljmp	$sel_cs0, $0	# jmp offset 0 of code segment 0 in gdt

# This routine checks that the keyboard command queue is empty
# No timeout is used - if this hangs there is something wrong with
# the machine, and we probably couldn't proceed anyway.
empty_8042:
	.word	0x00eb,0x00eb
	in	$0x64, %al	# 8042 status port
	test	$2, %al		# is input buffer full?
	jnz	empty_8042	# yes - loop
	ret

print_hex:
	mov $4, %cx
	mov (%bp), %dx
print_digit:
	roll $4, %dx
	mov $0xe0f ,%ax
	andb %dl, %al
	addb $0x30, %al
	cmpb $0x3a, %al
	jl outp
	addb $0x07, %al
outp:
	int $0x10
	loop print_digit
	ret

print_nl:
	mov $0xe0d, %ax
	int $0x10
	mov $0xa, %al
	int $0x10
	ret

msg:
	.byte 13,10
	.ascii "Now we are in the SETUP"
	.byte 13,10,13,10

msg_cursor:
	.byte 13,10
	.ascii "Cursor POS:"

msg_memorySize:
	.byte 13,10
	.ascii "Memory Size:"

msg_KB:
	.ascii "KB"

msg_HD_info:
	.byte 13,10
	.ascii "HD Info"

msg_Cylinders:
	.byte 13,10
	.ascii "Cylinders:"


msg_Headers:
	.byte 13,10
	.ascii "Headers:"


msg_Sectors:
	.byte 13,10
	.ascii "Sectors:"


gdt:
	.word	0,0,0,0		# dummy

	.word	0x07FF		# 8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000		# base address=0
	.word	0x9A00		# code read/exec
	.word	0x00C0		# granularity=4096, 386

	.word	0x07FF		# 8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000		# base address=0
	.word	0x9200		# data read/write
	.word	0x00C0		# granularity=4096, 386

idt_48:
	.word	0			# idt limit=0
	.word	0,0			# idt base=0L


gdt_48:
	.word	0x800			# gdt limit=2048, 256 GDT entries
	.word   512+gdt, 0x9		# gdt base = 0X9xxxx,
	# 512+gdt is the real gdt after setup is moved to 0x9020 * 0x10




.text
endtext:
.data
enddata:
.bss
endbss:
