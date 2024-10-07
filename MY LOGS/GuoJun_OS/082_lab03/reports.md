# LAB3 操作系统的引导
## 实验目的
- 熟悉实验环境；

- 建立对操作系统引导过程的深入认识；

- 掌握操作系统的基本开发过程；

- 能对操作系统代码进行简单的控制，揭开操作系统的神秘面纱。

## 实验环境：
vmware 16；Ubuntu 20x04 ; 老师提供的新环境
## 实验内容：
改写 `bootsect.s` 主要完成如下功能：

1. `bootsect.s` 能在屏幕上打印一段提示信息“XXX is booting...”，其中 XXX 是你给自己的操作系统起的名字，例如 LZJos、Sunix 等（可以上论坛上秀秀谁的 OS 名字最帅，也可以显示一个特色 logo，以表示自己操作系统的与众不同。）

```asm
# Print some inane message
    mov $0x03, %ah      # read cursor pos
    xor %bh, %bh
    int $0x10
    mov $24, %cx
    mov $0x0007, %bx        # page 0, attribute 7 (normal)
    #lea    msg1, %bp
    mov     $msg1, %bp
    mov $0x1301, %ax        # write string, move cursor
    int $0x10
   ...
 
msg1:
    .byte 13,10
    .ascii "YSY OS is RUNNING..."
    # .ascii "Loading system ..."
    .byte 13,10,13,10
```

改写 `setup.s` 主要完成如下功能：

1. `bootsect.s` 能完成 `setup.s` 的载入，并跳转到 `setup.s` 开始地址执行。而 `setup.s` 向屏幕输出一行"Now we are in SETUP"。
```asm
_start:
    mov $0x03, %ah      # read cursor pos
    xor %bh, %bh
    int $0x10
    mov $25, %cx
    mov $0x0007, %bx        # page 0, attribute 7 (normal)
    # lea   msg1, %bp
    mov $msg, %bp
    mov %cs, %ax
    mov %ax, %es # es:bp 此寄存器对指向要显示的字符串起始位置处,es在新汇编文件中要重置为正确值
    mov $0x1301, %ax        # write string, move cursor
    int $0x10
```
这里注意 `es: bp` 指向要显示的字符串起始位置处，在跳到 setup. S 后 `%es` 寄存器会被更改，这里要设置为正确值（与 `CS` 相同）。
2. `setup.s` 能获取至少一个基本的硬件参数（如内存参数、显卡参数、硬盘参数等），将其存放在内存的特定地址，并输出到屏幕上。
![](images/Pasted%20image%2020230623030449.png)
存入内存指定位置：
![](images/Pasted%20image%2020230623030532.png)
qemu 中
`Cursor：0x0b17         Memory:0x3b80    Cylinders:0x00cc   Heads:0x0010    Sectors:0x0026`
## 实验结果：
成功基本的硬件参数（如内存参数、显卡参数、硬盘参数等），将其存放在内存的特定地址，并输出到屏幕上。
![](images/Pasted%20image%2020230623025942.png)
但 bochs 跟 qemu 输出获取的值不一样：
![](images/Pasted%20image%2020230623030116.png)
## 问题回答 ：
>有时，继承传统意味着别手蹩脚。 `x86` 计算机为了向下兼容，导致启动过程比较复杂。 请找出 `x86` 计算机启动过程中，被硬件强制，软件必须遵守的两个“多此一举”的步骤（多找几个也无妨），说说它们为什么多此一举，并设计更简洁的替代方案。

答：
x86 计算机启动过程中，被硬件强制、软件必须遵守的一些“多此一举”的步骤包括：
1. BIOS自检检测所有硬件设备这一步通常需要几秒钟的时间，且并不是每次开机都需要检测。它其实是为了向下兼容而设计的，以确保计算机能够适应各种类型的硬件。但对于现代计算机而言，通常只需要检测一次，因此这一步相当于是多余的。

替代方案：使用更现代的UEFI固件来代替BIOS，UEFI启动不需要进行自检，因此能够更快速地启动操作系统

2. BIOS 在物理地址 0 处开始初始化中断向量表，而操作系统的页目录表最好放在物理地址 0 处，方便实现内核代码的逻辑地址和物理地址的恒等映射。因此 `bootsect.s` 在读入操作系统 `system` 模块时，先将它放在 `0x10000` 处，等 `setup.s` 使用完 BIOS 中断后，再将操作系统 `system` 模块拷贝到物理地址 0 处。

替代方案是修改 BIOS，让它将中断向量表放在其他不冲突的地方。

3. 实模式和保护模式的切换

替代方案：可以直接启动计算机进入保护模式，避免实模式和保护模式的切换过程，从而减少启动时间。
