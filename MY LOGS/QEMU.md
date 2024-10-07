#qemu #kernel

*先按住ctrl + a，然后放开,再按h、x、b等 *

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

`make -nB` 看到所有编译选项 ^7fea45

make qemu 在qemu运行xv6


