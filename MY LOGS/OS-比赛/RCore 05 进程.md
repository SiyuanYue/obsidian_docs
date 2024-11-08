

进程就是操作系统选取某个可执行文件并对其进行一次动态执行的过程。相比可执行文件，它的动态性主要体现在：

1.  它是一个过程，从时间上来看有开始也有结束；
    
2.  在该过程中对于可执行文件中给出的需求要相应对 **硬件/虚拟资源** 进行 **动态绑定和解绑** 。


这里需要指出的是，两个进程可以选择同一个可执行文件执行，然而它们却是截然不同的进程：它们的启动时间、占据的硬件资源、输入数据均有可能是不同的，这些条件均会导致它们是不一样的执行过程。在某些情况下，我们可以看到它们的输出是不同的——这是其中一种可能的直观表象。

>**为何要在这里才引入进程**
>根据我们多年来的 OS 课程经验，学生对 **进程** 的简单定义“ **正在执行的程序** ”比较容易理解。但对于多个运行的程序之间如何切换，会带来哪些并发问题，进程创建与虚拟内存的关系等问题很难一下子理解清楚，也不清楚试图解决这些问题的原因。这主要是由于学生对进程的理解是站在应用程序角度来看的。
>如果变化一下，让学生站在操作系统的角度来看，那么在进程这个定义背后，有特权级切换、异常处理，程序执行的上下文切换、地址映射、地址空间、虚存管理等一系列的知识支撑，才能理解清楚操作系统对进程的整个管理过程。所以，我们在前面几章对上述知识进行了铺垫。并以此为基础，更加全面地来分析操作系统是如何管理进程的。

> **进程，线程和协程**
> 进程，线程和协程是操作系统中经常出现的名词，它们都是操作系统中的抽象概念，有联系和共同的地方，但也有区别。计算机的核心是 CPU，它承担了基本上所有的计算任务；而操作系统是计算机的管理者，它可以以进程，线程和协程为基本的管理和调度单位来使用 CPU 执行具体的程序逻辑。
> 从历史角度上看，它们依次出现的顺序是进程、线程和协程。在还没有进程抽象的早期操作系统中，计算机科学家把程序在计算机上的一次执行过程称为一个任务（Task）或一个工作（Job），其特点是任务和工作在其整个的执行过程中，不会被切换。这样其他任务必须等待一个任务结束后，才能执行，这样系统的效率会比较低。
> 在引入面向 CPU 的分时切换机制和面向内存的虚拟内存机制后，进程的概念就被提出了，进程成为 CPU（也称处理器）调度（Scheduling）和分派（Switch）的对象，各个进程间以时间片为单位轮流使用 CPU，且每个进程有各自独立的一块内存，使得各个进程之间内存地址相互隔离。这时，操作系统通过进程这个抽象来完成对应用程序在 CPU 和内存使用上的管理。
> 随着计算机的发展，对计算机系统性能的要求越来越高，而进程之间的切换开销相对较大，于是计算机科学家就提出了线程。线程是程序执行中一个单一的顺序控制流程，线程是进程的一部分，一个进程可以包含一个或多个线程。各个线程之间共享进程的地址空间，但线程要有自己独立的栈（用于函数访问，局部变量等）和独立的控制流。且线程是处理器调度和分派的基本单位。对于线程的调度和管理，可以在操作系统层面完成，也可以在用户态的线程库中完成。用户态线程也称为绿色线程（GreenThread）。如果是在用户态的线程库中完成，操作系统是“看不到”这样的线程的，也就谈不上对这样线程的管理了。
> 协程（Coroutines，也称纤程（Fiber）），也是程序执行中一个单一的顺序控制流程，建立在线程之上（即一个线程上可以有多个协程），但又是比线程更加轻量级的处理器调度对象。协程一般是由用户态的协程管理库来进行管理和调度，这样操作系统是看不到协程的。而且多个协程共享同一线程的栈，这样协程在时间和空间的管理开销上，相对于线程又有很大的改善。在具体实现上，协程可以在用户态运行时库这一层面通过函数调用来实现；也可在语言级支持协程，比如 Rust 借鉴自其他语言的的 `async` 、 `await` 关键字等，通过编译器和运行时库二者配合来简化程序员编程的负担并提高整体的性能。


