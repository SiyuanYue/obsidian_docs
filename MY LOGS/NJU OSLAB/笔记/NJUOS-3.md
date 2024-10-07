# OS 26 文件系统 API
## Overview
复习
-   对 I/O 设备的抽象
    -   物理层 1-bit 的存储
    -   设备层 I/O 设备 (寄存器)
    -   驱动层 (可读/写/控制的对象)
    -   块设备层 (block read/write)

本次课回答的问题
-   **Q**: **如何使应用程序能共享存储设备？**

本次课主要内容
-   文件系统需求分析
-   文件系统 API

## 为什么需要文件系统？
### 设备在应用程序之间的共享
终端
-   多个进程并行打印，如何保证不混乱？([printf-race.c](http://jyywiki.cn/pages/OS/2022/demos/printf-race.c))
    -   Unicode 字符和 Escape Code 被隔断可不是闹着玩的
-   多个进程并行读，就会发生争抢
    -   谁抢到谁赢 (还算可以接受)
    -   后台进程会在读终端时收到 SIGTTIN (RTFM)

GPU (CUDA)
-   每个 CUDA 应用程序都是一系列 CUDA API 的调用
    -   cudaMemcpy, kernel call
-   全部由设备驱动负责调度 (和隔离)
    -   Kernel 要等空闲 thread warp 才可以上，执行完后归还 

### 设备在应用程序之间的共享 (cont'd)
磁盘需要支持数据的持久化
-   程序数据
    -   可执行文件和动态链接库
    -   应用数据 (高清图片、过场动画、3D 模型……)
-   用户数据
    -   文档、下载、截图、replay……
-   系统数据
    -   Manpages
    -   系统配置

字节序列并不是磁盘的好抽象
-   让所有应用共享磁盘？一个程序 bug 操作系统就没了

### 文件系统：虚拟磁盘
**文件系统：设计目标**
1.  **提供合理的 API 使多个应用程序能共享数据**
2.  **提供一定的隔离，使恶意/出错程序的伤害不能任意扩大**

“存储设备 (字节序列) 的*虚拟化*”
-   磁盘 (I/O 设备) = 一个可以读/写的字节序列
-   虚拟磁盘 (文件) = 一个可以读/写的动态字节序列
    -   命名管理
        -   虚拟磁盘的名称、检索和遍历
    -   数据管理
        -   `std::vector<char>` (随机读写/resize)

## 虚拟磁盘：命名管理
### 怎么找到想要的虚拟磁盘？
*信息的局部性*：将虚拟磁盘 (文件) 组织成层次结构
![](http://jyywiki.cn/pages/OS/img/nju-lib.jpg)

### 利用信息的局部性组织虚拟磁盘
目录树
-   逻辑相关的数据存放在相近的目录

```text
. 
└── 学习资料
	├── .学习资料(隐藏)   
	├── 问题求解1     
	├── 问题求解2     
	├── 问题求解3     
	├── 问题求解4     
	└── 操作系统
```
### 文件系统的 “根”
树总得有个根结点

![](http://jyywiki.cn/pages/OS/img/IBM-PC-5150.jpg)

-   Windows: 每个设备 (驱动器) 是一棵树
    -   `C:\` “C 盘根目录”
        -   `C:\Program Files\`, `C:\Windows`, `C:\Users`, ...
    -   优盘分配给新的盘符
        -   为什么没有 `A:\`, `B:\`?
        -   简单、粗暴、方便，但 `game.iso` 一度非常麻烦……
-   UNIX/Linux
    -   只有一个根 `/`
        -   第二个设备呢？
        -   优盘呢？？？

### 目录树的拼接
UNIX: 允许任意目录 “挂载 (mount)” 一个设备代表的目录树
-   非常灵活的设计
    -   可以把设备挂载到任何想要的位置
    -   Linux 安装时的 “mount point”
        -   `/`, `/home`, `/var` 可以是独立的磁盘设备

mount 系统调用
```C
int mount(const char *source, const char *target,           
		  const char *filesystemtype, unsigned long mountflags,           
		  const void *data);
```
-  mount /dev/sdb /mnt `(RTFM)`
    -   Linux mount 工具能自动检测文件系统 (busybox 不能)

### 真正的 Linux 启动流程
Linux-minimal 运行在 “initramfs” 模式
-   Initial RAM file system
-   完整的文件系统
    -   可以包含设备驱动等任何文件 ([launcher.c](http://jyywiki.cn/pages/OS/2022/demos/launcher.c))
    -   但不具有 “持久化” 的能力

最小 “真正” Linux 的启动流程
```shell
export PATH=/bin 
busybox mknod /dev/sda b 8 0 
busybox mkdir -p /newroot 
busybox mount -t ext2 /dev/sda /newroot 
exec busybox switch_root /newroot/ /etc/init
```
通过 `pivot_root` (2) 实现根文件系统的切换

### 文件的挂载
文件的挂载引入了一个微妙的循环
-   文件 = 磁盘上的虚拟磁盘
-   挂载文件 = 在虚拟磁盘上虚拟出的虚拟磁盘 🤔

Linux 的处理方式
-   创建一个 loopback (回环) 设备
    -   设备驱动把设备的 read/write 翻译成文件的 read/write
-   观察 [disk-img.tar.gz](http://jyywiki.cn/pages/OS/2021/demos/disk-img.tar.gz) 的挂载
    -   lsblk 查看系统中的 block devices (strace)
    -   strace 观察挂载的流程
        -   `ioctl(3, LOOP_CTL_GET_FREE)`
        -   `ioctl(4, LOOP_SET_FD, 3)`

### [Filesystem Hierarchy Standard](http://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html) (FHS)
> FHS enables _software and user_ to predict the location of installed files and directories.

例子：macOS 是 UNIX 的内核 (BSD), 但不遵循 Linux FHS

![](http://jyywiki.cn/pages/OS/img/fhs.jpg)

## 目录 API (系统调用)
### 目录管理：创建/删除/遍历
这个简单
-   mkdir
    -   创建一个目录
    -   可以设置访问权限
-   rmdir
    -   删除一个空目录
    -   没有 “递归删除” 的系统调用
        -   (应用层能实现的，就不要在操作系统层实现)
        -   `rm -rf` 会遍历目录，逐个删除 (试试 strace)
-   getdents
    -   返回 `count` 个目录项 (ls, find, tree 都使用这个)
        -   以点开头的目录会被系统调用返回，只是 ls 没有显示
    - `man 2 getdents`  一个**底层系统调用**, 类似 link，unlink，mount         
    - 实际使用：`man readdir（glibc）` M1 LAB 用过哦

### 更人类友好的目录访问方式
实际实现应用，而非 OS 课专门折麽你时： **合适的 API + 合适的编程语言**
-   [Globbing](https://www.gnu.org/software/libc/manual/html_node/Calling-Glob.html)

```python
from pathlib import Path  for f in Path('/proc').glob('*/status'):
	print(f.parts[-2], \
	    (f.parent / 'cmdline').read_text() or '[kernel]')
```
-   这才是人类容易使用的方式
    -   C++17 filesystem API 那叫一个难用 😂
### 硬 (hard) 链接
需求：系统中可能有同一个运行库的多个版本
-   `libc-2.27.so`, `libc-2.26.so`, ...
-   还需要一个 “当前版本的 libc”
    -   程序需要链接 “`libc.so.6`”，能否避免文件的一份拷贝？

硬连接：允许一个文件被多个目录引用
-   目录中仅存储指向文件数据的指针
-   链接目录 ❌
-   跨文件系统 ❌

大部分 UNIX 文件系统所有文件都是硬连接 (`ls -i` 查看)
-   删除的系统调用称为 “unlink” (引用计数)

### 软 (symbolic) 链接  （符号链接）
软链接：在文件里存储一个 “跳转提示”
-   软链接也是一个文件
    -   当引用这个文件时，去找另一个文件
    -   另一个文件的绝对/相对路径以文本形式存储在文件里
    -   可以跨文件系统、可以链接目录、……
-   类似 “快捷方式”
    -   链接指向的位置当前不存在也没关系
    -   `~/usb` → `/media/jyy-usb`
    -   `~/Desktop` → `/mnt/c/Users/jyy/Desktop` (WSL)

`ln -s` 创建软链接
-   `symlink` 系统调用

### 软链接带来的麻烦
“任意链接” 允许创建任意有向图 😂
-   允许多次间接链接
    -   a → b → c (递归解析)
-   可以创建软连接的硬链接 (因为软链接也是文件)
    -   `ls -i` 可以看到
-   允许成环
    -   [fish.c](http://jyywiki.cn/pages/OS/2022/demos/fish.c) 自动机的目录版本：[fish-dir.sh](http://jyywiki.cn/pages/OS/2022/demos/fish-dir.sh)
        -   `find -L A | tr -d '/'`
        -   可以做成一个 “迷宫游戏”
            -   ssh 进入游戏，进入名为 end 的目录胜利
            -   只允许 ls (-i), cd, pwd
    -   所有处理符号链接的程序 (tree, find, ...) 都要考虑递归的情况

### 进程的 “当前目录”
Working/current directory
-   `pwd` 命令或 `$PWD` 环境变量可以查看
-   `chdir` 系统调用修改
    -   对应 shell 中的 cd
    -   注意 cd 是 shell 的内部命令
        -   不存在 `/bin/cd`

问题：线程是共享 working directory, 还是各自独立持有一个？

## 文件 API (系统调用)
### 复习：文件和文件描述符
文件：虚拟的磁盘
-   磁盘是一个 “字节序列”
-   支持读/写操作

文件描述符：进程访问文件 (操作系统对象) 的 “指针”
-   通过 open/pipe 获得
-   通过 close 释放
-   通过 dup/dup2 复制
-   fork 时继承

### 复习：mmap
使用 open 打开一个文件后
-   用 `MAP_SHARED` 将文件映射到地址空间中
-   用 `MAP_PRIVATE` 创建一个 copy-on-write 的副本

```C
void *mmap(void *addr, size_t length, int prot, int flags,   
		   int fd, off_t offset); // 映射 fd 的 offset 开始的 length 字节
int munmap(void *addr, size_t length); 
int msync(void *addr, size_t length, int flags);
```
小问题：
-   映射的长度超过文件大小会发生什么？
    -   (RTFM, “Errors” section): **`SIGBUS`**...
        -   bus error 的常见来源 (M5)
        -   ftruncate 可以改变文件大小

### 文件访问的游标 (偏移量)
文件的读写自带 “游标”，这样就不用每次都指定文件读/写到哪里了
-   方便了程序员顺序访问文件

例子
-   `read(fd, buf, 512);` - 第一个 512 字节
-   `read(fd, buf, 512);` - 第二个 512 字节
-   `lseek(fd, -1, SEEK_END);` - 最后一个字节
    -   so far, so good

### 偏移量管理：没那么简单 (1)
mmap, lseek, ftruncate 互相交互的情况
-   初始时文件大小为 0
    1.  mmap (`length` = 2 MiB)
    2.  lseek to 3 MiB (`SEEK_SET`)
    3.  ftruncate to 1 MiB

在任何时刻，写入数据的行为是什么？
-   blog posts 不会告诉你全部
-   RTFM & 做实验！

### 偏移量管理：没那么简单 (2)
> 文件描述符在 fork 时会被子进程继承。

父子进程应该共用偏移量，还是应该各自持有偏移量？
-   这决定了 `offset` 存储在哪里

考虑应用场景
-   父子进程同时写入文件
    -   各自持有偏移量 → 父子进程需要协调偏移量的竞争
        -   (race condition)
    -   共享偏移量 → 操作系统管理偏移量
        -   虽然仍然共享，但操作系统保证 `write` 的原子性 ✅

### 偏移量管理：行为
操作系统的每一个 API 都可能和其他 API 有交互 😂
1.  open 时，获得一个独立的 offset
2.  dup 时，两个文件描述符共享 offset
3.  fork 时，父子进程共享 offset
4.  execve 时文件描述符不变
5.  `O_APPEND` 方式打开的文件，偏移量永远在最后 (无论是否 fork)
    -   modification of the file offset and the write operation are performed as a single atomic step

这也是 fork 被批评的一个原因
-   (在当时) 好的设计可能成为系统演化过程中的包袱
    -   今天的 fork 可谓是 “补丁满满”；[A `fork()` in the road](https://dl.acm.org/doi/10.1145/3317550.3321435)

## 总结
### 本次课回答的问题
Q: 如何设计文件系统，使应用程序能共享存储设备？
Takeaway messages
### 文件系统的两大主要部分
* 虚拟磁盘 (文件)
	*  mmap, read, write, lseek, ftruncate, ...
* 虚拟磁盘命名管理 (目录树和链接)
	* mount, chdir, mkdir, rmdir, link, unlink, symlink, open, ...

# OS 27 FAT 和 UNIX 文件系统
## Overview
复习：文件系统 API
-   目录 (索引)
    -   “图书馆” - mkdir, rmdir, link, unlink, open, ...
-   文件 (虚拟磁盘)
    -   “图书” - read, write, mmap, ...
-   文件描述符 (偏移量)
    -   “书签” - lseek

---
本次课回答的问题
-   **Q**: 如何实现这些 API？
---
本次课主要内容
-   FAT 和 ext2/UNIX 文件系统

## 回到数据结构课
### 什么是文件系统实现？
在一个 I/O 设备 (block device) 上实现所有文件系统 API
-   `bread(int id, char *buf);`
-   `bwrite(int id, const char *buf);`
    -   假设所有操作排队同步完成
    -   (可以在 block I/O 层用队列实现)

目录/文件 API
-   `mkdir`, `rmdir`, `link`, `unlink`
-   `open`, `read`, `write`, `stat`

### 回到数据结构课……
文件系统就是一个数据结构 (抽象数据类型；ADT)
-   只是和数据结构课上的假设稍有不同

数据结构课程的假设
-   冯诺依曼计算机
-   Random Access Memory (RAM)
    -   Word Addressing (例如 32/64-bit load/store)
    -   每条指令执行的代价是 O (1)
        -   Memory Hierarchy 在苦苦支撑这个假设 (cache-unfriendly 代码也会引起性能问题)

文件系统的假设
-   按*块 (例如 4KB)* 访问，在磁盘上构建 RAM 模型完全不切实际

### 数据结构的实现
Block device 提供的设备抽象
```C
struct block blocks[NBLK]; // 磁盘 
void bread(int id, struct block *buf) { memcpy(buf, &blocks[id], sizeof(struct block)); } void bwrite(int id, const struct block *buf) { memcpy(&blocks[id], buf, sizeof(struct block)); }
```
在 bread/bwrite 上实现块的分配与回收 (与 pmm 类似)
```C
int balloc(); // 返回一个空闲可用的数据块 void bfree(int id); // 释放一个数据块
```
### 数据结构的实现 (cont'd)
在 balloc/bfree 上实现磁盘的虚拟化
-   文件 = `vector<char>`
    -   用链表/索引/任何数据结构维护
    -   支持任意位置修改和 resize 两种操作

在文件基础上实现目录
-   “目录文件”
    -   把 `vector<char>` 解读成 `vector<dir_entry>`
    -   连续的字节存储一个目录项 (directory entry)

## File Allocation Table (FAT)
### 让时间回到 1980 年
5.25" 软盘：单面 180 KiB
-   360 个 512B 扇区 (sectors)
-   在这样的设备上实现文件系统，应该选用怎样的数据结构？

![](http://jyywiki.cn/pages/OS/img/floppy-drives.jpg)

### FAT 文件系统中的文件

`int balloc(); // 返回一个空闲可用的数据块 void bfree(int id); // 释放一个数据块 vector<struct block *> file; // 文件 // 文件的名称、大小等保存在目录中`
注意到这是相当小的文件系统
-   树状的目录结构
-   系统中以小文件为主 (几个 block 以内)

文件的实现方式
-   `struct block *` 的链表
    -   任何复杂的高级数据结构都显得浪费

### 用链表存储数据：两种设计
1.  在每个数据块后放置指针
    -   优点：实现简单、无须单独开辟存储空间
    -   缺点：数据的大小不是 $2^k$; 单纯的 lseek 需要读整块数据
2.  将指针集中存放在文件系统的某个区域
    -   优点：局部性好；lseek 更快
    -   缺点：集中存放的数据损坏将导致数据丢失

哪种方式的缺陷是致命、难以解决的？
#man man lseek

### 集中保存所有指针
集中存储的指针容易损坏？存 �n 份就行！
-   FAT-12/16/32 (FAT entry，即 “next 指针” 的大小)

![](http://jyywiki.cn/pages/OS/img/fat32_layout.gif)

### “File Allocation Table” 文件系统
![](http://jyywiki.cn/pages/OS/img/chat-rtfm.png)
[RTFM](http://jyywiki.cn/pages/OS/manuals/MSFAT-spec.pdf) 得到必要的细节   #man
-   诸如 tutorial、博客都不可靠
-   还会丢失很多重要的细节

`if (CountofClusters < 4085) {   // Volume is FAT12 (2 MiB for 512B cluster) } else if (CountofCluster < 65525) {   // Volume is FAT16 (32 MiB for 512B cluster) } else {   // Volume is FAT32 }`
### FAT: 链接存储的文件
“FAT” 的 “next” 数组
-   `0`: free; `2...MAX`: allocated;
-   `ffffff7`: bad cluster; `ffffff8-ffffffe`, `-1`: end-of-file

![](http://jyywiki.cn/pages/OS/img/FAT-number.png)

### 目录树实现：目录文件
以普通文件的方式存储 “目录” 这个数据结构
-   FAT: 目录 = 32-byte 定长目录项的集合
-   操作系统在解析时把标记为目录的目录项 “当做” 目录即可
    -   可以用连续的若干个目录项存储 “长文件名”
-   思考题：为什么不把元数据 (大小、文件名、……) 保存在 `vector<struct block *> file` 的头部？

![](http://jyywiki.cn/pages/OS/img/FAT-dent.png)

### Talk is Cheap, Show Me the Code!
首先，观察 “快速格式化” (`mkfs.fat`) 是如何工作的  #man man mkfs. fat, man  fstat
-   老朋友：strace   

然后，把整个磁盘镜像 mmap 进内存 
-   照抄手册，遍历目录树：[fatree.c](http://jyywiki.cn/pages/OS/2022/demos/fatree.c)

另一个有趣的问题 ([M5 - frecov](http://jyywiki.cn/OS/2022/labs/M5))
-   快速格式化 = FAT 表丢失
    -   所有的文件内容 (包括目录文件) 都还在
    -   只是在数据结构眼里看起来都是 “free block”
-   首先需要猜出文件系统的参数 (`SecPerClus`, `BytsPerSec`, `FATSz32`, `BPB_RootClus`, ...)
-   本质上是 cluster 的分类和建立 “可能后继关系”

### FAT: 性能与可靠性
性能
-   ＋ 小文件简直太合适了
-   － 但大文件的随机访问就不行了
    -   4 GB 的文件跳到末尾 (4 KB cluster) 有 220220 次链表 next 操作
    -   缓存能部分解决这个问题
-   在 FAT 时代，磁盘连续访问性能更佳
    -   使用时间久的磁盘会产生碎片 (fragmentation)
        -   malloc 也会产生碎片，不过对性能影响不太大

可靠性
-   维护若干个 FAT 的副本防止元数据损坏
    -   额外的同步开销
-   损坏的 cluster 在 FAT 中标记

## ext2/UNIX 文件系统
### ext2 inode

![](http://jyywiki.cn/pages/OS/img/ext2-inode.gif)

### ext2 目录文件
与 FAT 本质相同：在文件上建立目录的数据结构
-   注意到 inode 统一存储
    -   目录文件中存储文件名到 inode 编号的 key-value mapping

![](http://jyywiki.cn/pages/OS/img/ext2-dirent.jpg)

### ext2: 性能与可靠性
大文件的随机读写性能提升明显 (�(1)O(1))
-   支持链接 (一定程度减少空间浪费)
-   inode 在磁盘上连续存储，便于缓存/预取
-   依然有碎片的问题

但可靠性依然是个很大的问题
-   存储 inode 的数据块损坏是很严重的

## 总结
本次课回答的问题
-   **Q**: 如何在磁盘上实现文件系统 API？
    -   “图书馆” - mkdir, rmdir, link, unlink, open, ...
    -   “图书/书签” - read, write, mmap, lseek, ...

Takeaway messages
-   文件系统实现 = 自底向上设计实现数据结构
    -   balloc/bfree
    -   FAT/inode/...
    -   文件和目录文件

# OS 28 持久数据的可靠性
## Overview
复习
-   文件系统实现：bread/bwrite 上的数据结构
    -   balloc/bfree
    -   文件：FAT (链表)/UNIX 文件系统 (索引)
    -   目录文件

本次课回答的问题
-   数据结构的另一个假设：内存可靠且可以接受断电数据丢失
-   **Q**: 持久数据是不能接受丢失的，如何保证持久数据的可靠性？

本次课主要内容
-   RAID (Redundant Array of Inexpensive Disks)
-   崩溃一致性

## Redundant Array of Inexpensive Disks (RAID)
### 日渐增长的持久存储需求 (1)——性能
存储：只要 CPU (DMA) 能处理得过来，我就能提供足够的带宽！
-   Computer System 的 “industry” 传统——做真实有用的系统

![](http://jyywiki.cn/pages/OS/img/emc-vnx5300.jpg)

### 日渐增长的持久存储需求 (2)——可靠性
任何物理存储介质都有失效的可能
-   你依然希望在存储设备失效的时候能保持数据的完整
    -   极小概率事件：战争爆发/三体人进攻地球/世界毁灭 😂
    -   小概率事件：硬盘损坏
        -   大量重复 = 必然发生 (但我们还是希望系统能照常运转)

![](http://jyywiki.cn/pages/OS/img/datacenter.jpg)
### RAID: 存储设备的虚拟化
> 那么，性能和可靠性，我们能不能全都要呢？

Redundant Array of Inexpensive (_Independent_) Disks (RAID)
-   把多个 (不可靠的) 磁盘虚拟成一块非常可靠且性能极高的虚拟磁盘
    -   [A case for redundant arrays of inexpensive disks (RAID)](https://dl.acm.org/doi/10.1145/971701.50214) (SIGMOD'88)

RAID 是一个 “反向” 的虚拟化
-   进程：把一个 CPU 分时虚拟成多个虚拟 CPU
-   虚存：把一份内存通过 MMU 虚拟成多个地址空间
-   文件：把一个存储设备虚拟成多个虚拟磁盘
### RAID 的 Fault Model: Fail-Stop
磁盘可能在某个时刻忽然彻底无法访问
-   机械故障、芯片故障……
    -   磁盘好像就 “忽然消失” 了 (数据完全丢失)
    -   假设磁盘能报告这个问题 (如何报告？)
-   [An analysis of data corruption in the storage stack](https://www.usenix.org/conference/fast-08/analysis-data-corruption-storage-stack) (FAST'08)

在那个遍地是黄金的年代
-   1988: 凑几块盘，掀翻整个产业链！
    -   “Single Large Expensive Disks” (IBM 3380), v.s.
    -   “Redundant Array of Inexpensive Disks”

### 一个最简单的想法
在系统里多接入一块硬盘用于 Fault Tolerance (RAID-1)
-   假设有两块盘 A, B
    -   同样规格，共有 n 块
-   “镜像” 虚拟磁盘 V
    -   $V_i​→\{ A_i​，B_i\}(1≤i≤n)$

块读写
-   bread ($i$)
    -   可以从 $A$ 或 $B$ 中的任意一个读取
-   bwrite ($i$)
    -   同时将同样的数据写入 $A$, $B$ 的同一位置
-   容错，且读速度翻倍 (假设内存远快于磁盘)

### RAID: Design Space
> RAID (虚拟化) = 虚拟磁盘块到物理磁盘块的 “映射”。

两块磁盘的其他拼接方法
-   顺序拼接
    -  $V_1​→A_1​,V_2​→A_2​, ……V_n​→A_n​$
    -   $V_n+1​→B_1​, V_n+2​→B_2​, ……, V_2n​→B_n​$
-   交错排列 (RAID-0)
    -  $V_1​→A_1​, V_2​→B_1$ ​
    -  $V_3​→A_2​, V_4​→B_2​$
    -  $V_{2i−1}​→A_i​, V_{2i​}→B_i$ ​
-   虽然不能容错，但可以利用好磁盘的带宽

## 崩溃一致性与崩溃恢复
### 另一种 Fault Model
磁盘并没有故障
-   但操作系统内核可能 crash，系统可能断电

![](http://jyywiki.cn/pages/OS/img/cat-crash-consistency.jpg)

文件系统：设备上的树结构
-   即便只是 append 一个字节，也涉及多处磁盘的修改
    -   FAT、目录文件 (文件大小) 和数据
    -   磁盘本身不提供 “all or nothing” 的支持

### 崩溃一致性 (Crash Consistency)
> **Crash Consistency**: Move the file system from one consistent state (e.g., before the file got appended to) to another atomically (e.g., after the inode, bitmap, and new data block have been written to disk).

(你们平时编程时假设不会发生的事，操作系统都要给你兜底)
磁盘不提供多块读写 “all or nothing” 的支持
-   甚至为了性能，没有顺序保证
    -   bwrite 可能被乱序
    -   所以磁盘还提供了 bflush 等待已写入的数据落盘
    -   回到被并发编程支配的恐惧？[peterson-barrier.c](http://jyywiki.cn/pages/OS/2022/demos/peterson-barrier.c)
-   ~~那我们也可以考虑提供啊：[Transactional flash](https://dl.acm.org/doi/10.5555/1855741.1855752) (OSDI'08)~~

### 磁盘乱序的后果

为 FAT 文件追加写入一个 cluster (4KB) 需要更新

-   目录项中的文件大小 (100 → 4196)
-   FAT 表中维护的链表 (EOF → cluster-id, FREE → EOF)
-   实际数据

---

这麻烦了……

-   任何一个子集的写入丢失都可能出现
-   文件系统就进入了 “不一致” 的状态
    -   可能违反 FAT 的基本假设
        -   链表无环且长度和文件大小一致
        -   FREE 的 cluster 不能有入边
        -   ……

## File System Checking (FSCK)

根据磁盘上已有的信息，恢复出 “最可能” 的数据结构

![](http://jyywiki.cn/pages/OS/img/fsck-recovery.png)

-   [SQCK: A declarative file system checker](https://dl.acm.org/doi/10.5555/1855741.1855751) (OSDI'08)
-   [Towards robust file system checkers](https://dl.acm.org/doi/10.1145/3281031) (FAST'18)
    -   “widely used file systems (EXT4, XFS, BtrFS, and F2FS) may leave the file system in an uncorrectable state if the repair procedure is interrupted unexpectedly” 😂

## 日志 (Journaling)
### 实现 Atomic Append
用 bread, bwrite 和 bflush 实现 append()
![](http://jyywiki.cn/pages/OS/img/fs-journaling.png)
1.  定位到 journal 的末尾 (bread)
2.  bwrite TXBegin 和所有数据结构操作
3.  bflush 等待数据落盘
4.  bwrite TXEnd
5.  bflush 等待数据落盘
6.  将数据结构操作写入实际数据结构区域
7.  等待数据落盘后，删除 (标记) 日志

### Journaling: 优化
现在磁盘需要写入双份的数据
-   批处理 (xv6; jbd)
    -   多次系统调用的 Tx 合并成一个，减少 log 的大小
    -   jbd: 定期 write back
-   Checksum (ext4)
    -   不再标记 TxBegin/TxEnd
    -   直接标记 Tx 的长度和 checksum
-   Metadata journaling (ext4 default)
    -   数据占磁盘写入的绝大部分
        -   只对 inode 和 bitmap 做 journaling 可以提高性能
    -   保证文件系统的目录结构是一致的；但数据可能丢失

### Metadata Journaling
从应用视角来看，文件系统的行为可能很怪异
-   各类系统软件 (*git*, sqlite, gdbm, ...) 不幸中招                      #man `man sync`
    -   [All file systems are not created equal: On the complexity of crafting crash-consistent applications](https://cn.bing.com/search?q=All+file+systems+are+not+created+equal%3A+On+the+complexity+of+crafting+crash-consistent+applications&form=APMCS1&PC=APMC) (OSDI'14)
    -   (os-workbench 里的小秘密)
-   [更多的应用程序可能发生 data loss](https://zhuanlan.zhihu.com/p/25188921)
    -   我们的工作: GNU coreutils, gmake, gzip, ... 也有问题
    -   [Crash consistency validation made easy](https://dl.acm.org/doi/10.1145/2950290.2950327) (FSE'16)

更为一劳永逸的方案：TxOS
-   xbegin/xend/xabort 系统调用实现跨 syscall 的 “all-or-nothing”
    -   应用场景：数据更新、软件更新、check-use……
    -   [Operating systems transactions](https://dl.acm.org/doi/10.1145/1629575.1629591) (SOSP'09)
## 总结
本次课回答的问题
-   **Q**: 如何保证持久数据的可靠性？
    -   硬件冗余：RAID
    -   软件容错：fsck 和 journaling

Takeaway messages
-   多个 bwrite 不保证顺序和原子性
-   Journaling: 数据结构的两个视角
    -   真实的数据结构
    -   执行的历史操作

# OS 29 Xv6 文件系统实现
## Overview
复习
-   文件系统：bread/bwrite 上的数据结构
    -   balloc/bfree
    -   文件：FAT (链表)/UNIX 文件系统 (索引)
    -   目录文件
-   持久数据的可靠性
    -   RAID 和日志

本次课回答的问题
-   **Q**: 到底能不能看一看文件系统实现的代码？

本次课主要内容
-   Xv6 文件系统实现

## 文件系统：复习
### “磁盘上的数据结构”
支持的操作
-   目录 (索引)
    -   “图书馆” - mkdir, rmdir, link, unlink, open, ...
-   文件 (虚拟磁盘)
    -   “图书” - read, write, mmap, ...
-   文件描述符 (偏移量)
    -   “书签” - lseek

实现的方法
-   block I/O → block 管理 → 文件 → 目录文件
-   FAT: 文件信息 “分别” 保存在链表和目录项中
-   UNIX 文件系统：集中存储文件对象

## RTFSC
(讨论：假设你第一次阅读这部分代码，应该怎么做？)
### mkfs: 创建文件系统 (格式化)
`// Disk layout: // [ boot block | sb block | log | inode blocks //              | free bit map | data blocks ]`
可以知道每一部分的含义
-   boot block - 启动加载器
-   sb block (super block) - 文件系统元数据
-   log - 日志 (崩溃恢复)
-   inode blocks
-   free bitmap - balloc/bfree
-   data blocks
    -   RTFSC!

### mkfs: 创建文件系统 (cont'd)
“只管分配、不管回收” (类似于极限速通)
-   rsect/wsect (bread/bwrite)
-   balloc/bzero
-   ialloc
-   iappend
-   rinode/winode

RTFSC 的正确方式
-   “读代码不如读执行”: [trace.py](http://jyywiki.cn/pages/OS/2022/demos/trace.py)
-   `gdb -ex 'source mkfs/trace.py' mkfs/mkfs`


> #gdb  gdb 第 0 层用法：
  不断启动 gdb , 打断点，运行，查看与调试
  gdb 第一层用法：
  gdbinit
  省的每次手输，每次运行时设置好，打好想要的断点
  	![[Pasted image 20230211172957.png]]
  	再进一层：
  	回到程序时状态机
  	gdb+python trace 观测状态机的运行
  	用 python 写一个控制 gdb 的脚本

#git git blame [file]   妙！查看修改提交记录

### buffer cache
![[Pasted image 20230211224042.png]]
## 调试代码
### 调试系统调用
有很多选择
-   open - 路径解析、创建文件描述符
-   read/write - 文件描述符和数据操作
-   link - 文件元数据操作
-   ...

应该选哪一个？
-   取决于你对代码的熟悉程度和信心
    -   有信心可以选复杂一些的
    -   没有信心可以选简单一些的
-   但如果有了刚才的铺垫，应该都有信心！
## 崩溃恢复
### 能否让我们调试崩溃恢复的代码？
> “Get out of your comfort zone.”

懒惰是我们的本性
-   “调试这部分代码有点小麻烦”
-   “反正考试也不考，算了吧”
    -   一定要相信是可以优雅地做到的

课程作业的意义
-   逼迫大家克服懒惰
    -   好作业的设计必须是 “不吃苦做不出来”
-   获得激励和 “self motivation”

### 故障注入 (Fault Injection)
Crash = “断电”
`void crash() {   static int count = 100;   if (--count < 0) {     printf("crash\n");     *((int *)0x100000) = 0x5555;   } }`
-   (“[sifive finisher](https://patchwork.kernel.org/project/linux-riscv/patch/20191107212408.11857-3-hch@lst.de/)”)

xv6 是相对比较 deterministic 的
-   枚举可能的 count
    -   我们就得到了一个 “测试框架”！
    -   我们用类似的 trick 模拟应用程序写入数据后的系统崩溃
## 总结
本次课回答的问题
-   **Q**: 到底怎么实现一个真正的文件系统？
    -   Xv6 文件系统：mkfs; 系统调用实现和日志

Takeaway messages
-   调试代码的建议
    -   先了解一下你要调试的对象
    -   然后从 trace 开始
    -   不要惧怕调试任何一部分