# LAB2 调试分析Linux0.00引导程序

# 实验目的
-   熟悉实验环境；

-   掌握如何手写Bochs虚拟机的配置文件；

-   掌握Bochs虚拟机的调试技巧；

-   掌握操作系统启动的步骤；

# 实验配置与工具学习

## Bochs 配置文件
`Windows` 下可视化配置：
`config_interface: win32config`
`display_library: win32, options="gui_debug"`
设置虚拟软驱 A 为 1.44MB ，使用 Image 镜像文件装载：
`floppya: 1_44="Image", status=inserted`
设置计算机从虚拟软驱 A 启动， BIOS 将据此从软驱 A 加载引导扇
`boot: a `
## 掌握 Bochs 虚拟机的调试技巧
-   如何单步跟踪？
    ![](./images/Pasted%20image%2020230514115258.png)
-   如何设置断点进行调试？
    ![](./images/Pasted%20image%2020230514115412.png)
-   如何查看通用寄存器的值？
    ![](./images/Pasted%20image%2020230514115425.png)
-   如何查看系统寄存器的值？
    如上
-   如何查看内存指定位置的值？
    ![](./images/Pasted%20image%2020230514115450.png)
-   如何查看各种表，如 `gdt` ，`idt` ，`ldt` 等？
    上图中 gdt, idt, ldt
-   如何查看 `TSS`？
	  `info TSS`
-   如何查看栈中的内容？

	上图中 stack
-   如何在内存指定地方进行反汇编？

	“Disassemble”（将从某个线性地址开始的代码反汇编并显示在中间的框里）

# 实验内容
## 计算机引导程序

1.  如何查看 `0x7c00` 处被装载了什么？
     设置 0x7c00 处断点
2.  如何把真正的内核程序从硬盘或软驱装载到自己想要放的地方;
```
BOOTSEG = 0x07c0 ! 引导扇区（本程序）被 BIOS 加载到内存 0x7c00 处。
SYSSEG = 0x1000 ! 内核（head）先加载到 0x10000 处，然后移动到 0x0 处。
SYSLEN = 17 ! 内核占用的最大磁盘扇区数。
entry start
start:
 jmpi go,#BOOTSEG
```
标号 start 就是 boot. s 描述的汇编程序的入口地址（偏移地址，与段地址无关），在汇编后的二进制文件中，（因为没有指定起始地址）标号地址都从 0 开始，也就是说 start=0。
利用实模式下“段地址: 偏移地址”的性质，将 0: 0x7C00 等价变换为 0x7C0: 0，也就是说我们将段地址修改为 0x7C0，那么真正运行时的偏移地址就是从 0 开始的，这就与标号的地址一致了。
`jmpi` 指令是一条远转移指令，它会将代码段地址 `CS` 和代码偏移地址 `IP` 同时修改为指定的立即数（0x7C0、go 标号地址）。
接下来让 DS 和 SS 都指向 0x7c0 段。
`mov sp, #0x400` 设置临时栈指针。其值需大于程序末端并有一定空间即可。
接下来需要调用 BIOS 提供的磁盘中断（系统调用）int 0x13 将“软盘”上的系统内核代码（head. s）加载到内存里。
```
load_system:
17 mov dx,#0x0000 ! 利用 BIOS 中断 int 0x13 功能 2 从启动盘读取 head 代码。
18 mov cx,#0x0002 ! DH - 磁头号；DL - 驱动器号；CH - 10 位磁道号低 8 位；
19 mov ax,#SYSSEG ! CL - 位 7、6 是磁道号高 2 位，位 5-0 起始扇区号（从 1 计）。
20 mov es,ax ! ES:BX - 读入缓冲区位置（0x1000:0x0000）。
21 xor bx,bx ! AH - 读扇区功能号；AL - 需读的扇区数（17）。
22 mov ax,#0x200+SYSLEN
23 int 0x13
24 jnc ok_load ! 若没有发生错误则跳转继续运行，否则死循环。
```
![](./images/Pasted%20image%2020230514122214.png)

