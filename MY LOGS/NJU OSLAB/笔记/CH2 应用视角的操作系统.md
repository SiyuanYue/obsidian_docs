# OS 2
**背景回顾**：操作系统是连接软件和硬件的桥梁。因此想要理解操作系统，我们首先需要对操作系统的服务对象 (应用程序) 有更精确和深刻的理解。

**本讲内容**：程序的状态机模型；回答以下问题：

- 什么是程序？
- 如何在操作系统上构造最小/一般、甚至是图形界面应用程序？
- 编译器的工作原理是什么？

# 操作系统上的最小应用程序
## Hello, OS World
> Operating System: A body of software, in fact, that is responsible for _making it easy to run programs_ (even allowing you to seemingly run many at the same time), allowing programs to share memory, enabling programs to interact with devices, and other fun stuff like that. (OSTEP)

### 要想理解 “操作系统”，就要理解什么是 “程序”
- 那就从 Hello World 开始吧

```C
int main() { printf("Hello, World\n"); }
```
## 意识到的问题
#gcc 编译出来的文件一点也不小
`readelf -a a.out|less`
`objdump -d  hello.o|less`
-   `objdump -d a.out|less` 工具可以查看对应的汇编代码
-    `gcc --verbose` 可以查看所有编译选项 (真不少)
    -   `printf` 变成了` puts@plt`
-   `-Wl,--verbose` 可以查看所有链接选项 (真不少)
    -   原来链接了那么多东西
    - >The command you provided is used to display the linker's verbose output in GCC. This can be useful for debugging purposes or to understand the linker's behavior during the linking stage of compiling a program.
    - The output will include detailed information about the linker's actions, such as the libraries it is searching for, the directories it is looking in, and the symbols it is resolving.
    -   还解释了 `end` 符号的由来
-   `-static` 会链接 `libc` (大量的代码)
![[NJUOS （-1）.png]]
## 强行构造最小的 Hello, World？
我们可以手动链接编译的文件，直接指定二进制文件的入口
-   直接用 ld 链接失败
    -   ld 不知道怎么链接 printf
-   不调用 printf 可以链接
    -   但得到奇怪的警告 (可以定义成 `_start` 避免警告)
    -   而且 Segmentation Fault 了
-   `while (1);` 可以链接并正确运行
## 为什么？怎么办？
> 我在操作系统课的练习题中写了一个代码，发生了 Segmentation Fault，我阅读了代码，无法定位到问题的地方。程序也没有任何输出。我应该怎么办？

