# OS20 多处理器调度
## Overview
-   机制 (mechanism)：上下文切换
    -   在中断/系统调用时执行操作系统代码
    -   操作系统实现所有状态机 (进程) 一视同仁的 “封存”
    -   从而可以恢复任意一个状态机 (进程) 执行
### 本次课回答的问题 ：
-   **Q** : *策略 (policy)*：那我们到底选哪个进程执行呢？

### 本次课主要内容
-   常见调度算法：Round-Robin, 优先级, MLFQ, CFS
-   告诉大家为什么我们这门课不讲 “调度算法”
---
## 处理器调度 (1)
### 简化的处理器调度问题
中断机制
-   处理器以固定的频率被中断
    -   Linux Kernel 可以配置：100/250/300/1000Hz
-   中断/系统调用返回时可以自由选择进程/线程执行

处理器调度问题的简化假设
-   系统中有一个处理器 (1970s)
-   系统中有多个进程/线程共享 CPU
    -   包括系统调用 (进程/线程的一部分代码在 syscall 中执行)
    -   偶尔会等待 I/O 返回，不使用 CPU (通常时间较长)

### 策略: Round-Robin
假设当前 $T_i$ 运行
-   中断后试图切换到下一个线程 $T_{(i+1)\,\textrm{mod}\,n}​$
-   如果下一个线程正在等待 I/O 返回，继续尝试下一个
    -   如果系统所有的线程都不需要 CPU，就调度 idle 线程执行

