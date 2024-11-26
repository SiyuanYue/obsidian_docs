## **为什么不想要coredump？**

也许你会说，coredump很好啊，程序异常崩溃时候，coredump会提供程序的内存、堆栈、寄存器、函数栈等各种信息，是定位BUG的利器啊。

的确，我也同意，coredump有诸多好处。但是有一种场景让我不得不放弃它 - **如果程序运行时占用大量内存，异常崩溃时生成的coredump文件可能会非常非常大。**比如，某个程序运行时占用20GB内存，当它异常时可能会生成40GB大小的core文件，而生成文件的写盘过程非常缓慢，这会严重影响系统的整体运行情况。可以假想，这个程序如果异常崩溃后其实也没什么太大影响，因为守护进程会自动检测并运行新的进程实例来恢复业务。但是，40GB大小的core文件写盘需要数分钟甚至数十分钟时间，在这期间业务就完全瘫痪了，这肯定不是你想看到的情况。

你可能会说，没关系啊，可以通过 ulimit -c <core_file_max_size> 来控制core文件大小。

但是，我们要获取的信息中最重要的，通常是异常发生时函数调用栈，而如果裁剪core文件的大小，则再用gdb bt可能无法获得函数调用栈。更何况，对于这种占用内存超大的程序，如果指望通过分析数十GB的core文件来定位问题，有点儿不太现实。

大多数况下，如果程序员对程序逻辑、业务流程足够熟悉，如果得到异常发生时的函数调用栈，通常就能定位并解决问题了。那么，有没有什么方法，可以不用生成coredump文件，只生成异常发生时的函数调用栈呢？

有的！可以用backtrace()、backtrace_symbol() API、适当的gcc编译选项、addr2line工具，实现异常函数栈输出，而无须生成coredump文件。

