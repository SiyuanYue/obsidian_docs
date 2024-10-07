

#GDB    #调试  #linux

# GDB  MANUAL STUDY


#  前言


官网 ：  https://sourceware.org/gdb/

### What is GDB?

GDB, the GNU Project debugger, allows you to see what is going on inside another program while it executes -- or what another program was doing at the moment it crashed.

GDB can do four main kinds of things (plus other things in support of these) to help you catch bugs in the act:

-   Start your program, specifying anything that might affect its behavior.
-   Make your program stop on specified conditions.
-   Examine what has happened, when your program has stopped.
-   Change things in your program, so you can experiment with correcting the effects of one bug and go on to learn about another.

Those programs might be executing on the same machine as GDB (native), on another machine (remote), or on a simulator. GDB can run on most popular UNIX and Microsoft Windows variants, as well as on Mac OS X.

检查gdb版本 与是否成功安装
`gdb --version

gdb manual ：[Top (Debugging with GDB) (sourceware.org)](https://sourceware.org/gdb/current/onlinedocs/gdb/)

# GDB 命令
` man gdb

`(gdb) p (char **) environ`
`$2 = (char **) 0x0`
`(gdb) wa (char **)environ`

# `bt`

# `wa`

# `p/print`

`直接r argv[1] ...  eg. r 1   那么argv[1]=1`

`info frame`


### 一份简单点的mannual:
https://www.cprogramming.com/gdb.html