### fork 系统调用
在内核初始化完毕之后会创建一个进程——即 **用户初始进程** (Initial Process) ，它是目前在内核中以硬编码方式创建的唯一一个进程。其他所有的进程都是通过一个名为 `fork` 的系统调用来创建的。
```rust
/// 功能：当前进程 fork 出来一个子进程。
/// 返回值：对于子进程返回 0，对于当前进程则返回子进程的 PID 。
/// syscall ID：220
pub fn sys_fork() -> isize;
```
进程 A 调用 `fork` 系统调用之后，内核会创建一个新进程 B，这个进程 B 和调用 `fork` 的进程 A 在它们分别返回用户态那一瞬间几乎处于相同的状态：这意味着它们包含的用户态的代码段、堆栈段及其他数据段的内容完全相同，但是它们是被放在两个独立的地址空间中的。因此新进程的地址空间需要从原有进程的地址空间完整拷贝一份。两个进程通用寄存器也几乎完全相同。例如， pc 相同意味着两个进程会从同一位置的一条相同指令（我们知道其上一条指令一定是用于系统调用的 ecall 指令）开始向下执行， sp 相同则意味着两个进程的用户栈在各自的地址空间中的位置相同。其余的寄存器相同则确保了二者回到了相同的控制流状态。
但是唯有用来保存 `fork` 系统调用返回值的 a0 寄存器（这是 RISC-V 64 的函数调用规范规定的函数返回值所用的寄存器）的值是不同的。

### waitpid 系统调用
```rust
/// 功能：当前进程等待一个子进程变为僵尸进程，回收其全部资源并收集其返回值。
/// 参数：pid 表示要等待的子进程的进程 ID，如果为 -1 的话表示等待任意一个子进程；
/// exit_code 表示保存子进程返回值的地址，如果这个地址为 0 的话表示不必保存。
/// 返回值：如果要等待的子进程不存在则返回 -1；否则如果要等待的子进程均未结束则返回 -2；
/// 否则返回结束的子进程的进程 ID。
/// syscall ID：260
pub fn sys_waitpid(pid: isize, exit_code: *mut i32) -> isize;
```
一般情况下一个进程要负责通过 `waitpid` 系统调用来等待它 `fork` 出来的子进程结束并回收掉它们占据的资源，这也是父子进程间的一种同步手段。但这并不是必须的。如果一个进程先于它的子进程结束，在它退出的时候，它的所有子进程将成为进程树的根节点——用户初始进程的子进程，同时这些子进程的父进程也会转成用户初始进程。这之后，这些子进程的资源就由用户初始进程负责回收了，这也是用户初始进程很重要的一个用途。后面我们会介绍用户初始进程是如何实现的.

### [exec 系统调用]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter5/1process.html#exec "永久链接至标题")
如果仅有 `fork` 的话，那么所有的进程都只能和用户初始进程一样执行同样的代码段，这显然是远远不够的。于是我们还需要引入 `exec` 系统调用来执行不同的可执行文件：

```rust
/// 功能：将当前进程的地址空间清空并加载一个特定的可执行文件，返回用户态后开始它的执行。
/// 参数：path 给出了要加载的可执行文件的名字；
/// 返回值：如果出错的话（如找不到名字相符的可执行文件）则返回 -1，否则不应该返回。
/// syscall ID：221
pub fn sys_exec(path: &str) -> isize;
```

注意，我们知道 `path` 作为 `&str` 类型是一个胖指针，既有起始地址又包含长度信息。在实际进行系统调用的时候，我们只会将起始地址传给内核（对标 C 语言仅会传入一个 `char*` ）。这就需要应用负责在传入的字符串的末尾加上一个 `\0` ，这样内核才能知道字符串的长度。下面给出了用户库 `user_lib` 中的调用方式：