我们的 [thread-os.c](http://jyywiki.cn/pages/OS/2022/demos/thread-os.c) 实际上实现了 Round-Robin 的调度器
-   中断之间的线程执行称为 “时间片” (time-slicing)

![](http://jyywiki.cn/pages/OS/img/sched-rr.png)
### 策略：引入优先级
![](http://jyywiki.cn/pages/OS/img/haorenka.jpg)
UNIX niceness
- **nice** ：（好人卡，好人被人欺负捏）:
	* ***-20 ~ 19的整数**
		-20 极坏，优先级最高
		 19  极好，优先级最低
- `man nice`  看手册
-   基于优先级的调度策略
    -   RTOS: 坏人躺下好人才能上，**完全基于优先级**，有严格实时性要求
        -   ~~好人流下了悔恨的泪水~~
    -   Linux: nice 相差 10, CPU 资源获得率相差 10 倍，**普通桌面系统不辣么严格**
-   不妨试一试: nice/renice   什么是taskset？ `man taskset`
    `taskset -c 0 nice -n 19 yes > /dev/null &`` 
    `taskset -c 0 nice -n  9 yes > /dev/null &`
    然后top，看两个yes的%CPU

---
## 真实的处理器调度 (1)
### Round-Robin 的问题
系统里有两个进程
-   交互式的 Vim，单线程
-   纯粹计算的 [mandelbrot.c](http://jyywiki.cn/pages/OS/2022/demos/mandelbrot.c), 32 个线程
-   Vim 花 0.1ms 处理完输入就又等输入了
    -   主动让出 CPU
-   Mandelbrot 使 Vim 在有输入可以处理的时候被延迟
    -   必须等当前的 Mandelbrot 转完一圈
    -   数百 ms 的延迟就会使人感到明显卡顿
-   你们会在 L2 里遇到这样的问题
    -   表现形式：tty 卡顿

### 策略：动态优先级 (MLFQ)
不会设置优先级？让系统自动设定！
![](http://jyywiki.cn/pages/OS/img/MLFQ.png)
-   设置若干个 Round-Robin 队列
    -   每个队列对应一个优先级
-   动态优先级调整策略
    -   优先调度高优先级队列
    -   用完时间片 → 坏人
        -   Mandelbrot: 请你变得更好
    -   让出 CPU I/O → 好人
        -   Vim: 你可以变得更坏
-   阅读教科书

### 策略：Complete Fair Scheduling (CFS)
试图去模拟一个 “Ideal Multi-Tasking CPU”:
-   “Ideal multi-tasking CPU” is a (non-existent :-)) CPU that has 100% physical power and which can run each task at precise equal speed, in parallel, each at 1/n. For example: if there are 2 tasks running, then it runs each at 50% physical power — i.e., actually in parallel.

“让系统里的所有进程尽可能公平地共享处理器”
-   为每个进程记录精确的运行时间
-   中断/异常发生后，切换到运行时间最少的进程执行
    -   下次中断/异常后，当前进程的可能就不是最小的了

### CFS: 实现优先级
操作系统具有对物理时钟的 “绝对控制”
-   每人执行 1ms，但好人的钟快一些，坏人的钟慢一些
    -   vruntime (virtual runtime)
    -   vrt[i] / vrt[j] 的增加比例 = wt[j] / wt[i]


     ```C
const int sched_prio_to_weight[40] = {   
/* -20 */ 88761, 71755, 56483, 46273, 36291,   
/* -15 */ 29154, 23254, 18705, 14949, 11916,  
/* -10 */  9548,  7620,  6100,  4904,  3906,  
/*  -5 */  3121,  2501,  1991,  1586,  1277,
/*   0 */  1024,   820,   655,   526,   423,
/*   5 */   335,   272,   215,   172,   137, 
/*  10 */   110,    87,    70,    56,    45,
/*  15 */    36,    29,    23,    18,    15, };
```
### CFS 的复杂性 (3): 整数溢出
vruntime 有优先级的 “倍数”
-   如果溢出了 64-bit 整数怎么办……？
    -   `a < b` 不再代表 “小于”！

假设：系统中最近、最远的时刻差不超过数轴的一半
-   我们可以比较它们的相对大小

`bool less(u64 a, u64 b) {   return (i64)(a - b) < 0; }`
### 实现 CFS 的数据结构
用什么数据结构维护所有进程的 vruntime?
-   任何有序集合 (例如 binary search tree) 维护线程 tt 的 vrt(t)vrt(t)
    -   更新 vrt(t) \leftarrow vrt(t) + \Delta_t / wvrt(t)←vrt(t)+Δt​/w
    -   取最小的 vrtvrt
    -   进程创建/退出/睡眠/唤醒时插入/删除 tt

道理还挺简单的
-   代码实现有困难
-   还不能有并发 bug……

### 小结：是否解决了问题？
考虑三种情况：Producer, Consumer, `while (1)`
-   Round-Robin (L2)
    -   Producer/Consumer 获得非常少比例的 CPU
-   MLFQ
    -   Producer/Consumer 获得最高优先级 Round-Robin
    -   `while (1)` 完全饥饿 → 需要定期把所有人优先级 “拉平”
-   CFS
    -   线程有精确的 accounting 信息
    -   这些信息可以指导 Round-Robin
        -   适当使用 uptime (不必太精确) 可以大幅缓解 L2

---
##  真实的处理器调度 (2)
### 不要高兴得太早
```C
void xiao_zhang() { // 高优先级   
	sleep(1); // 休息一下先   
	mutex_lock(&wc);   
	...
}  
void xi_zhu_ren() { // 中优先级   
	while (1) ; 
}
void jyy() { // 最低优先级
	mutex_lock(&wc);
	... 
}
```
jyy 在持有互斥锁的时候被赶下了处理器……
### 这个故事在火星上发生过一次
![](http://jyywiki.cn/pages/OS/img/mpf-sojourner.jpg)
Sojourner “探路者” (PathFinder)，1997 年 7 月 4 日登陆火星
### [The First Bug on Mars](https://news.ycombinator.com/item?id=13210478)
Sojourner “探路者” (PathFinder)
-   Lander (登陆舱)
    -   IBM Rad6000 SC (20 MIPS), 128 MiB RAM, 6 MiB EEPROM
    -   VxWorks “实时” 任务操作系统
        -   ASI/MET task: 大气成分监测 (低)
        -   `bc_dist` task: 分发任务 (中)
        -   `bc_sched` task: 总线调度 (高)
-   Rover (火星车)
    -   Intel 80C85 (0.1 MIPS), 512K RAM, 176K Flash SSD
-   着陆后开始出现系统重启

### The First Bug on Mars (cont'd)
![](http://jyywiki.cn/pages/OS/img/marsbot.png)
-   (低优先级) `select -> pipeIoctl -> selNodeAdd -> mutex_lock`
-   (高优先级) `pipeWrite -> mutex_lock`

### 解决优先级反转问题
Linux: CFS 凑合用吧
-   实时系统：火星车在 CPU Reset 啊喂？？
    -   优先级继承 (Priority Inheritance)/优先级提升 (Priority Ceiling)
        -   持有 mutex 的线程/进程会继承 block 在该 mutex 上进程的最高优先级
        -   但也不是万能的 (例如条件变量唤醒)
    -   在系统中动态维护资源依赖关系
        -   优先级继承是它的特例
        -   似乎更困难了……
    -   避免高/低优先级的任务争抢资源
        -   对潜在的优先级反转进行预警 (lockdep)
        -   TX-based: 冲突的 TX 发生时，总是低优先级的 abort

## 真实的处理器调度 (3)
### 多处理器调度
还没完：我们的计算机系统可是多核心、多线程的！
-   我们的老服务器：2 Socket x 24 Cores x 2 Threads = 96T

![](http://jyywiki.cn/pages/OS/img/2S-motherboard.jpg)
### 多处理器调度：被低估的复杂性
> “And you have to realize that there are not very many things that have aged as well as the scheduler. Which is just another proof that scheduling is easy.” ——Linus Torvalds, 2001

Linus 以为调度是个挺简单的问题？
-   As a central part of resource management, the OS thread scheduler must maintain the following, simple, invariant: _make sure that ready threads are scheduled on available cores_... this invariant is often broken in Linux. Cores may stay idle for seconds while ready threads are waiting in runqueues.
    -   [The Linux scheduler: A decade of wasted cores](https://dl.acm.org/doi/10.1145/2901318.2901326). (EuroSys'16)
        -   作者在狂黑 Linus 😂

### 多处理器调度的困难所在
既不能简单地 “分配线程到处理器”
-   线程退出，瞬间处理器开始围观

也不能简单地 “谁空丢给谁”
-   在处理器之间迁移会导致 cache/TLB 全都白给

多处理器调度的两难境地
-   迁移？可能过一会儿还得移回来
-   不迁移？造成处理器的浪费

### 实际情况 (1): 多用户、多任务
还是刚才服务器的例子
-   马上要到 paper deadline 了，A 和 B 要在服务器上跑实验
    -   A 要跑一个任务，因为要调用一个库，只能单线程跑
    -   B 跑并行的任务，创建 1000 个线程跑
        -   B 获得几乎 100% 的 CPU

更糟糕的是，优先级解决不了这个问题……
-   B 不能随便提高自己进程的优先级
    -   “An unprivileged user can only increase the nice value and such changes are irreversible...”

### Linux Namespaces Control Groups (cgroups)
namespaces (7), cgroups (7)
-   轻量级虚拟化，创造 “操作系统中的操作系统”
    -   Mount, pid, network, IPC, user, cgroup namespace, time
    -   cgroup 允许以进程组为单位管理资源
        -   Docker 就变得很容易实现了

![](http://jyywiki.cn/pages/OS/img/cgroups.jpg)
### 实际情况 (2): Big.LITTLE/能效比
![](http://jyywiki.cn/pages/OS/img/Snapdragon-888.png)
Snapdragon 888
-   1X Prime Cortex-X1 (2.84GHz)
-   3X Performance Cortex-A78 (2.4GHz)
-   4X Efficiency Cortex-A55 (1.8GHz)
“Dark silicon” 时代的困境
-   功率无法支撑所有电路同时工作
-   总得有一部分是停下的
-   Linux Kernel [EAS](https://www.kernel.org/doc/html/latest/scheduler/sched-energy.html) (Energy Aware Scheduler)

### 实际情况 (2): Big.LITTLE/能耗 (cont'd)
软件可以配置 CPU 的工作模式
-   开/关/工作频率 (频率越低，能效越好)
-   如何在给定功率下平衡延迟 v.s. 吞吐量？

### 实际情况 (3): Non-Uniform Memory Access
共享内存只是假象
-   L1 Cache 花了巨大的代价才让你感到内存是共享的
-   Producer/Consumer 位于同一个/不同 module 性能差距可能很大

### 实际情况 (4): CPU Hot-plug （热插拔）
😂😂😂 我讲不下去了
-   实在是太复杂了
-   我不是代码的维护者，并不清楚这些细节
    -   把上面都加起来
        -   这得考虑多少情况，写多少代码……

复杂的系统无人可以掌控
-   [The battle of the schedulers: FreeBSD ULE vs. Linux CFS](https://www.usenix.org/system/files/conference/atc18/atc18-bouron.pdf). (ATC'18)
    -   结论：在现实面前，没有绝对的赢家和输家
    -   如果你追求极致的性能，就不能全指望一个调度算法

### 谁来完成建模-预测-决策？
操作系统不 (完全) 背这个锅
-   让程序提供 scheduling hints
-   [ghOSt: Fast & flexible user-space delegation of Linux scheduling](https://dl.acm.org/doi/10.1145/3477132.3483542) (SOSP'21)

![](http://jyywiki.cn/pages/OS/img/ghost-sched.png)

---
## 总结
本次课回答的问题
-   **Q**: 中断后到底应该把哪个进程/线程调度到处理器上？

Take-away messages
-   机制 (做出来) 和策略 (做得好)
    -   构建复杂系统的常用方法
-   真实世界的处理器调度
    -   异构处理器 + Non-Uniform Memory Access
    -   优先级翻转
    -   教科书上的内容随时可能会被改写

----
# OS21 操作系统设计
## Overview
复习
-   操作系统设计：一组对象 + 访问对象的 API
-   操作系统实现：一个 C 程序实现上面的设计

本次课回答的问题
-   **Q**: 操作系统到底应该提供什么对象和 API？

本次课主要内容
-   Micro/Exo/Unikernel
---
## 操作系统里到底该有什么？
### 2022.4.25 小学生又出新产品了
这次支持了分页和图形界面 (似乎是搬运了一些素材？)
-   L2: tty 和 fb 驱动 (tty 是逐像素绘制的)
-   L3: 9 个系统调用 (kputc, fork, wait, exit, kill, mmap, ...)

![](http://jyywiki.cn/pages/OS/img/min0911-os.jpg)
### 莫要慌：你们是大学生啊 😂
![](http://jyywiki.cn/pages/OS/img/eager-for-power.jpg)
### 上课谈的不能称为真正的 “操作系统”
发扬大学生 RTFM & RTFSC 的光荣传统
-   能够意识到这一点的中/小学生就能成为顶级的程序员

[The Open Group Base Specifications Issue 7 (2018 Ed.)](https://pubs.opengroup.org/onlinepubs/9699919799/mindex.html)
-   XBD: Base Definitions
-   XSH: System Interfaces
-   XCU: Shell & Utilities
-   XRAT: Rationale
    -   这是非常关键的：不仅告诉 “是什么”，还有 “为什么”

[Windows API Index](https://docs.microsoft.com/en-us/windows/win32/apiindex/windows-api-list)
-   和 POSIX 相当不同的一组设计
-   “工业” v.s. “黑客” (PowerShell v.s. bash)

### 冰山的一角
API 意味着可以互相模拟
-   Windows Subsystem for Linux (WSL)，大家都在用
    -   WSL1: 直接用 Windows 加载 ELF 文件
    -   WSL2: 虚拟机
-   Linux Subsystem for Windows (Wine)

![](http://jyywiki.cn/pages/OS/img/wined3.jpg)
### 冰山的一角 (cont'd)
操作系统默默帮你承载了更多
-   [Operating system transactions](https://dl.acm.org/doi/abs/10.1145/1629575.1629591) (SOSP'09)
    -   在 Linux 2.6.22 上实现
    -   对 Kernel 破坏性太大，不太可能维护得下去
-   [Windows KTM](https://docs.microsoft.com/en-us/windows-hardware/drivers/kernel/when-to-use-kernel-mode-ktm), since Windows Vista (2007)
    -   对，你没看错，是 Windows Vista
    -   世界最强、骂声最大，悄然落幕

### 小结：操作系统设计
操作系统 = 对象 + API
-   承载了软件的 “一切需要”
-   [中国海军航母宣传片](https://www.bilibili.com/video/BV1aY411P7e1)

![](http://jyywiki.cn/pages/ICS/2021/img/CV41.jpg)
### 如何迈出走向操作系统的第一步？
理解老系统是如何实现、遇到怎样的问题
-   xv6; 偶尔讲一些新特性
-   然后：RTFM, RTFSC

![](http://jyywiki.cn/pages/ICS/2021/img/CV-1.jpg)

---
## Microkernel
### Less is More
> 公理：没有完美的程序员。
> 推论：越小的系统，错误就越少。

C 作为一个有 Undefined Behavior 的语言，是复杂系统的灾难
-   Signed integer overflow (Linux Kernel 使用了 -fwrapv)
-   Data race
-   Memory error
    -   libpng 高危漏洞 (一张图偷走你的密码)
        -   整数溢出后空格 keyword 读取进程数据

Microkernel (微内核) 应运而生
-   把尽可能多的功能都用普通进程实现 (失效隔离在 “进程” 级)

### 试着用普通进程做更多的事
[sh-xv6.c](http://jyywiki.cn/pages/OS/2022/demos/sh-xv6.c) 到底执行了哪些 “就算丢给另一个进程，还得请求操作系统” 的操作？
-   进程 (状态机) 管理似乎绕不开
    -   fork/spawn; exit
-   加载器 [loader-static.c](http://jyywiki.cn/pages/OS/2022/demos/loader-static.c) (execve) 似乎不必要
    -   mmap 似乎绕不开
-   终端 (tty) 可以放在进程里
    -   让 “驱动进程” 能访问 memory-mapped register 就行
    -   或者提供一个 mmio 系统调用
-   文件系统 (open, close, read, write, ...)
    -   进程只要有访问磁盘的权限，在磁盘上做个数据结构不成问题

### Microkernel (微内核)
![](http://jyywiki.cn/pages/OS/img/microkernel.jpg)
微内核 (microkernel)
-   只把 “不能放在用户态” 的东西留在内核里
    -   状态机 (拥有寄存器和地址空间的执行流)
    -   状态机之间的协作机制 (进程间通信)
    -   权限管理 (例如设备访问)
-   赋予进程最少的权限，就能降低错误带来的影响

### Minix: 另一个改变世界的操作系统
![](http://jyywiki.cn/pages/OS/img/minix2-book.jpg)
Minix: 完全用于教学的真实操作系统
-   by Andrew S. Tanenbaum

年轻人的第一个 “全功能” 操作系统
-   Minix1 (1987): UNIXv7 兼容
    -   Linus 实现 Linux 的起点
-   [Minix2](http://download.minix3.org/previous-versions/Intel-2.0.4/) (1997): POSIX 兼容
    -   更加完备的系统，书后附全部内核代码

![](http://jyywiki.cn/pages/OS/img/minix3-desktop.png)
-   [Minix3](http://minix3.org/) (2006): POSIX/NetBSD 兼容
    -   一度是世界上应用最广的操作系统
        -   Intel ME 人手一个

### Minix3 Architecture
![](http://jyywiki.cn/pages/OS/img/minixarch.png)
-   Minix2 更极端一些，只有 send 和 receive 两个系统调用
    -   主要用来实现 RPC (remote procedure call)
    -   操作系统还是操作系统，但跨模块调用会跨越进程边界

### 再向前走一小步
听说 “微内核” 有更好的可靠性？
-   那我们能不能证明它真的 “十分可靠”？
    -   对于任何输入、任何执行路径
    -   没有 memory error
    -   不会 crash……

seL4
-   世界上第一个 verified micorkernel
    -   [Whitepaper](https://sel4.systems/About/seL4-whitepaper.pdf) (初学者友好，十分推荐)
    -   [Comprehensive formal verification of an OS microkernel](https://dl.acm.org/doi/10.1145/2560537) (TOCS'14)
-   有一个非常优雅的 capability 机制

### seL4 证明思路
首先，用适合描述行为的语言建一个模型 (seL4 有两层模型)
`def rr_sched(cpu):     cpu.threads = cpu.threads[1:] + cpu.threads[:1]     assert anything_you_need     return cpu.threads[0]`
再写一份 C 代码
-   [thread-os.c](http://jyywiki.cn/pages/OS/2022/demos/thread-os.c)
    -   我们就有了两个状态机 (Python 和 C 代码的形式语义)

就可以去证明操作系统的 functional correctness 啦！
-   证明两个数学对象 (状态机) 可观测行为的等价性
-   剩下就是去解决遇到的各种技术问题 (更重要的是敢不敢去做)
    -   Non-trivial; 但也不是 “神来之笔” (incremental work)

---
## 我们置身的时代
### Linus 和 Andy 的激烈论战 (1992)
“[Linux is obsolete](https://www.oreilly.com/openbook/opensources/book/appa.html)”
-   主要批评内核架构设计不合理、移植性问题
-   30 年过去了，许多问题得到了解决；许多还没有
![](http://jyywiki.cn/pages/OS/img/ken-quote.png)
### Exokernel
> “The essential observation about abstractions in traditional operating systems is that they are overly general.”

操作系统就不应该有任何策略
-   只应该管硬件资源的最小虚拟化
-   Expose allocation, expose names, expose revocation
    -   内核里甚至连 “进程” 的概念都没有，只有时间片
        -   调度策略完全在 libOS 中实现
-   [Exokernel: An operating system architecture for application-level resource management](https://dl.acm.org/doi/abs/10.1145/224057.224076) (SOSP'95)

### Unikernel: libOS 的复活
今天我们有虚拟机 (和硬件虚拟化) 了
-   为什么不直接让 Lab2 跑应用程序呢？
    -   应用代码直接和 klib, AbstractMachine, Lab 代码静态链接
    -   任何操作 (包括 I/O) 都可以直接做

Unikernel: 内核可以非常小 (应用不需要的特性都直接删除)
-   [includeOS](https://www.includeos.org/) (C++); [runtime.js](http://runtimejs.org/) (JavaScript); [Mirage](https://mirage.io/) (OCaml)
-   [Unikernels: The rise of the virtual library operating system](https://dl.acm.org/doi/10.1145/2541883.2541895) (CACM'14)
-   [Unikraft: Fast, specialized unikernels the easy way](https://dl.acm.org/doi/10.1145/3447786.3456248) (EuroSys'21, Best Paper Award 🏅)

## 总结
本次课回答的问题
-   **Q**: 操作系统到底应该提供什么对象和 API？

Take-away messages
-   “操作系统” 的含义随应用而变
    -   可以大而全 (Linux/Windows API)
    -   可以只有最少的硬件抽象 (Microkernel)
    -   可以没有用户态 (Unikernel)
-   互联网时代
    -   从井里走出去：RTFM, RTFSC
    -   然后去改变这个世界

---
# OS22 极限速通操作系统实验
	 http://jyywiki.cn/OS/2022/slides/22.slides
----
# OS23  存储设备原理
---
# OS24 输入输出设备
---
# OS25 设备驱动程序
## 设备驱动程序原理
### I/O设备做抽象
OS层对I/O设备做抽象，这样提供给应用程序api，以尽可能统一方式管理设备，不直接把寄存器形式的I/O接口层面暴漏给应用程序。
I/O 设备的主要功能：**输入和输出**
-   “能够读 (`read`) 写 (`write`) 的字节序列 (**流**(`byte stream`)或数组(`byte array`))”
-   常见的设备都满足这个模型
    -   终端/串口 - **字节流**
    -   鼠标/键盘 - **字节流**
    -   打印机 - 字节流 (例如 [PostScript 文件](http://jyywiki.cn/pages/OS/2022/demos/page.ps))
    -   硬盘 - **字节数组 (按块访问)**
    -   **GPU - 字节流 (控制) + 字节数组 (显存)**

操作系统：设备 = 支持各类操作的对象 (文件)
-   `read` - 从设备某个指定的位置读出数据
-   `write` - 向设备某个指定位置写入数据
-   `ioctl `- 读取/设置设备的状态 io control `man 2 iotcl看手册`
### 设备驱动程序driver
把系统调用 (read/write/ioctl/...) “翻译” 成与设备寄存器的交互
-   就是一段普通的内核代码
-   但可能会睡眠 (例如 P 信号量，等待中断中的 V 操作唤醒)
例子：`/dev/` 中的对象
-   `/dev/pts/[x]` - pseudo terminal
-   `/dev/zero` - “零” 设备
-   `/dev/null` - “null” 设备
-   `/dev/random`, `/dev/urandom` - 随机数生成器
    -   试一试：`head -c 512 [device] | xxd`
    -   以及观察它们的 strace
        -   能看到访问设备的系统调用
### 例子: Lab 2 设备驱动
设备模型
-   简化的假设
    -   设备从系统启动时就存在且不会消失
-   支持读/写两种操作
    -   在无数据或数据未就绪时会等待 (P 操作)
```
```
```C
typedef struct devops {   int (*init)(device_t *dev);   int (*read) (device_t *dev, int offset, void *buf, int count);   int (*write)(device_t *dev, int offset, void *buf, int count); } devops_t;
```
I/O 设备看起来是个 “黑盒子”
-   写错任何代码就 simply “not work”
-   设备驱动：Linux 内核中最多也是质量最低的代码
### 字节流/字节序列抽象的缺点
![](http://jyywiki.cn/pages/OS/img/pmd.gif)
设备不仅仅是数据，还有控制
-   尤其是设备的附加功能和配置
-   所有额外功能全部依赖 ioctl
    -   “Arguments, returns, and semantics of ioctl() vary according to the device driver in question”
    -   无比复杂的 “hidden specifications”
例子
-   打印机的打印质量/进纸/双面控制、卡纸、清洁、自动装订……
    -   一台几十万的打印机可不是那么简单 😂
-   键盘的跑马灯、重复速度、宏编程……
-   磁盘的健康状况、缓存控制……
### 例子：终端
“字节流” 以内的功能
-   ANSI Escape Code
-   [logisim.c](http://jyywiki.cn/pages/OS/2022/demos/logisim.c) 和 [seven-seg.py](http://jyywiki.cn/pages/OS/2022/demos/seven-seg.py)

“字节流” 以外的功能
-   stty -a
    -   终端大小怎么知道？
    -   终端大小变化又怎么知道？
-   isatty (3), termios (3)
    -   大部分都是 ioctl 实现的
    -   这才是水面下的冰山的一角
---
## Linux 设备驱动
### Nuclear Launcher
我们希望实现一个最简单的 “软件定义核弹”
`#include <fcntl.h>  #define SECRET "\x01\x14\x05\x14"  int main() {   int fd = open("/dev/nuke", O_WRONLY);   if (fd > 0) {     write(fd, SECRET, sizeof(SECRET) - 1);     close(fd);   } else {     perror("launcher");   } }`
### 实现 Nuclear Launcher
内核模块：一段可以被内核动态加载执行的代码
-   [M4 - crepl](http://jyywiki.cn/OS/2022/labs/M4)
    -   也就是把文件内容搬运到内存
    -   然后 export 一些符号 (地址)

* [launcher.c](http://jyywiki.cn/pages/OS/2022/demos/launcher.c) : 驱动程序模块
-   Everything is a file
    -   设备驱动就是实现了 `struct file_operations` 的对象
        -   把文件操作翻译成设备控制协议
-   在内核中初始化、注册设备
    -   系统调用直接以函数调用的方式执行驱动代码
### 更多的 File Operations
```C
struct file_operations {   
	struct module *owner;  
	loff_t (*llseek) (struct file *, loff_t, int);   
	ssize_t (*read) (struct file *, char __user *, size_t, loff_t *);   
	ssize_t (*write) (struct file *, const char __user *, size_t, loff_t *);   
	int (*mmap) (struct file *, struct vm_area_struct *);   
	unsigned long mmap_supported_flags;   
	int (*open) (struct inode *, struct file *);   
	int (*release) (struct inode *, struct file *);   
	int (*flush) (struct file *, fl_owner_t id);   
	int (*fsync) (struct file *, loff_t, loff_t, int datasync);   
	int (*lock) (struct file *, int, struct file_lock *);   
	ssize_t (*sendpage) (struct file *, struct page *, int, size_t, loff_t *, int);   
	long (*unlocked_ioctl) (struct file *, unsigned int, unsigned long);   
	long (*compat_ioctl) (struct file *, unsigned int, unsigned long);   
	int (*flock) (struct file *, int, struct file_lock *);   
	...
```
### 为什么有两个 ioctl?
```C
long (*unlocked_ioctl) (struct file *, unsigned int, unsigned long); long (*compat_ioctl) (struct file *, unsigned int, unsigned long);
```
-   `unlocked_ioctl`: BKL (Big Kernel Lock) 时代的遗产
    -   单处理器时代只有 `ioctl`
    -   之后引入了 BKL, `ioctl` 执行时默认持有 BKL
    -   (2.6.11) 高性能的驱动可以通过 `unlocked_ioctl` 避免锁
    -   (2.6.36) `ioctl` 从 `struct file_operations` 中移除
-   `compact_ioctl`: 机器字长的兼容性
    -   32-bit 程序在 64-bit 系统上可以 ioctl
    -   此时应用程序和操作系统对 ioctl 数据结构的解读可能不同 (tty)
    -   (调用此兼容模式)
---
## 为 GPU 编程
### Mandelbrot, Again
[mandelbrot.cu](http://jyywiki.cn/pages/OS/2022/demos/mandelbrot.cu) 和 GPU 惊人的计算力
-   16 亿像素、每像素迭代 100 次
    -   分到 512x512 = 262,144 线程计算
-   每个线程计算 mandelbrot 的一小部分
    -   [mandelbrot-12800.webp](http://jyywiki.cn/pages/OS/img/mandelbrot-12800.webp)
    -   (感谢 doowzs 借用的机器)

nvprof 结果
```
==2994086== Profiling result: 
Time(%)      Time   Name  
95.75%  1.76911s   mandelbrot_kernel   
4.25%  78.506ms   [CUDA memcpy DtoH] (12800 x 12800 data)   
0.00%  1.5360us   [CUDA memcpy HtoD]
```
### Mandelbrot, Again (cont'd)
RTFM: [Parallel Thread Execution ISA Application Guide](http://jyywiki.cn/pages/OS/manuals/ptx-isa-7.7.pdf)
-   就是个指令集
-   再编译成 SASS (机器码)
    -   cuobjdump --dump-ptx / --dump-sass

该有的工具都有
-   gcc → nvcc
-   binutils → cuobjdump
-   gdb → cuda-gdb
    -   可以直接调试 GPU 上的代码！
-   perf → nvprof
-   ...
### GPU 驱动程序
GPU 驱动非常复杂
-   全套的工具链
    -   Just-in-time 程序编译
    -   Profiler
    -   ...
-   API 的实现
    -   cudaMemcpy, cudaMalloc, ...
    -   Kernel 的执行
    -   大部分通过 ioctl 实现
-   设备的适配
NVIDIA 在 2022 年开源了驱动！([名场面](https://www.bilibili.com/video/BV1YF41177V6))
---
## 存储设备的抽象
### 存储设备的抽象
磁盘 (存储设备) 的访问特性
1.  以数据块 (block) 为单位访问
    -   传输有 “最小单元”，不支持任意随机访问
    -   最佳的传输模式与设备相关 (HDD v.s. SSD)
2.  大吞吐量
    -   使用 DMA 传送数据
3.  应用程序不直接访问
    -   访问者通常是文件系统 (维护磁盘上的数据结构)
    -   大量并发的访问 (操作系统中的进程都要访问文件系统)

对比一下终端和 GPU，的确是很不一样的设备
-   终端：小数据量、直接流式传输
-   GPU：大数据量、DMA 传输
### Linux Block I/O Layer
文件系统和磁盘设备之间的接口
-   包含 “I/O 调度器”
    -   曾经的 “电梯” 调度器
![](http://jyywiki.cn/pages/OS/img/linux-bio.png)
### 块设备：持久数据的可靠性
Many storage devices, ... come with _volatile write back caches_
-   the devices signal I/O completion to the operating system before data actually has hit the non-volatile storage
-   this behavior obviously _speeds up_ various workloads, but ... _data integrity_...

我们当然可以提供一个 ioctl
-   但 block layer 提供了更方便的机制
    -   在 block I/O 提交时
        -   `| REQ_PREFLUSH` 之前的数据落盘后才开始
        -   `| REQ_FUA` (force unit access)，数据落盘后才返回
    -   设备驱动程序会把这些 flags 翻译成磁盘 (SSD) 的控制指令
---
## 总结
本次课回答的问题
-   **Q**: 操作系统如何使应用程序能访问 I/O 设备？

Takeaway messages
-   设备驱动
    -   把 read/write/ioctl 翻译成设备听得懂的协议
    -   字符设备 (串口、GPU) + DMA
    -   块设备 (磁盘)