### **学习任何别人学过的东西，别人都遇到过你遇到过的困难**
- 你只需要提出问题
- 随着熟练度的增长，你就可以 RTFM 了
    - 此时 M 变得 friendly
    - 在你问不出问题时，[Manual](http://sourceware.org/gdb/documentation/) 的价值就体现了

### 人类的新时代即将来临
- (你问不出问题的时候，langchain 可以帮你枚举)
## 什么是程序？
### 答案在这里：
```C
struct CPUState { uint32_t regs[32], csrs[CSR_COUNT]; uint8_t *mem; uint32_t mem_offset, mem_size; };
```
### 处理器：无情的、执行指令的**状态机**
- 从 $M[PC]$ 取出一条指令
- 执行它
- 循环往复
## 解决异常退出
### 程序自己是不能 “停下来” 的

- 指令集里没有一条关闭计算机的指令，那么操作系统是如何在关闭所有软件后，切断计算机的电源的？

>问问 chatGPT？
>在现代计算机系统中，操作系统通常并不直接控制切断计算机的电源。相反，当用户选择关机或者操作系统需要关闭时，操作系统会执行以下步骤来安全地关闭计算机：
>1. **关闭所有应用程序**：操作系统会发送信号给所有正在运行的应用程序，要求它们保存数据并关闭。这确保了所有数据都被正确地保存到存储设备上。
>2. **关闭服务和进程**：操作系统会停止所有系统服务和后台进程，以确保系统处于一个稳定的状态。
>3. **卸载文件系统**：操作系统会卸载所有挂载的文件系统，确保数据已经写入磁盘。
>4. **关闭硬件设备**：操作系统会向硬件设备发送关闭信号，例如关闭硬盘、网络接口等。
>5. **发送 ACPI 信号**：最后，操作系统会向主板发送 ACPI（高级配置与电源管理接口）信号。这个信号告诉主板可以切断电源。主板会根据 ACPI 信号来执行相应的操作，包括关闭电源。
   总的来说，操作系统通过一系列步骤来安全地关闭计算机，确保数据被保存并硬件设备被正确关闭。最终，主板根据 ACPI 信号来切断计算机的电源。
### 只能借助操作系统
解决办法：用一条特殊的指令请操作系统帮忙
`movq $SYS_exit,  %rax   # exit( movq $1,         %rdi   #   status=1 syscall                 # );`
-   把 “系统调用” 的参数放到寄存器中
-   执行 syscall，操作系统接管程序
    -   程序把控制权完全交给操作系统
    -   操作系统可以改变程序状态甚至终止程序

## Everything (二进制程序) = 状态机
### 状态
- gdb 内可见的内存和寄存器

### 初始状态
- 由 ABI 规定 (例如有一个合法的 %rsp)

### 状态迁移
- 执行一条指令
    - 我们花了一整个《计算机系统基础》解释这件事
    - gdb 可以单步观察状态机的执行
- **syscall 指令**: 将状态机 “完全交给” 操作系统


我们在编程时，总是想象程序 “独占整个计算机，逐条指令执行”，大部分时候都不用 “考虑” 操作系统的存在。当系统调用发生时，程序执行被完全暂停，但操作系统依然在工作——就像麻醉后醒来，周围的环境发生了变化，但我们完全没有感到时间的流逝。

Minimal. S
```C
#include <sys/syscall.h>
#define syscall3(id, a1, a2, a3) \
    movq $SYS_##id, %rax; \
    movq $a1, %rdi; \
    movq $a2, %rsi; \
    movq $a3, %rdx; \
    syscall
#define syscall2(id, a1, a2)  syscall3(id, a1, a2, 0)
#define syscall1(id, a1)  syscall2(id, a1, 0)
.globl _start
_start:
    syscall3(write, 1, addr1, addr2 - addr1)
    syscall1(exit, 1)
addr1:
    .ascii "\033[01;31mHello, OS World\033[0m\n"
addr2:
```

## 对一些细节的补充解释
为什么用 `gcc` 编译？
-   `gcc` 会进行预编译 (可以使用 `__ASSEMBLER__` 宏区分汇编/C 代码)

更重要的问题：怎样才能变强？
-   问正确的问题、用正确的方式找答案
    -   syscall (2), syscalls (2) -- RTFM & RTFSC `man 2 system`
    -   Q & A 论坛；Q & A 机器人

>操作系统使得应用程序有 “独占整个计算机，逐条指令执行” 的假象。如果把程序类比成我们自己的意识，感知到的时间似乎是连续不间断的。操作系统上的应用程序通过系统调用指令与操作系统交互，此时程序执行被完全暂停，但操作系统依然在工作——就像麻醉后醒来，周围的环境发生了变化，但我们完全没有感到时间的流逝。
>因此，我们对操作系统上程序的一个很重要的理解是程序是计算和系统调用组成的状态机；大部分计算指令都是确定性 (deterministic，在相同环境下执行的结果总是相同) 的，少部分指令 (如 rdrand 返回随机数) 则有非确定的结果。系统调用指令是非确定性的，操作系统可能会将计算机运行环境中的信息，例如来自设备的输入传递到程序中。

# 操作系统上的应用程序
### Core Utilities (coreutils)
- _Standard_ programs for text and file manipulation
- 系统中默认安装的是 [GNU Coreutils](https://www.gnu.org/software/coreutils/)

### 系统/工具程序
- bash, [binutils](https://www.gnu.org/software/binutils/), apt, ip, ssh, vim, tmux, gcc, python, ffmpeg, ...
    - 原理不复杂 (例如 apt 是 dpkg 的套壳)，但琐碎
- All-in-one 工具合集：[busybox](https://www.busybox.net/), [toybox](https://landley.net/toybox/)

### 其他各种应用程序
- Vscode、OBS-Studio、浏览器、音乐播放器：它们在各种工具程序基础上建立起来 (例：ffmpeg)

## 所以这些程序……

### 和 minimal.S 有任何区别吗？

- 简短的答案：**没有**
- 任何程序 = minimal.S = 状态机

### 可执行文件是操作系统中的对象

- 与 minimal 的二进制文件没有本质区别
- 我们甚至可以像文本一样直接编辑可执行文件

## 死去记忆的意义

### 如果那时候有人告诉我……

- 同样的方式也可以去 hack Windows binary
- Binary 太大？用**正确的工具**把 “不在意” 的部分屏蔽掉
    - 调试程序，在运行时观察哪里变了
    - 就入门了逆向工程
- (其实大家离 “做点不一样的东西” 并不远)

### 对《操作系统》课的反思

- **做减法**：把 “不重要” 的部分屏蔽掉
- “简单” 也可以深刻
- 推广到学习：如果觉得 “难”，应该有简化的方法


## 正确的工具

### 打开程序的执行：Trace (追踪)

> In general, trace refers to the process of following _anything_ from the beginning to the end. For example, the `traceroute` command follows each of the network hops as your computer connects to another computer.

### **System call trace (strace)**

- “理解程序是如何与操作系统交互的”
    - (观测状态机执行里的 syscalls)
    - Demo: 试一试最小的 Hello World


## 操作系统中的 “任何程序”

### **任何程序 = minimal.S = 状态机**

- 总是从被操作系统加载开始
    - 通过另一个进程执行 execve 设置为初始状态
- 经历状态机执行 (计算 + syscalls)
    - 进程管理：fork, execve, exit, ...
    - 文件/设备管理：open, close, read, write, ...
    - 存储管理：mmap, brk, ...
- 最终调用 _exit (exit_group) 退出

### 感到吃惊？

- 浏览器、游戏、杀毒软件、病毒呢？都是这些 API 吗？


## 自己动手做实验：观察程序的执行

### 工具程序代表：编译器 (gcc)

- `strace -f gcc a.c` (gcc 会启动其他进程)
    - 可以管道给编辑器 `vim -`
    - 编辑器里还可以 `%!grep`
        - 对于开发者来说，工具的组合是非常重要的

### 图形界面程序代表：编辑器 (xedit)

- `strace xedit`
    - 图形界面程序和 X-Window 服务器按照 X11 协议通信
    - 虚拟机中的 xedit 将 X11 命令通过 ssh (X11 forwarding) 转发到 Host



## 想象 “一切应用程序” 的实现

### 应用程序 = 计算 + 操作系统 API

- 窗口管理器
    - 能直接管理屏幕设备 (read/write/mmap)
        - 能画一个点，理论上就能画任何东西
    - 能够和其他进程通信 (send, recv)
- 任务管理器
    - 能访问操作系统提供的进程对象 ([M1 - pstree](https://jyywiki.cn/OS/2024/labs/M1.md))
- 杀毒软件
    - 文件静态扫描 (read)、主动防御 (ptrace)

### 操作系统的职责：提供令应用程序**舒适**的抽象 (对象 + API)

# [理解高级语言程序](https://jyywiki.cn/OS/2023/slides/2.2.slides)
## 什么是程序？
Hmm....
![](https://cs.nju.edu.cn/hongjin/me.png)

你需要《[程序设计语言的形式语义](https://hongjin-liang.github.io/teaching/semantics/index.html)》
-   by 梁红瑾 🎩
-   λ-calculus, operational semantics, Hoare logic, separation logic
-   入围 “你在南京大学上过最牛的课是什么？” 知乎高票答案
    -   ~~当然，我也厚颜无耻地入围了~~
## ~~不，你不需要~~
你能写一个 C 语言代码的 “解释器” 吗？
-   如果能，你就完全理解了高级语言
-   和 logisim/mini-rv32ima 完全一样
    -   实现 #gdb 里的 “单步执行”
-  amazing
```C
while (1) { stmt = fetch_statement(); execute(stmt); }
```

“解释器” 的例子：用基础结构模拟函数调用和递归
-   试试汉诺塔吧

## 简单 C 程序的状态机模型 (语义)
对 C 程序做出简化
-   简化：改写成每条语句至多一次运算/函数调用的形式
    -   [真的有这种工具](https://cil-project.github.io/cil/) (C Intermediate Language) 和[解释器](https://gitlab.com/zsaleeba/picoc)

状态机定义
-   状态 = 堆 + 栈
-   初始状态 = `main` 的第一条语句
-   状态迁移 = 执行一条语句中的一小步

(这还只是 “粗浅” 的理解) *不严格，不够数学，状态机是数学严格定义的* 
-   Talk is cheap. Show me the code. (Linus Torvalds)
    -   任何真正的理解都应该落到可以执行的代码

## 简单 C 程序的状态机模型 (语义)
>“状态机” 是拥有严格数学定义的对象。这意味着你可以把定义写出来，并且用数学严格的方法理解它 —— 形式化方法

状态
- [StackFrame, StackFrame, ...] + 全局变量

初始状态
- 仅有一个 StackFrame (main, argc, argv, **PC=0**)
- 全局变量全部为初始值

状态迁移
- 执行 frames[-1]. PC 处的简单语句]

*函数调用=栈帧*
然后看看我们的非递归汉诺塔 (更本质)

## 这个问题已经超出了 90% 程序员的能力范围
ChatGPT 竟然改写对了！而且给出了非常优雅 (但也有缺陷) 的实现
```C
void hanoi_non_recursive(int n, char from, char to, char via) {   
struct Element { int n; char from; char to; char via; };   
std::stack<Element> elements;   
elements.push({n, from, to, via});
while (!elements.empty()) {     
	auto e = elements.top();     
	elements.pop();     
	if (e.n == 1) {       
		printf("%c -> %c\n", e.from, e.to);  
	} else {       
		elements.push({e.n - 1, e.via, e.to, e.from});       
		elements.push({1, e.from, e.to, e.via});       
		elements.push({e.n - 1, e.from, e.via, e.to});     
		}   
	} 
}


```
JYY 写的：
```C
typedef struct {
	int pc, n;
	char from, to, via; 
} Frame; 

#define call(...) ({ *(++top) = (Frame) { .pc = 0, __VA_ARGS__ }; }) 
#define ret()     ({ top--; }) 
#define goto(loc) ({ f->pc = (loc) - 1; }) 

void hanoi(int n, char from, char to, char via) {
  Frame stk[64], *top = stk - 1;
  call(n, from, to, via);
  for (Frame *f; (f = top) >= stk; f->pc++) {
    n = f->n; from = f->from; to = f->to; via = f->via;
    switch (f->pc) {
      case 0: if (n == 1) { printf("%c -> %c\n", from, to); goto(4); } break;
      case 1: call(n - 1, from, via, to);   break;
      case 2: call(    1, from, to,  via);  break;
      case 3: call(n - 1, via,  to,  from); break;
      case 4: ret();                        break;
      default: assert(0);
    }
  }
}
```
>此外，我们也可以用类似汉诺塔的方法把 C 语言改写成仅包含顺序执行的简单语句和条件跳转 `if (cond) goto` 的 “简化 C 语言代码”——循环、分支和函数调用都被消灭了。这时候，我们的 C 代码已经可以逐条翻译成汇编指令了。这也是为什么 C 语言被称为 “高级的汇编语言”——我们几乎总是能从 C 语言的语法层面对应到机器指令序列。

` gdb hanoi-r`                 #gdb bt 栈帧记录 
![[CH2 应用视角的操作系统.png]]
#  编译器与编译优化 🌶️
##  理解编译器
我们有两种状态机
-   高级语言代码 .c
    -   状态：栈、全局变量；状态迁移：语句执行
-   汇编指令序列 .s
    -   状态(M,R)；状态迁移：指令执行
-   编译器 = **状态机之间的翻译器**

那到底什么是编译器？
-   不同的优化级别产生不同的指令序列
-   凭什么说一个 . s=compile (. c) 是 “对的” 还是 “错的”？

## SimpleC: 直接翻译
### 运算

- 把操作数 load 到寄存器、执行运算、store 写回结果

### 分支/循环

- 使用条件跳转分别执行代码

### 函数调用

- **专门留一个寄存器给栈** (SP, Stack Pointer)
- 将 Stack frame 的信息保存在内存里
    - 通过 SP 可以访问当前栈帧的变量、返回地址等

(SimpleC 编译器很适合作为《计算机系统基础》的编程练习)

## SimpleC: 直接翻译 (cont'd)

### 所以，C 被称为**高级汇编语言**

- 存在 C 代码到指令集的直接对应关系
    - 状态机和迁移都可以 “直译”
    - 于是计算机系统里多了一个抽象层 (“一生二、二生三、三生万物”)
- 更 “高级” 的语言就很难了
    - C++ `virtual void foo();`
    - Python `[1, 2, 3, *rest]`
    - Javascript `await fetch(...)`

### C 语言能实现对机器更好的控制 (例子：[Inline Assembly](https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html))
## 编译优化 🌶️🌶️

>GPT 的完美回答！： C 语言编译器在进行代码优化时，遵循的基本准则是在*不改变程序的语义* (即**程序的行为和输出结果**) 的前提下，提高程序的*执行效率*和/或*减少程序的资源消耗*

一些 “不改变语义” 的例子 (编译优化中最重要的 “三板斧”)：

- **函数内联**：将函数调用替换为函数体本身的内容
- **常量传播**：在编译时计算常量表达式的值并替换
- **死代码消除**：删除永远不会被执行到的代码
## . s=compile (. c)：编译正确性
. c 执行中*所有外部观测者可见* 的行为，必须在. s 中保持一致
-   External function calls (链接时确定)
    -   如何调用由 Application Binary Interface (ABI) 规定
    -   可能包含**系统调用**，因此不可更改、不可交换
-   编译器提供的 “不可优化” 标注
    -   `volatile` [load | store | inline assembly]
-   Termination
    -   .c 终止当且仅当 .s 终止

在此前提下，任何翻译都是合法的 (例如我们期望更快或更短的代码)
-   编译优化的实际实现：(context-sensitive) rewriting rules
-   代码示例：观测编译器优化行为和 compiler barrier

### 系统调用是使程序计算结果**可见**的唯一方法

- 不改变语义 = 不改变可见结果
- 状态机的视角：满足**C/汇编状态机生成的所有 syscall 序列完全一致**，任何优化都是允许的

### C 代码中的**不可优化部分**

- External function calls (链接时才能确定到底是什么代码)
    - 未知的代码可能包含**系统调用**
    - 因此不可删除、移出循环等，且要保证参数传递完全一致
- 编译器提供的 “不可优化” 标注
    - `volatile` [load | store | inline assembly]


# 有没有觉得这个定义保守了？🌶️🌶️🌶️

### **凭什么系统调用不能被优化？**
```C
if (n <= 26) { for (int i = 0; i < n; i++) { putchar('A' + i); } }
```
- 凭什么不能合并成一个 `printf`？

### 把状态机的一部分直接放到操作系统里运行

- 把代码放进操作系统运行：[XRP](https://www.usenix.org/conference/osdi22/presentation/zhong)
- 单个应用就是操作系统：[Unikernel](https://dl.acm.org/doi/abs/10.1145/3552326.3587458)


>   如果你感到困难，不要慌，对于这些简单的例子，你完全可以让 ChatGPT 来帮你解释，例如问问他编译器可以对 `return_1` 作出什么样的优化，你不仅能得到正确的回答，还学到了一个新名词：
>![[Pasted image 20230301224918.png]]我们甚至有可能 “证明” 编译器所作出的优化全部是正确的，或是用更激进地方式生成更优化的代码，例如把几个行为已知的系统调用 “合并” 起来。如果你对这方面的知识感兴趣，我们有一些论文，供有基础且希望在这方面深入学习的同学参考 (读个大概即可)：
>-   [CompCert C verified compiler](https://compcert.org/motivations.html) and a [paper](https://xavierleroy.org/publi/compcert-backend.pdf) (POPL'06, Most Influential Paper Award 🏅)
>-   [An executable formal semantics of C with applications](https://dl.acm.org/doi/10.1145/2103621.2103719) (POPL'12)
>-   [Copy-and-patch compilation](https://dl.acm.org/doi/10.1145/3485513) (OOPSLA'21, Distinguished Paper 🏅)
>Note: PL 领域 (的很多人) 有一种倾向：用数学化的语言定义和理解一切 (all about semantics)；这 (一定程度上) 是因为 PL 在创立时是逻辑学的分支。(所以你看一眼 paper 就觉得自己瞎了。) 当然，这一切背后的直觉依然是 system/software 的：我们是人，不是无情的数学机器。