执行后：
![](./images/Pasted%20image%2020230514122725.png)
接下来我们要将读取的内核程序从 0x10 00:00 00 开始处复制到 00 00:00 00 开始（内存地址空间的开头）处。
现在就可以占用 0: 0 开始的内存区了。不过，为了防止中途因
键盘等原因产生中断（中断向量表都被我们占了，这还咋处理），我们需要屏蔽掉所有中断：
```
ok_load:
cli                ! no interrupts allowed !
```
然后我们进行内存整体复制:
```
mov ax, #SYSSEG ! 移动开始位置 DS:SI = 0x1000:0；目的位置 ES:DI=0:0。
mov ds, ax
xor ax, ax
mov es, ax
mov cx, #0x1000 ! 设置共移动 4K 次，每次移动一个字（word）。
sub si, si
sub di,di
rep movw ! 执行重复移动指令。
```
可以看到跟上面之前在 0 x10000 处内存中数据一致：
![](./images/Pasted%20image%2020230514123159.png)
设置控制寄存器 CR0（即机器状态字），进入保护模式。控制寄存器 CR0 的第 0 位（PE）置 1，这里用了一个 `lmsw` 指令设置 CR0 的低 16 位。

1.  如何查看实模式的中断程序？

在把内核从 0x10000 搬移到 0x0 之前，0: 0 处存的是实模式下的中断向量表。可以追踪执行 `int 0x13`

4.  如何静态创建 `gdt` 与 `idt` ？

设置 GDT 和 IDT（在内核程序中我们还会再次设置，这里只是为了进入保护模式而做的准备）。GDT/IDT 的内容在这里是静态配置的，也就是说，在汇编源程序里提前把 GDT/IDT 的内容写好（使用数据分配语句），作为二进制数据被汇编器处理到二进制文件（引导扇区）里，引导扇区被加载时会一块读到内存里，然后使用 lgdt/lidt 指令指定它们的位置（物理地址）即可。
`lidt idt_48 ! 加载 IDTR。6 字节操作数：2 字节表长度，4 字节线性基地址。`
`lgdt gdt_48 ! 加载 GDTR。6 字节操作数：2 字节表长度，4 字节线性基地址。`
 idt_48 处的 48 位字（3 个 word）是全 0 的，这里只是把 IDTR 初始化成全 0，后面在内核里还会设置真正的 IDT 的。
 gdt_48 处的 48 位字，低 16 位（GDT 大小）是 0x7FF。高 32 位是 GDT 的起始物理地址，值就是标号 gdt 对应的物理地址（0x7C00+gdt，整个引导程序的入口物理地址是 0x7C00，偏移 gdt）。lgdt 就是把 gdt_48 处的这个 48 位字装入 GDTR。
 标号 gdt 处的 GDT 数据，每 64 位（8 字节，4 个 word）对应一个索引从 0 开始的 GDT 描述符。第 0 个描述符必须是全 0。
```asm
50 gdt: .word 0,0,0,0 ! 段描述符 0，不用。每个描述符项占 8 字节。
51
52 .word 0x07FF ! 段描述符 1。8Mb - 段限长值=2047 (2048*4096=8MB)。
53 .word 0x0000 ! 段基地址=0x00000。
54 .word 0x9A00 ! 是代码段，可读/执行。
55 .word 0x00C0 ! 段属性颗粒度=4KB，80386。
56
57 .word 0x07FF ! 段描述符 2。8Mb - 段限长值=2047 (2048*4096=8MB)。
58 .word 0x0000 ! 段基地址=0x00000。
59 .word 0x9200 ! 是数据段，可读写。
60 .word 0x00C0 ! 段属性颗粒度=4KB，80386。
```
第二个段描述符对应一个从线性地址 0x00000000 开始的代码段。在跳到内核程序时，让 CS 对应到这个代码段描述符。这个描述符对应的选择子是 16 位整数 0x08，0x08 的低 2 位为 0（特权级 =0），第 2 位为 0（GDT 描述符），高 13 位为 0x01（GDT 的索引为 1 的描述符，就是这个代码段描述符）。
5.  如何从实模式切换到保护模式？

设置控制寄存器 CR0（即机器状态字），进入保护模式。控制寄存器 CR0 的第 0 位（PE）置 1，这里用了一个 `lmsw` 指令设置 CR0 的低 16 位。
```asm
mov ax,#0x0001 ! 在 CR0 中设置保护模式标志 PE（位 0）。
lmsw ax ! 然后跳转至段选择符值指定的段中，偏移 0 处。
```
6.  调试跟踪 `jmpi 0,8` ，解释如何寻址？

