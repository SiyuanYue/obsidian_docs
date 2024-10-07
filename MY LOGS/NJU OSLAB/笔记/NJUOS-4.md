# OS31 Android
## Overview
复习
-   应用视角的操作系统
    -   对象 + API
-   硬件视角的操作系统
    -   一个控制了整个计算机硬件的程序

本次课回答的问题
-   **Q**: 一个真正 “实用” 的操作系统还需要什么？

本次课主要内容
-   Android 应用和系统

## 走向移动互联网时代
### 我们的世界悄然发生的变化
> 我们已然无法想象没有手机的生活。
[![](http://jyywiki.cn/pages/OS/img/mobile-phone-evolve.jpg)](https://www.bilibili.com/video/BV12W411e7o8)

(把计算机变小从来不是一个新想法，但是……)
###  一次、再一次，改变世界
![](http://jyywiki.cn/pages/OS/img/iphone-release.jpg)

### Android

![](http://jyywiki.cn/pages/OS/img/htc-g1.jpg)

[Android 官方主页](https://developer.android.google.cn/)
-   Linux + Framework + JVM
    -   在 Linux/Java 上做了个二次开发？
    -   并不完全是：Android 定义了应用模型
-   支持 Java 是一个非常高瞻远瞩的决定
    -   Qualcomm MSM7201
        -   ARMv6 指令集
        -   528MHz x 1CPU, 顺序八级流水线
        -   TSMC 90nm
    -   “跑个地图都会卡”
        -   但摩尔定律生效了！

## Android Apps
一个运行在 Java 虚拟机 ([Android Runtime](http://aospxref.com/android-12.0.0_r3/xref/art/)) 上的应用程序
-   Platform (Framework)
-   NDK (Native Development Kit)
-   JNI： Java Native Interface (C/C++ 代码) 
- [(17条消息) Android：JNI 与 NDK到底是什么？（含实例教学）_Carson带你学Android的博客-CSDN博客_jni与ndk教学](https://blog.csdn.net/carson_ho/article/details/73250163)

官方文档 (RTFM)
-   [Kotlin](https://developer.android.google.cn/kotlin)     ---但只是改变前端，依旧使用JVM
-   [Platform](https://developer.android.google.cn/reference/packages)
    -   [android.view.View](https://developer.android.google.cn/reference/android/view/View): “the basic building block for user interface components”
    -   [android.webkit.WebView](https://developer.android.google.cn/reference/android/webkit/WebView) - 嵌入应用的网页
    -   [android.hardware.camera2](https://developer.android.google.cn/reference/android/hardware/camera2/package-summary) - 相机
    -   [android.database.database](https://developer.android.google.cn/reference/android/database/sqlite/package-summary) - 数据库

## Android 应用
### “四大组件”

![](http://jyywiki.cn/pages/OS/img/android-activity.png)

Activity
-   应用程序的 UI 界面 (Event Driven)
-   存在一个 Activity Stack (应用拉起)

Service
-   无界面的后台服务

Broadcast
-   接受系统消息，做出反应
    -   例如 “插上电源”、“Wifi 断开”

ContentProvider
-   可以在应用间共享的数据存储 (insert, update, query, ...)

### 例子：计算器

![](http://jyywiki.cn/pages/OS/img/gcalc.jpg)

[Calculator](http://jyywiki.cn/pages/OS/2022/demos/platform_packages_apps_calculator-master.zip)
-   AndroidManifest.xml - 应用的 “元数据”
    -   例如需要的权限、监听的 Intents 等
-   res - 资源文件
    -   各国语言的翻译
    -   图片文件 (例如图标)
-   编写应用逻辑只需要重载 Activity 的 onCreate, ... 即可

## Android 系统
![[Pasted image 20230227165516.png]]
### Platform API 之下：一个 “微内核”

![](http://jyywiki.cn/pages/OS/img/android-stack.png)

通过 “Binder IPC”
-   Remote Procedure Call (RPC)
    -   `remote.transact()`
-   在性能优化和易用之间的权衡
    -   注册机制
        -   相比之下，管道/套接字就太 “底层” 了，需要手工管理的东西太多
    -   基于共享内存实现
        -   Linux Kernel binder driver
    -   服务端线程池

### 然后……海量的代码
例子：如何杀死一个 Android 进程？
-   RTFSC: [ActivityManagerService.java](http://aospxref.com/android-12.0.0_r3/xref/frameworks/base/services/core/java/com/android/server/am/ActivityManagerService.java#3688)
    -   Android 每个 App 都有独立的 uid
    -   遍历进程表，找到属于 uid 的进程
    -   Process.KillProcessGroup
        -   [间隔 5ms，连续杀死 40 次](http://aospxref.com/android-12.0.0_r3/xref/system/core/libprocessgroup/processgroup.cpp#411)，防止数据竞争
        -   Operating System Transactions 的必要性

那么，我们是不是就可以利用数据竞争进程保活了呢？
-   成为孤儿进程从而不会立即收到 SIGKILL 信号
-   在被杀死后立即唤醒另一个进程: [flock-demo.c](http://jyywiki.cn/pages/OS/2022/demos/flock-demo.c)
    -   [A lightweight framework for fine-grained lifecycle control of Android applications](https://dl.acm.org/doi/10.1145/3302424.3303956) (EuroSys'19); “diehard apps”

### 一个真正的 “操作系统”
adb (Android Debug Bridge)
-   adb push/pull/install
-   adb shell
    -   screencap /sdcard/screen.png
    -   sendevent
-   adb forward
-   adb logcat/jdwp

一系列衍生的工具
-   开发者选项
-   scrcpy
-   Monkey/UI Automator

### 拥抱变化的世界
我们也试着蹭一波热度 (也决定不再蹭了)
-   Cross-device record and replay for Android apps (ESEC/FSE'22, Under review)
-   Detecting non-crashing functional bugs in Android apps via deep-state differential analysis (ESEC/FSE'22, Under review)
-   Push-button synthesis of watch companions for Android apps (ICSE'22)
-   ComboDroid: Generating high-quality test inputs for Android apps via use case combinations (ICSE'20)
-   Characterizing and detecting inefficient image displaying issues in Android apps (SANER'19)
-   ...
-   User guided automation for testing mobile apps (APSEC'14)

## 总结
本次课回答的问题
-   **Q**: 一个真正 “实用” 的操作系统 (生态) 是如何构成的？

Takeaway messages
-   服务、服务、服务
    -   Android Platform API
    -   Google Mobile Service (GMS)
    -   海量的工程细节
-   复杂系统无处不在
    -   能驾驭整个系统复杂性的架构师
    -   大量高水准的工程师，他们都在哪里？

 # OS32 最后一课总结从逻辑门到计算机系统
## 从逻辑门到计算机系统
### 数字系统：计算机系统的 “公理系统”
数字系统 = 状态机
-   状态：触发器
-   迁移：组合逻辑
    -   [logisim.c](http://jyywiki.cn/pages/OS/2022/demos/logisim.c) 和 [seven-seg.py](http://jyywiki.cn/pages/OS/2022/demos/seven-seg.py)
    -   NEMU Full System Emulator

![](http://jyywiki.cn/pages/OS/img/chisel-counter.png)
数字系统的设计 = 描述状态机
-   HDL (Verilog)
-   HCL (Chisel)
    -   编译生成 Verilog
-   HLS (High Level Synthesis)
    -   “从需求到代码”

### 编程语言和算法
C/Java/Python 程序 = 状态机
-   状态：栈、堆、全局变量
-   迁移：语句 (或语句一部分) 的执行
    -   “程序设计语言的形式语义”
    -   [hanoi-nr.c](http://jyywiki.cn/pages/OS/2022/demos/hanoi-nr.c)

编程 = 描述状态机
-   将人类世界的需求映射到计算机世界中的数据和计算
    -   DFS 走迷宫 [dfs-fork.c](http://jyywiki.cn/pages/OS/2022/demos/dfs-fork.c)
    -   Dijkstra 算法求最短路径……
-   允许使用操作系统提供的 API
    -   例子：`write(fd, buf, size)` 持久化数据

### 如何使程序在数字系统上运行？
指令集体系结构
-   在逻辑门之上建立的 “指令系统” (状态机)
    -   [The RISC-V Instruction Set Manual](http://jyywiki.cn/pages/OS/manuals/riscv-spec.pdf)
    -   既容易用电路实现，又足够支撑程序执行

编译器 (也是个程序)
-   将 “高级” 状态机 (程序) 翻译成的 “低级” 状态机 (指令序列)
    -   翻译准则：external visible 的行为 (操作系统 API 调用) 等价

操作系统 (也是个程序)
-   状态机 (运行中程序) 的管理者
    -   使程序可以共享一个硬件系统上的资源 (例如 I/O 设备)

### 操作系统上的程序 （OS2 回看一下！）
状态机 + 一条特殊的 “操作系统调用” 指令
-   syscall (2)
-   [minimal.S](http://jyywiki.cn/pages/OS/2022/demos/minimal.S)

程序的编译、链接和加载
-   [dl.h](http://jyywiki.cn/pages/OS/2022/demos/dl/dl.h), [dlbox.c](http://jyywiki.cn/pages/OS/2022/demos/dl/dlbox.c)
-   [libc.S](http://jyywiki.cn/pages/OS/2022/demos/dl/libc.S) - 提供 putchar 和 exit
-   [libhello.S](http://jyywiki.cn/pages/OS/2022/demos/dl/libhello.S) - 调用 putchar, 提供 hello
-   [main.S](http://jyywiki.cn/pages/OS/2022/demos/dl/main.S) - 调用 hello, 提供 main

### 操作系统对象和 API
![](http://jyywiki.cn/pages/OS/ostep-fun.jpg)

-   Concurrency - [thread.h](http://jyywiki.cn/pages/OS/2022/demos/thread.h) 和 [mem-ordering.c](http://jyywiki.cn/pages/OS/2022/demos/mem-ordering.c) 打开潘多拉的盒子
-   Virtualization - [sh-xv6.c](http://jyywiki.cn/pages/OS/2022/demos/sh-xv6.c); [fork-printf.c](http://jyywiki.cn/pages/OS/2022/demos/fork-printf.c); [dosbox-hack.c](http://jyywiki.cn/pages/OS/2022/demos/dosbox-hack.c)
-   Persistence - [fatree.c](http://jyywiki.cn/pages/OS/2022/demos/fatree.c); [fish-dir.sh](http://jyywiki.cn/pages/OS/2022/demos/fish-dir.sh)

### 你们获得了 “实现一切” 的能力！

M1 - pstree

-   打印进程树 (文件系统 API; procfs)

M2 - libco

-   进程内的状态机管理 (setjmp/longjmp)

M3 - sperf

-   strace (pipe; fork; execve)

M4 - crepl

-   动态链接和加载 (fork; execve; dlopen)

M5 - freov

-   文件系统解析 (mmap)

### 你们也获得了 “理解一切” 的能力！

“操作系统” 课给了你程序的 “最底层” 的状态机视角

-   也给了很多之前很难回答问题的答案
    -   如何创造一个 “最小” 的可执行文件？
        -   [minimal.S](http://jyywiki.cn/pages/OS/2022/demos/minimal.S)
    -   `a.out` 是什么？
    -   `a.out` 执行的第一条指令在哪里？
    -   `printf` 是如何被调用的？
    -   `a.out` 执行了哪些系统调用？
    -   `a.out` 执行了多少条指令？
        -   [inst-count.py](http://jyywiki.cn/pages/OS/2022/demos/inst-count.py)   #GDB  python with GDB, 用 python 写 gdb 执行的脚本
        - ![[Pasted image 20230303220141.png]]
        -   `perf stat -e instructions:u`

### 你们还理解了操作系统是如何实现的

![](http://jyywiki.cn/pages/OS/2022/slides/os-speedrun.jpg)

操作系统实现选讲

-   从 Firmware 到第一个用户程序 [bootmain.c](http://jyywiki.cn/pages/OS/2022/demos/bootmain.c)
-   迷你 “操作系统” [thread-os.c](http://jyywiki.cn/pages/OS/2022/demos/thread-os.c)
-   Xv6
    -   真正的 “教科书” 代码
    -   [spinlock-xv6.c](http://jyywiki.cn/pages/OS/2022/demos/spinlock-xv6.c)
    -   系统调用；文件系统；……
-   [linux-minimal.zip](https://box.nju.edu.cn/f/3f67e092e1ba441187d9/?dl=1)
    -   “核弹发射器” 驱动
-   OSLabs

### 从逻辑门到计算机系统

![](http://jyywiki.cn/pages/OS/img/android-stack.png)

刷一下手机，你的计算机系统经历了非常复杂的过程
-   应用程序 (app) → 库函数 (Android Framework) → 系统调用 → 操作系统中的对象 → 操作系统实现 (C 程序) → 设备驱动程序 → 硬件抽象层 → 指令集 → CPU, RAM, I/O设备 → 门电路

操作系统课给这个稍显复杂的过程一个清晰的轮廓
-   “这一切是可以掌控的”
-   RTFM! RTFSC!

## 所以你到底学到了什么？

> Operating systems (最重要的那个 piece): you're _delighted_

你不再惧怕任何 “system”

-   嵌入式系统
-   通用操作系统
-   分布式系统
-   ……

也不再惧怕任何 “需求” 的实现

-   找到合适的系统调用实现
-   做不到？可以自己加个系统调用
-   软件上实现不了？可以改 CPU 来支持！

## Hacker's Delights: 新的“理解”

“一切皆状态机”

-   状态的副本 (fork) 可以用来做什么？
    -   Model checking, failure recovery, ...

---

“死锁检测: lockdep 在每次 lock/unlock 的时候插入一条 printf”

-   这就是 dynamic analysis 的本质
    -   如何减少 printf 的数量、怎么巧妙地记录、怎样分析日志……
    -   如何调控程序的执行？找到 bug 还是绕开 bug？

---

“文件系统是磁盘上的一个数据结构”

-   通过 append-only 实现 journaling
-   LSM Tree 和分布式 key-value store
    -   Block chain 也是一个数据结构！

## 并发：走向分布式系统

如何为网络上的多台计算机提供统一的应用程序接口？

-   把多个分布的、随时可能离线的计算机组成一个存储系统
-   在存储的基础上完成计算

![](http://jyywiki.cn/pages/OS/img/hadoop-ecosystem.png)

## 虚拟化：重新理解操作系统设计

Microkernel, Exokernel, Unikernel

-   没有人规定操作系统里一定要有 “文件”、“进程” 这些对象

![](http://jyywiki.cn/pages/OS/img/microkernel.png)

## 持久化：重新理解持久存储设计

文件系统没能解决的需求

-   大量的数据 (订单、用户、网络……) + 非简单目录遍历性质的查询

---

“数据库”：虚拟磁盘上的数据结构

-   就像我们在内存 (random access memory) 上构建各种数据结构
    -   Binary heap, binary search tree, hash table, ...
-   典型的数据库
    -   关系数据库 (二维表、关系代数)
    -   key-value store (持久化的 `std::map`)
    -   VCS (目录树的快照集合)
-   SSD 和 NVM 带来的新浪潮

## 和操作系统相关的 Topics

-   Computer Architecture
    -   计算机硬件的设计、实现与评估
-   Computer Systems
    -   系统软件 (软件) 的设计、实现与评估
-   Network Systems
    -   网络与分布式系统的设计、实现与评估
-   Programming Languages
    -   状态机 (计算过程) 的描述方法、分析和运行时支持
-   Software Engineering
    -   程序/系统的构造、理解和经验
-   System/Software Security
    -   系统软件的安 (safety) 全 (integrity)

## 上操作系统课的乐趣

> 在课堂上时，你可以思考一些已经很清楚的基本东西。这些知识是很有趣、令人愉快的，重温一遍又何妨？另一方面，有没有更好的介绍方式？有什么相关的新问题？你能不能赋予这些旧知识新生命？……但如果你真的有什么新想法，能从新角度看事物，你会觉得很愉快。
> 
> 学生问的问题，有时也能提供新的研究方向。他们经常提出一些我曾经思考过、但暂时放弃、却都是些意义很深远的问题，重新想想这些问题，看看能否有所突破，也很有意思。
> 
> 学生未必理解我想回答的方向，或者是我想思考的层次；但他们问我这个问题，却往往提醒了我相关的问题。单单靠自己，是不容易获得这种启示的。 —— Richard Feynman

## 五周目的主要改进

课程主线

-   实现了 “一切皆状态机” 的教学思路 (四周目整改项目)
    -   改进了 model checker
    -   增加了一些以往很难讲的主题
        -   “编译器可以做什么样的优化”、“形式化验证”……
-   更明确地问题驱动 (四周目整改项目)
    -   在一定程度上实现了，但感觉还不满意

代码

-   增加了更多的示例代码 (四周目整改项目)
    -   [dosbox-hack.c](http://jyywiki.cn/pages/OS/2022/demos/dosbox-hack.c), [dlbox.c](http://jyywiki.cn/pages/OS/2022/demos/dl/dlbox.c), [fatree.c](http://jyywiki.cn/pages/OS/2022/demos/fatree.c)
    -   以及一系列的代码改进
-   动态链接似乎讲得更清楚了

## 自我批评与六周目

课程主线

-   还欠一些代码
    -   RAID 模拟器 (OSTEP 上的模拟器不太适合课堂教学)
    -   Xv6 文件系统 block trace 和崩溃恢复
    -   ...
-   Model checker: Once and for all
    -   并发 + 进程 + crash consistency
-   重写课程网站/Online Judge
    -   整改项目，再再次未能如愿

---

其他

-   欢迎大家提建议/意见 (例如 “增加 XXX 代码就好了”)


## 脖子被卡也不是偶然的

高考：为大众提供了阶级跃升的途径

代价：过度强化的训练和 (部分) 扭曲的价值观

-   进入大学以后的 “去高考化” 反而没有做好
    -   陈腐乏味的课程
    -   局限的视野
    -   稳固的舒适区
    -   畏惧哪怕一点点的风险

---

“我也想去改变世界，但拿什么去改变呢？”

-   [CS 自学指南](https://csdiy.wiki/)

## 在座各位的使命

> 重新定义 “专家”。

---

-   那些愿意站出来颠覆一个行业的人
-   那些能管理好工程项目的人
-   那些能驾驭的了大规模代码的人
    -   去共同完成一些旁人看来 “惊为天人” 的东西，
    -   去推动这个世界的进步

---

> 我们的征途是星辰和大海。

# 对自己要求高一点

  

(没什么前途的老学长对你们的期待)