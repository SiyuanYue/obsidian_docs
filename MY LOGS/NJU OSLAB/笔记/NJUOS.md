
热身实验
-   Lab0 (amgame): 熟悉代码框架

正经实验
-   Lab1 (pmm): Physical memory management
    -   多处理器 (bare-metal) 上的 kalloc/free
-   Lab2 (kmt): Kernel multi-threading
    -   中断和异常驱动的上下文 (线程) 切换
-   Lab3 (uproc): User processes
    -   虚拟地址空间、用户态进程和系统调用
-   Lab4 (vfs): Virtual file system
    -   devfs, procfs, 简单的文件系统；ELF 加载器

---

**Bare-metal 与程序员的约定**
    CPU reset 后，处理器处于某个确定的状态
    -   PC 指针一般指向一段 memory-mapped ROM
        -   ROM 存储了厂商提供的 firmware (固件)
    -   处理器的大部分特性处于关闭状态
        -   缓存、虚拟存储、……  
    Firmware (固件，厂商提供的代码)
    -   将用户数据加载到内存
        -   例如存储介质上的第二级 loader (加载器)
        -   或者直接加载操作系统 (嵌入式系统)



## 动态分析工具：Sanitizers

没用过 lint/sanitizers？
-   [AddressSanitizer](https://clang.llvm.org/docs/AddressSanitizer.html) (asan); [(paper)](https://www.usenix.org/conference/atc12/technical-sessions/presentation/serebryany): 非法内存访问
    -   Buffer (heap/stack/global) overflow, use-after-free, use-after-return, double-free, ...
    -   Demo: [uaf.c](http://jyywiki.cn/pages/OS/2022/demos/uaf.c); [kasan](https://www.kernel.org/doc/html/latest/dev-tools/kasan.html)
-   [ThreadSanitizer](https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html) (tsan): 数据竞争
    -   Demo: [fish.c](http://jyywiki.cn/pages/OS/2022/demos/fish.c), [sum.c](http://jyywiki.cn/pages/OS/2022/demos/sum.c), [peterson-barrier.c](http://jyywiki.cn/pages/OS/2022/demos/peterson-barrier.c); [ktsan](https://github.com/google/ktsan)
-   [MemorySanitizer](https://clang.llvm.org/docs/MemorySanitizer.html) (msan): 未初始化的读取
-   [UBSanitizer](https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html) (ubsan): undefined behavior
    -   Misaligned pointer, signed integer overflow, ...
    -   Kernel 会带着 `-fwrapv` 编译

程序执行 = 状态机执行

-   我们能不能 “hack” 进这个状态机
    -   观察状态机的执行
        -   strace/gdb   `strace -T`能观看每个系统调用花费的时间
        - #GDB  ：
        -   `p  = print`
        -    `info locals `：看局部变量 `p val`
        -    `info v`   
        - `snapshot` 将一个状态拷贝，之后接着调试?`reverse?   reversei?`
        - **GDB中:  `record full`  开始记录模式**
        -                `rsi`  回溯一条指令   只能回溯大部分指令，`syscall`就不能
        -           `record stop`  停止记录模式
    -   甚至记录和改变状态机的执行
    - 采样状态机的执行
	    - perf与一些子命令配合使用:
		-   stat: 测量运行单个程序或是系统运行一段时间内的性能计数
		-   top: 动态查看当前系统的热点函数
		-   record: 测量和保存单个程序的采样数据
		-   report: 分析由perf record产生的数据文件
		-   list: 列举出perf支持的性能计数事件


## 用 profiler (perf) 和Sanitizers 帮助我们做实验时 debug（native 编译）
你们遇到的大部分情况
-   二八定律：80% 的时间消耗在非常集中的几处代码
-   L1 (pmm): 小内存分配时的lock contention
    -   profiler 直接帮你解决问题

一门现代编程语言？ python、go、rust、现代C++？
## 进程的地址空间
`char *p` 可以和 `intptr_t` 互相转换
-   可以指向 “任何地方”
-   合法的地址 (可读或可写)
    -   代码 (`main`, `%rip` 会从此处取出待执行的指令)，只读
    -   数据 (`static int x`)，读写
    -   堆栈 (`int y`)，读写
    -   运行时分配的内存 (???)，读写
    -   动态链接库 (???)
-   非法的地址
    -   `NULL`，导致 segmentation fault

---
它们停留在概念中，但实际呢？
  #gdb  info inferiors 在 gdb 中查看当前运行程序的进程号
  
pmap (1) - report memory of a process
**“执行系统调用时，进程陷入内核态执行”——不，不是的。**
vdso (7): Virtual system calls: 只读的系统调用也许可以不陷入内核执行。 man 7 vdso
--> vvar ：**所有进程共享的一段内存** 
	例子: time (2)
    -   直接调试 [vdso.c](http://jyywiki.cn/pages/OS/2022/demos/vdso.c)
    -   时间：内核维护秒级的时间 (所有进程映射同一个页面)
能不能让其他系统调用也 trap 进入内核？
-   疯狂的事情也许真的是能实现的 (这算是魔法吗？)
    -   [FlexSC: Flexible system call scheduling with exception-less system calls](https://www.usenix.org/conference/osdi10/flexsc-flexible-system-call-scheduling-exception-less-system-calls) (OSDI'10).

使用共享内存和内核通信！
-   内核线程在 spinning 等待系统调用的到来
-   收到系统调用请求后立即开始执行
-   进程 spin 等待系统调用完成
-   如果系统调用很多，可以打包处理

## 地址空间：实现进程隔离
每个 `*ptr` 都只能访问本进程 (状态机) 的内存
-   除非 mmap 显示指定、映射共享文件或共享内存多线程
-   实现了操作系统最重要的功能：进程之间的隔离

#### 更强大的游戏外挂？
游戏也是程序，也是状态机
-   通过 API 调用 (和系统调用) 最终取得状态、修改状态
-   想象成是一个 “为这个游戏专门设计的 gdb”、
-  角度轻奇真的！！！！
## A Zero-dependency UNIX Shell (from xv6)

![](http://jyywiki.cn/pages/OS/img/pipe.gif)

我们应该如何阅读 [sh-xv6.c](http://jyywiki.cn/pages/OS/2022/demos/sh-xv6.c) 的代码？
-   strace + gdb!
    -   set follow-fork-mode, set follow-exec-mode

关键点
-   命令的执行、重定向、管道和对应的系统调用
-   这里用到 [minimal.S](http://jyywiki.cn/pages/OS/2022/demos/minimal.S) 会简化输出

`echo './a.out > /tmp/a.txt' | strace -f ./sh`
-   还可以用管道过滤不想要的系统调用

## The Shell Programming Language
基于文本替换的快速工作流搭建
-   重定向: `cmd > file < file 2> /dev/null`
-   顺序结构: `cmd1; cmd2`, `cmd1 && cmd2`, `cmd1 || cmd2`
-   管道: `cmd1 | cmd2`
-   预处理: `$()`, `<()`
-   变量/环境变量、控制流……

Job control
-   类比窗口管理器里的 “叉”、“最小化”
    -   jobs, fg, bg, wait
    -   (今天的 GUI 并没有比 CLI 多做太多事)

## UNIX Shell: Traps and Pitfalls
-   操作的 “优先级”？
    -   `ls > a.txt | cat` (bash/zsh)
-   文本数据 “责任自负”
    -   有空格？后果自负！(PowerShell: 我有 object stream pipe 啊喂)
-   行为并不总是 intuitive

`$ echo hello > /etc/a.txt bash: /etc/a.txt: Permission denied $ sudo echo hello > /etc/a.txt bash: /etc/a.txt: Permission denied`
## Shell 还有一些未解之谜
为什么 Ctrl-C 可以退出程序？
为什么有些程序又不能退出？
-   没有人 read 这个按键，为什么进程能退出？
-   Ctrl-C 到底是杀掉一个，还是杀掉全部？
    -   如果我 fork 了一份计算任务呢？
    -   如果我 fork-execve 了一个 shell 呢？
        -   Hmmm……
		为什么 [fork-printf.c](http://jyywiki.cn/pages/OS/2022/demos/fork-printf.c) 会在管道时有不同表现？
		 libc 到底是根据什么调整了缓冲区的行为？
		为什么 Tmux 可以管理多个窗口？
## 答案：终端
终端是 UNIX 操作系统中一类非常特别的设备！
-   RTFM: tty, stty, ...
- - `Print the file name of this terminal:`     
	`tty`                                        
RTFM: setpgid/getpgid(2)，它解释了 *process group*,  *session*, *controlling terminal* 之间的关系
——你神奇地发现，读手册不再是障碍了！
![session](http://jyywiki.cn/pages/OS/img/tty-session.png)
## Job Control: RTFM (cont'd)

-   A session can have a _controlling terminal_.
    -   At any time, one (and only one) of the process groups in the session can be the _foreground process group_ for the terminal; the remaining process groups are in the _background_.
        -   `./a.out &` 创建新的进程组 (使用 setpgid)
    -   If a signal is generated from the terminal (e.g., typing the interrupt key to generate `SIGINT`), that signal is sent to the foreground process group.
        -   Ctrl-C 是终端 (设备) 发的信号，发给 foreground 进程组
        -   所有 fork 出的进程 (默认同一个 PGID) 都会收到信号
        -   可以修改 [signal-handler.c](http://jyywiki.cn/pages/OS/2022/demos/signal-handler.c) 观察到这个行为

![[Pasted image 20220823164923.png]]
[Freestanding 环境](https://en.cppreference.com/w/cpp/freestanding)下也可以使用的定义
-   [stddef.h](https://www.cplusplus.com/reference/cstddef/) - `size_t`
-   [stdint.h](https://www.cplusplus.com/reference/cstdint/) - `int32_t`, `uint64_t`
-   [stdbool.h](https://www.cplusplus.com/reference/cstdbool/) - `bool`, `true`, `false`
-   [float.h](https://www.cplusplus.com/reference/cfloat/)
-   [limits.h](https://www.cplusplus.com/reference/climits/)
-   [stdarg.h](https://www.cplusplus.com/reference/cstdarg/)
    -   syscall 就用到了 (但 syscall0, syscall1, ... 更高效)
-   [inttypes.h](https://www.cplusplus.com/reference/cinttypes/)
    -   回答了你多年来的疑问！
    -   在你读过了小白阶段以后，就真的是 friendly manual 了

## 然后，系统调用也要用得方便！
> 系统调用是操作系统 “紧凑” 的最小接口。并不是所有系统调用都像 fork 一样可以直接使用。

低情商 API：
`extern char **environ; char *argv[] = { "echo", "hello", "world", NULL, }; if (execve(argv[0], argv, environ) < 0) {   perror("exec"); }`
RTFM man execve
高情商 API：
`execlp("echo", "echo", "hello", "world", NULL); system("echo hello world");`
# 封装 (1): 纯粹的计算
## [string.h](https://www.cplusplus.com/reference/cstring/): 字符串/数组操作
简单，不简单
`void *memset(void *s, int c, size_t n) {   for (size_t i = 0; i < n; i++) {     ((char *)s)[i] = c;   }   return s; }`
让我们看看 clang 把它编译成了什么……
-   以及，线程安全性？[memset-race.c](http://jyywiki.cn/pages/OS/2022/demos/memset-race.c)
-   标准库只对 “标准库内部数据” 的线程安全性负责
    -   例子：printf 的 buffer

## 排序和查找
低情商 (低配置) API
`void qsort(void *base, size_t nmemb, size_t size,            int (*compar)(const void *, const void *));  void *bsearch(const void *key, const void *base,               size_t nmemb, size_t size,               int (*compar)(const void *, const void *));`
高情商 API
`sort(xs.begin(), xs.end(), [] (auto& a, auto& b) {...});`
`xs.sort(lambda key=...)`
## 更多的例子
RTFM！
-   更多的 [stdlib.h](https://www.cplusplus.com/reference/cstdlib/) 中的例子
    -   atoi, atol, atoll, strtoull, ...
    -   rand (注意线程安全), ...
-   [setjmp.h](https://www.cplusplus.com/reference/csetjmp/)
    -   体会到我们精心设计的良苦用心？
        -   一次掉队，终身掉队 😂
-   [math.h](https://www.cplusplus.com/reference/cmath/)
    -   这玩意复杂了; 《操作系统》课直接摆烂
        -   [Automatically improving accuracy for floating point expressions](https://dl.acm.org/doi/10.1145/2737924.2737959) (PLDI'15, Distinguished Paper 🏅)

# 封装 (2): 文件描述符
## [stdio.h](https://www.cplusplus.com/reference/cstdio/): 你熟悉的味道
`FILE *` 背后其实是一个文件描述符
-   我们可以用 gdb 查看具体的 `FILE *` (例如 stdout)
    -   可以 “窥探” 到 glibc 的一些内部实现
    -   可以加载 glibc 的 debug symbols
        -   在这门课上不推荐：你调试起来会很浪费时间
-   封装了文件描述符上的系统调用 (fseek, fgetpos, ftell, feof, ...)

![[Pasted image 20220828220843.png]]

vprintf 系列
-   使用了 `stdarg.h` 的参数列表

`int vfprintf(FILE *stream, const char *format, va_list ap); int vasprintf(char **ret, const char *format, va_list ap);`
## popen 和 pclose
我们在 [dosbox-hack.c](http://jyywiki.cn/pages/OS/2022/demos/dosbox-hack.c) 中使用了它
-   一个设计有缺陷的 API
    -   Since a pipe is by definition unidirectional, the type argument may specify only reading or writing, _not both_; the resulting stream is correspondingly read-only or write-only.

高情商 API (现代编程语言)
`subprocess.check_output(['cat'],   input=b'Hello World', stderr=subprocess.STDOUT)`
`let dir_checksum = {   Exec::shell("find . -type f")     | Exec::cmd("sort") | Exec::cmd("sha1sum") }.capture()?.stdout_str();`
# 封装 (3): 更多的进程/操作系统功能
## err, error, perror
所有 API 都可能失败
`$ gcc nonexist.c gcc: error: nonexist.c: No such file or directory`
这个 “No such file or directory” 似乎见得有点多？
-   `cat nonexist.c, wc nonexist.c` 都是同样的 error message
-   这不是巧合！
    -   我们也可以 “山寨” 出同样的效果
    -   `warn("%s", fname);` (观察 strace)
        -   `err` 可以额外退出程序
-   errno 是进程共享还是线程独享？
    -   这下知道协程的轻量了吧
## environ (7)
我们也可以实现自己的 [env.c](http://jyywiki.cn/pages/OS/2022/demos/env.c)

-   问题来了：environ 是谁赋值的？
    -   这个函数又是在哪里定义的？

RTFM 后
-   对环境变量的理解又上升了
>man 7 environ
   extern char ** environ
   gdb: wa (char**)environ   look it!
 
# 封装 (4): 地址空间
pmap 查看进程地址空间


## OS -17
mmap 向操作系统申请映射一段匿名内存 ，操作系统从地址空间中找到一段连续内存给你