![](https://pic1.zhimg.com/v2-391399d5c107d426737f122e0d3898f8_1440w.jpg)

## **一个例程**

如下所示，我给出一个完整的小例子，注意 g_iTestFlag 全局变量如果设为0，表示按常规方式生成coredump文件；如果设为1，表示不生成coredump文件，程序自己截获SIGSEGV信号，自己检测异常的发生并打印函数栈。

> test_backtrace_addr2line.c

```c
#include <stdlib.h>
#include <stdio.h>
#include <stddef.h>
#include <signal.h>
#include <execinfo.h>

// 0: GENERATE COREDUMP FILE 
// 1: PRINT STACK BY SELF
int g_iTestFlag = 1;
#define ADDR_MAX_NUM 100

void CallbackSignal (int iSignalNo) {
    printf ("CALLBACK: SIGNAL:\n", iSignalNo);
    void *pBuf[ADDR_MAX_NUM] = {0};
    int iAddrNum = backtrace(pBuf, ADDR_MAX_NUM);
    printf("BACKTRACE: NUMBER OF ADDRESSES IS:%d\n\n", iAddrNum);
    char ** strSymbols = backtrace_symbols(pBuf, iAddrNum);
    if (strSymbols == NULL) {
        printf("BACKTRACE: CANNOT GET BACKTRACE SYMBOLS\n");
        return;
    }
    int ii = 0;
    for (ii = 0; ii < iAddrNum; ii++) {
        printf("%03d %s\n", iAddrNum-ii, strSymbols[ii]);
    }
    printf("\n");
    free(strSymbols);
    strSymbols = NULL;
    exit(1); // QUIT PROCESS. IF NOT, MAYBE ENDLESS LOOP.
}

void FuncBadBoy() {
    void* pBadThing = malloc(1024*1024*256);
    free (pBadThing);
    free (pBadThing);
}

void FuncBadFather() {
    FuncBadBoy();
}

int main(int argc, char **argv){
    if (g_iTestFlag) {
        signal(SIGSEGV, CallbackSignal);
    }
    FuncBadFather();   
    return 0;
}
```

## **生成coredump的情况（以对比）**

首先，允许在该SHELL生成coredump文件，执行 ulimit -c unlimited，并执行 ulimit -a 确认。其次，程序的编译命令中需要引入 -g 和 -rdynamic 选项以输出函数名等足够的符号信息。

```text
gcc -g -rdynamic -o test_backtrace_addr2line.elf test_backtrace_addr2line.c
```

然后，先把 g_iTestFlag 设置为0，编译并运行程序。可以看到程序异常崩溃，并生成了一个core文件。

```text
gcc -g -rdynamic -o test_backtrace_addr2line.elf test_backtrace_addr2line.c
./test_backtrace_addr2line.elf 
*** [test_backtrace_addr2line] Segmentation fault (core dumped)

-rw------- 1 root root 188416 Dec  2 21:03 core.28097
-rw-r--r-- 1 root root   1302 Dec  2 21:03 test_backtrace_addr2line.c
-rwxr-xr-x 1 root root  11547 Dec  2 21:03 test_backtrace_addr2line.elf
```

再执行 gdb test_backtrace_addr2line.elf core.28006 打开该core文件，进入后执行 bt，查看异常时的函数栈。通过函数栈的 #1 位置可以看到 FuncBadBoy() 函数中第二个 free() 重复释放，从而帮助定位了问题。

```text
gdb test_backtrace_addr2line.elf core.28097 

(gdb) bt
#0  0x0000003f2c47b93c in free () from /lib64/libc.so.6
#1  0x0000000000400afa in FuncBadBoy () at test_backtrace_addr2line.c:35
#2  0x0000000000400b0a in FuncBadFather () at test_backtrace_addr2line.c:39
#3  0x0000000000400b55 in main (argc=1, argv=0x7ffd4f059e28) at test_backtrace_addr2line.c:49
(gdb) q
```

## **不生成coredump的情况**

现在，删除core文件。将源代码中的 g_iTestFlag 设置为1，编译并运行程序。程序可以截获SIGSEGV 信号并打印函数栈。

```text
gcc -g -rdynamic -o test_backtrace_addr2line.elf test_backtrace_addr2line.c

./test_backtrace_addr2line.elf 
CALLBACK: SIGNAL:
BACKTRACE: NUMBER OF ADDRESSES IS:8

008 ./test_backtrace_addr2line.elf(CallbackSignal+0x5a) [0x400a0e]
007 /lib64/libc.so.6() [0x3f2c4326a0]
006 /lib64/libc.so.6(cfree+0x1c) [0x3f2c47b93c]
005 ./test_backtrace_addr2line.elf(FuncBadBoy+0x2e) [0x400afa]
004 ./test_backtrace_addr2line.elf(FuncBadFather+0xe) [0x400b0a]
003 ./test_backtrace_addr2line.elf(main+0x49) [0x400b55]
002 /lib64/libc.so.6(__libc_start_main+0xfd) [0x3f2c41ed5d]
001 ./test_backtrace_addr2line.elf() [0x4008f9]
```

可以看到上边005行应该是异常发生的地方，只能看到 FuncBadBoy 函数，却无法看到具体的文件名、行号。这的确没有 gdb 方便。而且注意到，**用这种方式就不会生成core文件了，这解决了超大coredump文件生成问题。**

```text
ls: cannot access core*: No such file or directory
-rw-r--r-- 1 root root  1302 Dec  2 21:06 test_backtrace_addr2line.c
-rwxr-xr-x 1 root root 11547 Dec  2 21:07 test_backtrace_addr2line.elf
```

对于函数栈每个函数所在的源代码文件名、行号的信息，可以使用 addr2line 工具获取。对上述函数栈尾部的[0xHHHHHHHH]，分别执行 addr2line -Cif -e test_backtrace_addr2line.elf 0xHHHHHHHH 即可获得具体的源文件名、行号。

```text
addr2line -Cif -e test_backtrace_addr2line.elf 0x400afa
FuncBadBoy
/root/prog/src/test2/test_backtrace_addr2line.c:36

addr2line -Cif -e test_backtrace_addr2line.elf 0x400b0a
FuncBadFather
/root/prog/src/test2/test_backtrace_addr2line.c:40

addr2line -Cif -e test_backtrace_addr2line.elf 0x400b55
main
/root/prog/src/test2/test_backtrace_addr2line.c:50
```

## **总结**

最后，让我们总结一下，前提条件是，对于超大内存的进程，不希望生成超大coredump文件，可以接受只获得异常崩溃时的函数栈。那么方法是，程序自己处理 SIGSEGV 信号，通过backtrace()、backtrace_symbol() API获取程序异常崩溃时的函数栈。程序编译时需引入 -g 和 -rdynamic 选项以获取足够的符号信息。在获取异常函数栈后，通过 addr2line 查看每个函数的源代码文件名和行号。

**补充1：objdump -d -l -C -S <ELF_FILE> > 12345.txt**

**补充2：grep -C 10 <异常地址前缀部分> 12346.txt**

  

_Reference:_

_0._ _[老宋的独家号](https://zhuanlan.zhihu.com/lao-song)_

_1. [backtrace_symbols(3) - Linux man page](https://link.zhihu.com/?target=https%3A//linux.die.net/man/3/backtrace_symbols)_

_2.[The GNU C Library: Backtraces](https://link.zhihu.com/?target=https%3A//www.gnu.org/software/libc/manual/html_node/Backtraces.html)_

_3.[Linux下利用backtrace追踪函数调用堆栈以及定位段错误 第2页_Linux编程_Linux公社-Linux系统门户网站](https://link.zhihu.com/?target=http%3A//www.linuxidc.com/Linux/2012-11/73470p2.htm)_

_4.[利用backtrace和backtrace_symbols函数打印调用栈信息 - mickole - 博客园](https://link.zhihu.com/?target=http%3A//www.cnblogs.com/mickole/p/3246702.html)_

_5.[linux backtrace()详细使用说明，分析Segmentation fault](https://link.zhihu.com/?target=http%3A//velep.com/archives/1032.html)_

_6. [addr2line(1) - Linux man page](https://link.zhihu.com/?target=https%3A//linux.die.net/man/1/addr2line)_

_7. [使用 Addr2line 将函数地址解析为函数名](https://link.zhihu.com/?target=http%3A//blog.csdn.net/whz_zb/article/details/7604760)_

_8. [gcc/g++中生成map文件 - CSDN博客](https://link.zhihu.com/?target=http%3A//blog.csdn.net/dj0379/article/details/17011237)_

_9. [把选项传给连接器 | 100个gcc小技巧](https://link.zhihu.com/?target=https%3A//www.ctolib.com/docs/sfile/100-gcc-tips/pass-options-to-linker.html)_

_10. [在linux下使用core dump和map文件调试 - SunBo - 博客园](https://link.zhihu.com/?target=http%3A//www.cnblogs.com/sunyubo/archive/2010/08/25/2282132.html)_

_11.[coredump产生与分析 - 答案是肯定的 - 博客园](https://link.zhihu.com/?target=http%3A//www.cnblogs.com/totopper/archive/2013/05/26/3099611.html)_

_12.[Linux下core文件产生的一些注意问题 - CSDN博客](https://link.zhihu.com/?target=http%3A//blog.csdn.net/fengxinze/article/details/6800175)_