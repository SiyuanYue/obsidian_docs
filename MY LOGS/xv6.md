# [6.S081 / Fall 2019 (mit.edu)](https://pdos.csail.mit.edu/6.828/2019/xv6.html)

# xv6-book文档：[xv6: a simple, Unix-like teaching operating system (mit.edu)](https://pdos.csail.mit.edu/6.828/2019/xv6/book-riscv-rev0.pdf)

#qemu : `ctrl + a x` 关闭虚拟机      

  `Ctrl-a h`
      Print this help
  `Ctrl-a x`
      Exit emulator
  `Ctrl-a s`
      Save disk data back to file (if -snapshot)
  `Ctrl-a t`
      Toggle console timestamps
  `Ctrl-a b`
      Send break (magic sysrq in Linux)
  `Ctrl-a c`
      Rotate between the frontends connected to the multiplexer (usually this switches between the monitor and the console)
  `Ctrl-a Ctrl-a`
      Send the escape character to the frontend

 `ctrl + a c` 切换到monitor

monitor (gdb)： `info mem`       `info registers`

make -nB 看到所有编译选项

make qemu 在qemu运行xv6

ecall:
Disable interrupts by clearing SIE. 
Copy the pc to sepc. 
Save the current mode (user or supervisor) in the SPP bit in sstatus. 
Set scause to reflect the interrupt’s cause. 
Set the mode to supervisor. 
Copy stvec to the pc. 
Start executing at the new pc.