>**为何创建进程要通过两个系统调用而不是一个？**
>同学可能会有疑问，对于要达成执行不同应用的目标，我们为什么不设计一个系统调用接口同时实现创建一个新进程并加载给定的可执行文件两种功能？如果使用 `fork` 和 `exec` 的组合，那么 `fork` 出来的进程仅仅是为了 `exec` 一个新应用提供空间。而执行 `fork` 中对父进程的地址空间拷贝没有用处，还浪费了时间，且在后续清空地址空间的时候还会产生一些资源回收的额外开销。这样的设计来源于早期的 MULTICS [1](http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter5/1process.html#multics) 和 UNIX 操作系统 [2](http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter5/1process.html#unix) ，在当时是经过实践考验的，事实上 `fork` 和 `exec` 是一种灵活的系统调用组合，在当时内存空间比较小的情况下，可以支持更快的进程创建，且上述的开销能够通过一些结合虚存的技术方法（如 _Copy on write_ 等）来缓解。而且拆分为两个系统调用后，可以灵活地支持 **重定向** (Redirection) 等功能。上述方法是 UNIX 类操作系统的典型做法。
>这一点与 Windows 操作系统不一样。在 Windows 中， `CreateProcess` 函数用来创建一个新的进程和它的主线程，通过这个新进程运行指定的可执行文件。虽然是一个函数，但这个函数的参数十个之多，使得这个函数很复杂，且没有 `fork` 和 `exec` 的组合的灵活性。而基于 POSIX 标准的 `posix_spawn` 系统调用则类似 Windows 的 `CreateProcess` 函数，不过对参数进行了简化，更适合现在的计算机系统（有更大的物理内存空间）和类 UNIX 应用程序 (更加复杂的软件)。


### Read

```rust
/// 功能：从文件中读取一段内容到缓冲区。
/// 参数：fd 是待读取文件的文件描述符，切片 buffer 则给出缓冲区。
/// 返回值：如果出现了错误则返回 -1，否则返回实际读到的字节数。
/// syscall ID：63
pub fn sys_read(fd: usize, buffer: &mut [u8]) -> isize;
```

### [进程标识符]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter5/2core-data-structures.html#id7 "永久链接至标题")

同一时间存在的所有进程都有一个唯一的进程标识符，它们是互不相同的整数，这样才能表示表示进程的唯一性。这里我们使用 RAII 的思想，将其抽象为一个 `PidHandle` 类型，当它的生命周期结束后对应的整数会被编译器自动回收：


## TCB

在内核中，每个进程的执行状态、资源控制等元数据均保存在一个被称为 **进程控制块** (PCB, Process Control Block) 的结构中，它是内核对进程进行管理的单位，故而是一种极其关键的内核数据结构。在内核看来，它就等价于一个进程。

承接前面的章节，我们仅需对任务控制块 `TaskControlBlock` 进行若干改动并让它直接承担进程控制块的功能：
```rust
// os/src/task/task.rs
 
 pub struct TaskControlBlock {
     // immutable
     pub pid: PidHandle,
     pub kernel_stack: KernelStack,
     // mutable
     inner: UPSafeCell<TaskControlBlockInner>,
 }

pub struct TaskControlBlockInner {
    pub trap_cx_ppn: PhysPageNum,
    pub base_size: usize,
    pub task_cx: TaskContext,
    pub task_status: TaskStatus,
    pub memory_set: MemorySet,
    pub parent: Option<Weak<TaskControlBlock>>,
    pub children: Vec<Arc<TaskControlBlock>>,
    pub exit_code: i32,
}
```
任务控制块中包含两部分：

-   在初始化之后就不再变化的元数据：直接放在任务控制块中。这里将进程标识符 `PidHandle` 和内核栈 `KernelStack` 放在其中；
    
-   在运行过程中可能发生变化的元数据：则放在 `TaskControlBlockInner` 中，将它再包裹上一层 `UPSafeCell<T>` 放在任务控制块中。这是因为在我们的设计中外层只能获取任务控制块的不可变引用，若想修改里面的部分内容的话这需要 `UPSafeCell<T>` 所提供的内部可变性。
    

`TaskControlBlockInner` 中则包含下面这些内容：

-   `trap_cx_ppn` 指出了应用地址空间中的 Trap 上下文（详见第四章）被放在的物理页帧的物理页号。
    
-   `base_size` 的含义是：应用数据仅有可能出现在应用地址空间低于 `base_size` 字节的区域中。借助它我们可以清楚的知道应用有多少数据驻留在内存中。
    
-   `task_cx` 将暂停的任务的任务上下文保存在任务控制块中。
    
-   `task_status` 维护当前进程的执行状态。
    
-   `memory_set` 表示应用地址空间。
    
-   `parent` 指向当前进程的父进程（如果存在的话）。注意我们使用 `Weak` 而非 `Arc` 来包裹另一个任务控制块，因此这个智能指针将不会影响父进程的引用计数。
    
-   `children` 则将当前进程的所有子进程的任务控制块以 `Arc` 智能指针的形式保存在一个向量中，这样才能够更方便的找到它们。
    
-   当进程调用 exit 系统调用主动退出或者执行出错由内核终止的时候，它的退出码 `exit_code` 会被内核保存在它的任务控制块中，并等待它的父进程通过 waitpid 回收它的资源的同时也收集它的 PID 以及退出码。
    

注意我们在维护父子进程关系的时候大量用到了引用计数 `Arc/Weak` 。进程控制块的本体是被放到内核堆上面的，对于它的一切访问都是通过智能指针 `Arc/Weak` 来进行的，这样是便于建立父子进程的双向链接关系（避免仅基于 `Arc` 形成环状链接关系）。当且仅当智能指针 `Arc` 的引用计数变为 0 的时候，进程控制块以及被绑定到它上面的各类资源才会被回收。子进程的进程控制块并不会被直接放到父进程控制块中，因为子进程完全有可能在父进程退出后仍然存在。


### fork 系统调用的实现[]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter5/3implement-process-mechanism.html#fork "永久链接至标题")

在实现 fork 的时候，最为关键且困难的是为子进程创建一个和父进程几乎完全相同的应用地址空间。

我们在子进程内核栈上压入一个初始化的任务上下文，使得内核一旦通过任务切换到该进程，就会跳转到 `trap_return` 来进入用户态。而在复制地址空间的时候，子进程的 Trap 上下文也是完全从父进程复制过来的，这可以保证子进程进入用户态和其父进程回到用户态的那一瞬间 CPU 的状态是完全相同的（后面我们会让它们的返回值不同从而区分两个进程）。而两个进程的应用数据由于地址空间复制的原因也是完全相同的，这是 fork 语义要求做到的。

### exec 系统调用的实现[]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter5/3implement-process-mechanism.html#exec "永久链接至标题")

`exec` 系统调用使得一个进程能够加载一个新应用的 ELF 可执行文件中的代码和数据替换原有的应用地址空间中的内容，并开始执行。

它在解析传入的 ELF 格式数据之后只做了两件事情：

-   首先是从 ELF 文件生成一个全新的地址空间并直接替换进来（第 15 行），这将导致原有的地址空间生命周期结束，里面包含的全部物理页帧都会被回收；
    
-   然后是修改新的地址空间中的 Trap 上下文，将解析得到的应用入口点、用户栈位置以及一些内核的信息进行初始化，这样才能正常实现 Trap 机制。
    

这里无需对任务上下文进行处理，因为这个进程本身已经在执行了，而**只有被暂停的应用才需要在内核栈上保留一个任务上下文。**