段选择符值 8 对应 GDT 表中第 2 个 (索引为 1） 段描述符。就是基址为 0x0 的代码段，进入我们搬移到那的内核代码 `head.S`.
```
jmpi 0,8 ! 注意此时段值已是段选择符。该段的线性基地址是 0。
```


## 调试内核引导程序 `head. S`
`head.S` 的工作是：
- 初始化 GDT 和 IDT
- 初始化定时芯片 8253
- 初始化 TSS
- 移动到任务 0 用户程序

首先加载数据段寄存器 DS、堆栈段寄存器 SS 和堆栈指针 ESP。所有段的线性基地址都是 0。
```asm
movl $0x10,%eax # 0x10 是 GDT 中数据段选择符。
mov %ax,%ds
lss init_stack,%esp
```
![](./images/Pasted%20image%2020230515172753.png)
其中 init_stack 是 ：![](./images/Pasted%20image%2020230515175853.png)
它的偏移值其实也是 0x0，所以就是让 `esp` 初始指向 `init_stack`，接着 `call setup_idt` 和 `call setup_gdt` 分别设置 IDT 和 GDT.
```asm
setup_idt: # 把所有 256 个中断门描述符设置为使用默认处理过程。
lea ignore_int,%edx # 设置方法与设置定时中断门描述符的方法一样。
movl $0x00080000,%eax # 选择符为 0x0008。
movw %dx,%ax
movw $0x8E00,%dx # 中断门类型，特权级为 0。
lea idt,%edi
mov $256,%ecx # 循环设置所有 256 个门描述符项。
rp_idt: movl %eax,(%edi)
movl %edx,4(%edi)
addl $8,%edi
dec %ecx
jne rp_idt
lidt lidt_opcode # 最后用 6 字节操作数加载 IDTR 寄存器。
ret
```
![](./images/Pasted%20image%2020230515174412.png)
这段程序构造了一个 64 位字，放在 {edx, eax} 中，然后用一个 256 次循环把这个 64 位字填到 IDT 开始的内存区里。将这个默认的陷阱门描述符循环填满 256 个中断门描述符。设置完后用 lidt 把 idt 基址从 `eax` 传回给 `IDTR`。
设置完后的 idt:
![](./images/Pasted%20image%2020230515175228.png)
接着跳转到 setup_gdt `setup_gdt`, 使用 6 字节操作数 lgdt_opcode 设置 GDT 表位置和长度: `lgdt lgdt_opcode`
```
lgdt_opcode:
.word (end_gdt -gdt)-1
.long gdt
```
包含 GDT 的大小和物理地址就是标号 gdt（因为 head. s 的二进制内容被搬运到 0x00000000 处了，数据和代码段基址都是 0，因此 head. s 的标号就等于物理地址）
![](./images/Pasted%20image%2020230515175754.png)
![](./images/Pasted%20image%2020230515175816.png)
设置完后回到内核主程序，重新加载段寄存器 `ds,es,fs,gs,和栈寄存器esp`，对应到 GDT 中设置的段描述符。
然后开始设置 8253 定时芯片。把计数器通道 0 设置成每隔 10 毫秒向中断控制器发送一个中断请求信号。
然后在 IDT 表第 8 和第 128（0x80）项处分别设置定时中断门描述符和系统调用陷阱门描述符。
![](./images/Pasted%20image%2020230515180658.png)
这条是系统调用的陷阱门描述符 0x80
```
movl $0x00080000, %eax # 中断程序属内核，即 EAX 高字是内核代码段选择符 0x0008。
movw $timer_interrupt, %ax # 设置定时中断门描述符。取定时中断处理程序地址。
movw $0x8E00, %dx # 中断门类型是 14（屏蔽中断），特权级 0 或硬件使用。
movl $0x08, %ecx # 开机时 BIOS 设置的时钟中断向量号 8。这里直接使用它。
lea idt(,%ecx,8), %esi # 把 IDT 描述符 0x08 地址放入 ESI 中，然后设置该描述符。
movl %eax,(%esi)
movl %edx,4(%esi)
movw $system_interrupt, %ax # 设置系统调用陷阱门描述符。取系统调用处理程序地址。
movw $0xef00, %dx # 陷阱门类型是 15，特权级 3 的程序可执行。
movl $0x80, %ecx # 系统调用向量号是 0x80。
lea idt(,%ecx,8), %esi # 把 IDT 描述符项 0x80 地址放入 ESI 中，然后设置该描述符。
movl %eax,(%esi)
movl %edx,4(%esi)
```
最终设置完后：
看到 IDT 中的变化，设置好的时钟中断：
![](./images/Pasted%20image%2020230515181131.png)
系统调用描述符：![](./images/Pasted%20image%2020230515181206.png)
之后人工建立一个内核栈保存的用于中断返回的上下文，再通过一条 `iret`，将特权级变为用户态，去执行用户程序，且在设置好时钟中断和系统调用后就可以去进行基本用户程序的执行任务切换了：
`pushfl` 将 EFLAGS 的 NT 标志位（第 14 位）置 0
`movl $TSS0_SEL, %eax   ltr %ax ` # 把任务 0 的 TSS 段选择符加载到任务寄存器 TR
`movl $LDT0_SEL, %eax  lldt %ax  ` # 把任务 0 的 LDT 段选择符加载到局部描述符表寄存器 LDTR。
![](./images/Pasted%20image%2020230515181846.png)

![](./images/Pasted%20image%2020230515195337.png)
特权级变到 0 时应切换到的 SS 和 ESP，即任务 0 的内核栈栈顶（在中断处理程序中使用），ESP 对应标号 krn_stk0 处的内存区，SS 对应 GDT 中的内核数据段选择子 0x10。另外一个是任务 0 的 LDT 选择子 LDT0_SEL。
![](./images/Pasted%20image%2020230515195459.png) ![](./images/Pasted%20image%2020230515195816.png)
最后把为执行 iret 切换到用户态建立一个内核栈中中断返回的上下文。
```asm
sti # 现在开启中断，并在栈中营造中断返回时的场景。
pushl $0x17 # 把任务 0 当前局部空间数据段（堆栈段）选择符入栈。
pushl $init_stack # 把堆栈指针入栈（也可以直接把 ESP 入栈）。
pushfl # 把标志寄存器值入栈。
pushl $0x0f # 把当前局部空间代码段选择符入栈。
pushl $task0 # 把代码指针入栈。
iret # 执行中断返回指令，从而切换到特权级 3 的任务 0 中执行。
```
![](./images/Pasted%20image%2020230515223602.png)
将 0x17 和 init_stack 标号地址压入栈顶，这样 iret 后，处理会自动把栈顶切换对于 ldt 中数据段开始的 0x17: init_stack 处。
然后将 0x0F 和 task0 标号地址压入栈顶，0x0F 就是刚才在 LDT 里创建的用户代码段的选择子，task0 标号就是任务 0 用户程序的入口，0x0F: task0 就是我们跳转的目的地址。
然后 `iret` 中断返回指令会把我们刚刚压入栈中的“中断上下文”恢复到对应寄存器中，然后以用户态执行 task0。
###  `iret` 前后的变化
`iret` 之前：
![](./images/Pasted%20image%2020230515224620.png)
栈顶正式 task0 的代码入口
然后是 `0x000F` --LDT 中的代码段段选择符，再往下有 `init_stack` 和对应的段选择符 `0x0017`
![](./images/Pasted%20image%2020230515224921.png)
的确跳到了对应的代码处，而且栈完成了转换！

## 系统调用（`int 0x80` ）前后栈的变换
![](./images/Pasted%20image%2020230515225212.png)
执行后：
![](./images/Pasted%20image%2020230515225257.png)
SS: ESP 自动切换到了任务 0 内核栈 0x 10:0 x0E4C 处，并且 CS: EIP 变到了系统调用中断处理程序入口（标号 system_interrupt）地址 0x 08:0 x0166 处。栈顶存放的是跳转前的下一条指令地址 `0x10eb` 和局部代码段选择子，还有 `eflags` 和栈顶和局部数据段选择子。
task0 的内核栈栈顶正好切换到 task0 tss 中指定的位置：
![](./images/Pasted%20image%2020230515225735.png)
不过是压入了上述用于返回时恢复的字段之后的那个位置：
![](./images/Pasted%20image%2020230515225840.png)

