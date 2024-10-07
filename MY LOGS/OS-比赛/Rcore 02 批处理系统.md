

# 特权级机制[]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/1rv-privilege.html#id1 "永久链接至标题")
## 本节导读
为了保护我们的批处理操作系统不受到出错应用程序的影响并全程稳定工作，单凭软件实现是很难做到的，而是需要 CPU 提供一种特权级隔离机制，使 CPU 在执行应用程序和操作系统内核的指令时处于不同的特权级。本节主要介绍了特权级机制的软硬件设计思路，以及 RISC-V 的特权级架构，包括特权指令的描述.
## 特权级的软硬件协同设计
> 为了让应用程序获得操作系统的函数服务，采用传统的函数调用方式（即通常的 `call` 和 `ret` 指令或指令组合）将会直接绕过硬件的特权级保护检查。所以可以设计新的机器指令：执行环境调用（Execution Environment Call，简称 `ecall` ）和执行环境返回 (Execution Environment Return，简称 `eret` )）：
-   `ecall` ：具有用户态到内核态的执行环境切换能力的函数调用指令    
-   `eret` ：具有内核态到用户态的执行环境切换能力的函数返回指令

硬件具有了这样的机制后，还需要操作系统的配合才能最终完成对操作系统自身的保护。首先，操作系统需要提供相应的功能代码，能在执行 `eret` 前准备和恢复用户态执行应用程序的上下文。其次，在应用程序调用 `ecall` 指令后，能够检查应用程序的系统调用参数，确保参数不会破坏操作系统。
### RISC-V 特权级架构[]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/1rv-privilege.html#risc-v "永久链接至标题")
RISC-V 架构中一共定义了 4 种特权级：
![[Pasted image 20230427213552.png]]
其中，级别的数值越大，特权级越高，掌控硬件的能力越强。从表中可以看出， M 模式处在最高的特权级，而 U 模式处于最低的特权级。在 CPU 硬件层面，除了 M 模式必须存在外，其它模式可以不存在。
其中操作系统内核代码运行在 S 模式上；应用程序运行在 U 模式上。运行在 M 模式上的软件被称为 **监督模式执行环境** (SEE, Supervisor Execution Environment)，如在操作系统运行前负责加载操作系统的 Bootloader – RustSBI。站在运行在 S 模式上的软件视角来看，它的下面也需要一层执行环境支撑，因此被命名为 SEE，它需要在相比 S 模式更高的特权级下运行，一般情况下 SEE 在 M 模式上运行。
![[Pasted image 20230427213732.png]]
执行环境的功能之一是在执行它支持的上层软件之前进行一些初始化工作。我们之前提到的引导加载程序会在加电后对整个系统进行初始化，它实际上是 SEE 功能的一部分，也就是说在 RISC-V 架构上的引导加载程序一般运行在 M 模式上。此外，编程语言相关的标准库也会在执行应用程序员编写的应用程序之前进行一些初始化工作。但在这张图中我们并没有将应用程序的执行环境详细展开，而是统一归类到 U 模式软件，也就是应用程序中。
### RISC-V 的特权指令[]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/1rv-privilege.html#term-csr-instr "永久链接至标题")
与特权级无关的一般的指令和通用寄存器 `x0` ~ `x31` 在任何特权级都可以执行。而每个特权级都对应一些特殊指令和 **控制状态寄存器** (CSR, Control and Status Register) ，来控制该特权级的某些行为并描述其状态。当然特权指令不仅具有读写 CSR 的指令，还有其他功能的特权指令。
如果处于低特权级状态的处理器执行了高特权级的指令，会产生非法指令错误的异常。这样，位于高特权级的执行环境能够得知低特权级的软件出现了错误，这个错误一般是不可恢复的，此时执行环境会将低特权级的软件终止。这在某种程度上体现了特权级保护机制的作用。
在 RISC-V 中，会有两类属于高特权级 S 模式的特权指令：
-   指令本身属于高特权级的指令，如 `sret` 指令（表示从 S 模式返回到 U 模式）。
    
-   指令访问了 [S模式特权级下才能访问的寄存器](http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/4trap-handling.html#term-s-mod-csr) 或内存，如表示 S 模式系统状态的 **控制状态寄存器** `sstatus` 等。
![[Pasted image 20230427214025.png]]

#  实现应用程序[]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/2application.html#id1 "永久链接至标题")

## 本节导读
本节主要讲解如何设计实现被批处理系统逐个加载并运行的应用程序。这有个前提，即应用程序假定在*用户态（U 特权级模式*下运行。实际上，如果应用程序的代码都符合用户态特权级的约束，那它完全可以正常在用户态中运行；但如果应用程序*执行特权指令或非法操作（如执行非法指令，访问一个非法的地址等），那会产生异常*，并导致程序退出。保证应用程序的代码在用户态能正常运行是将要实现的批处理系统的关键任务之一。应用程序的设计实现要点是：

-   应用程序的*内存布局*
-   应用程序发出的*系统调用*

从某种程度上讲，这里设计的应用程序与第一章中的*最小用户态执行环境*有很多相同的地方。即*设计一个应用程序和基本的支持功能库*，这样应用程序在用户态通过操作系统提供的服务完成自身的任务。


### 内存布局[]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/2application.html#term-app-mem-layout "永久链接至标题")

在 `user/.cargo/config` 中，我们和第一章一样设置链接时使用链接脚本 `user/src/linker.ld` 。在其中我们做的重要的事情是：

-   将程序的起始物理地址调整为 `0x80400000` ，三个应用程序都会被加载到这个物理地址上运行；
    
-   将 `_start` 所在的 `.text.entry` 放在整个程序的开头，也就是说批处理系统只要在加载之后跳转到 `0x80400000` 就已经进入了 用户库的入口点，并会在初始化之后跳转到应用程序主逻辑；
    
-   提供了最终生成可执行文件的 `.bss` 段的起始和终止地址，方便 `clear_bss` 函数使用。
    

其余的部分和第一章基本相同。

### 系统调用[](http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/2application.html#term-call-syscall "永久链接至标题")

在子模块 `syscall` 中，应用程序通过 `ecall` 调用批处理系统提供的接口，由于应用程序运行在用户态（即 U 模式）， `ecall` 指令会触发 名为 _Environment call from U-mode_ 的异常，并 Trap 进入 S 模式执行批处理系统针对这个异常特别提供的服务代码。由于这个接口处于 S 模式的批处理系统和 U 模式的应用程序之间，从上一节我们可以知道，这个接口可以被称为 ABI 或者系统调用。现在我们不关心底层的批处理系统如何提供应用程序所需的功能，只是站在应用程序的角度去使用即可。

在本章中，应用程序和批处理系统之间按照 API 的结构，约定如下两个系统调用：

>我们知道系统调用实际上是汇编指令级的二进制接口，因此这里给出的只是使用 Rust 语言描述的 API 版本。在实际调用的时候，我们需要按照 RISC-V 调用规范（即 ABI 格式）在合适的寄存器中放置系统调用的参数，然后执行 `ecall` 指令触发 Trap。在 Trap 回到 U 模式的应用程序代码之后，会从 `ecall` 的下一条指令继续执行，同时我们能够按照调用规范在合适的寄存器中读取返回值。

**RISC-V 寄存器编号和别名**
#RISC-V 寄存器编号从 `0~31` ，表示为 `x0~x31` 。其中：
-   `x10~x17` : 对应 `a0~a7`
    
-   `x1` ：对应 `ra`

在 RISC-V 调用规范中，和函数调用的 ABI 情形类似，约定寄存器 `a0~a6` 保存系统调用的参数， `a0` 保存系统调用的返回值。有些许不同的是寄存器 `a7` 用来传递 syscall ID，这是因为所有的 syscall 都是通过 `ecall` 指令触发的，除了各输入参数之外我们还额外需要一个寄存器来保存要请求哪个系统调用。由于这超出了 Rust 语言的表达能力，我们需要在代码中使用内嵌汇编来完成参数/返回值绑定和 `ecall` 指令的插入：
```RUST
fn syscall(id: usize, args: [usize; 3]) -> isize {

    let mut ret: isize;

    unsafe {

        asm!(

            "ecall",

            inlateout("x10") args[0] => ret,

            in("x11") args[1],

            in("x12") args[2],

            in("x17") id

        );

    }

    ret

}
```
`syscall` 中使用从第 5 行开始的 `asm!` 宏嵌入 `ecall` 指令来触发系统调用。在第一章中，我们曾经使用 `global_asm!` 宏来嵌入全局汇编代码，而这里的 `asm!` 宏可以将汇编代码嵌入到局部的函数上下文中。相比 `global_asm!` ， `asm!` 宏可以获取上下文中的变量信息并允许嵌入的汇编代码对这些变量进行操作。由于编译器的能力不足以判定插入汇编代码这个行为的安全性，所以我们需要将其包裹在 unsafe 块中自己来对它负责。
从 RISC-V 调用规范来看，就像函数有着输入参数和返回值一样， `ecall` 指令同样有着输入和输出寄存器： `a0~a2` 和 `a7` 作为输入寄存器分别表示系统调用参数和系统调用 ID ，而当系统调用返回后， `a0` 作为输出寄存器保存系统调用的返回值。在函数上下文中，输入参数数组 `args` 和变量 `id` 保存系统调用参数和系统调用 ID ，而变量 `ret` 保存系统调用返回值，它也是函数 `syscall` 的输出/返回值。这些输入/输出变量可以和 `ecall` 指令的输入/输出寄存器一一对应。如果完全由我们自己编写汇编代码，那么如何将变量绑定到寄存器则成了一个难题：比如，在 `ecall` 指令被执行之前，我们需要将寄存器 `a7` 的值设置为变量 `id` 的值，那么我们首先需要知道目前变量 `id` 的值保存在哪里，它可能在栈上也有可能在某个寄存器中。

作为程序员我们并不知道这些只有编译器才知道的信息，因此我们只能在编译器的帮助下完成变量到寄存器的绑定。现在来看 `asm!` 宏的格式：首先在第 6 行是我们要插入的汇编代码段本身，这里我们只插入一行 `ecall` 指令，不过它可以支持同时插入多条指令。从第 7 行开始我们在编译器的帮助下将输入/输出变量绑定到寄存器。比如第 8 行的 `in("x11") args[1]` 则表示将输入参数 `args[1]` 绑定到 `ecall` 的输入寄存器 `x11` 即 `a1` 中，编译器自动插入相关指令并保证在 `ecall` 指令被执行之前寄存器 `a1` 的值与 `args[1]` 相同。以同样的方式我们可以将输入参数 `args[2]` 和 `id` 分别绑定到输入寄存器 `a2` 和 `a7` 中。这里比较特殊的是 `a0` 寄存器，它同时作为输入和输出，因此我们将 `in` 改成 `inlateout` ，并在行末的变量部分使用 `{in_var} => {out_var}` 的格式，其中 `{in_var}` 和 `{out_var}` 分别表示上下文中的输入变量和输出变量。

有些时候不必将变量绑定到固定的寄存器，此时 `asm!` 宏可以自动完成寄存器分配。某些汇编代码段还会带来一些编译器无法预知的副作用，这种情况下需要在 `asm!` 中通过 `options` 告知编译器这些可能的副作用，这样可以帮助编译器在避免出错更加高效分配寄存器。事实上， `asm!` 宏远比我们这里介绍的更加强大易用，详情参考 Rust 相关 RFC 文档 [1](http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/2application.html#rust-asm-macro-rfc) 。

上面这一段汇编代码的含义和内容与 [第一章中的 RustSBI 输出到屏幕的 SBI 调用汇编代码](http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter1/6print-and-shutdown-based-on-sbi.html#term-llvm-sbicall) 涉及的汇编指令一样，但传递参数的寄存器的含义是不同的。有兴趣的同学可以回顾第一章的 `console.rs` 和 `sbi.rs` 。

**Qemu 的用户态模拟和系统级模拟**

Qemu 有两种运行模式：用户态模拟（User mode）和系统级模拟（System mode）。在 RISC-V 架构中，用户态模拟可使用 `qemu-riscv64` 模拟器，它可以模拟一台预装了 Linux 操作系统的 RISC-V 计算机。但是一般情况下我们并不通过输入命令来与之交互（就像我们正常使用 Linux 操作系统一样），它仅支持载入并执行单个可执行文件。具体来说，它可以解析基于 RISC-V 的应用级 ELF 可执行文件，加载到内存并跳转到入口点开始执行。在翻译并执行指令时，如果碰到是系统调用相关的汇编指令，它会把不同处理器（如 RISC-V）的 Linux 系统调用转换为本机处理器（如 x86-64）上的 Linux 系统调用，这样就可以让本机 Linux 完成系统调用，并返回结果（再转换成 RISC-V 能识别的数据）给这些应用。相对的，我们使用 `qemu-system-riscv64` 模拟器来系统级模拟一台 RISC-V 64 裸机，它包含处理器、内存及其他外部设备，支持运行完整的操作系统。


# 实现批处理操作系统[]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/3batch-system.html#term-batchos "永久链接至标题")

## 本节导读[](http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/3batch-system.html#id2 "永久链接至标题")

从本节开始我们将着手实现批处理操作系统——即泥盆纪“邓式鱼”操作系统。在批处理操作系统中，每当一个应用执行完毕，我们都需要将下一个要执行的应用的代码和数据加载到内存。在具体实现其批处理执行应用程序功能之前，本节我们首先实现该应用加载机制，也即：在操作系统和应用程序需要被放置到同一个可执行文件的前提下，设计一种尽量简洁的应用放置和加载方式，使得操作系统容易找到应用被放置到的位置，从而在批处理操作系统和应用程序之间建立起联系的纽带。具体而言，应用放置采用“静态绑定”的方式，而操作系统加载应用则采用“动态加载”的方式：

-   静态绑定：通过一定的编程技巧，把多个应用程序代码和批处理操作系统代码“绑定”在一起。
    
-   动态加载：基于静态编码留下的“绑定”信息，操作系统可以找到每个应用程序文件二进制代码的起始地址和长度，并能加载到内存中运行。
    

这里与硬件相关且比较困难的地方是如何让在内核态的批处理操作系统启动应用程序，且能让应用程序在用户态正常执行。本节会讲大致过程，而具体细节将放到下一节具体讲解。

## 找到并加载应用程序二进制码[]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/3batch-system.html#id4 "永久链接至标题")
能够找到并加载应用程序二进制码的应用管理器 `AppManager` 是“邓式鱼”操作系统的核心组件。我们在 `os` 的 `batch` 子模块中实现一个应用管理器，它的主要功能是：
-   保存应用数量和各自的位置信息，以及当前执行到第几个应用了。
-   根据应用程序位置信息，初始化好应用所需内存空间，并加载应用执行。

>**Rust Tips：Rust 所有权模型和借用检查**
  我们这里简单介绍一下 Rust 的所有权模型。它可以用一句话来概括： **值** （Value）在同一时间只能被绑定到一个 **变量** （Variable）上。这里，“值”指的是储存在内存中固定位置，且格式属于某种特定类型的数据；而变量就是我们在 Rust 代码中通过 `let` 声明的局部变量或者函数的参数等，变量的类型与值的类型相匹配。在这种情况下，我们称值的 **所有权** （Ownership）属于它被绑定到的变量，且变量可以作为访问/控制绑定到它上面的值的一个媒介。变量可以将它拥有的值的所有权转移给其他变量，或者当变量退出其作用域之后，它拥有的值也会被销毁，这意味着值占用的内存或其他资源会被回收。
  有些场景下，特别是在函数调用的时候，我们并不希望将当前上下文中的值的所有权转移到其他上下文中，因此类似于 C/C++ 中的按引用传参， Rust 可以使用 `&` 或 `&mut` 后面加上值被绑定到的变量的名字来分别生成值的不可变引用和可变引用，我们称这些引用分别不可变/可变 **借用** (Borrow) 它们引用的值。顾名思义，我们可以通过可变引用来修改它借用的值，但通过不可变引用则只能读取而不能修改。这些引用同样是需要被绑定到变量上的值，只是它们的类型是引用类型。在 Rust 中，引用类型的使用需要被编译器检查，但在数据表达上，和 C 的指针一样它只记录它借用的值所在的地址，因此在内存中它随平台不同仅会占据 4 字节或 8 字节空间。
  无论值的类型是否是引用类型，我们都定义值的 **生存期** （Lifetime）为代码执行期间该值必须持续合法的代码区域集合（见 [1](http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/3batch-system.html#rust-nomicon-lifetime) ），大概可以理解为该值在代码中的哪些地方被用到了：简单情况下，它可能等同于拥有它的变量的作用域，也有可能是从它被绑定开始直到它的拥有者变量最后一次出现或是它被解绑。
  当我们使用 `&` 和 `&mut` 来借用值的时候，则我们编写的代码必须满足某些约束条件，不然无法通过编译：
    -  不可变/可变引用的生存期不能 **超出** （Outlive）它们借用的值的生存期，也即：前者必须是后者的子集；
    -   同一时间，借用同一个值的不可变和可变引用不能共存；
    -   同一时间，借用同一个值的不可变引用可以存在多个，但可变引用只能存在一个。
  这是为了 Rust 内存安全而设计的重要约束条件。第一条很好理解，如果值的生存期未能完全覆盖借用它的引用的生存期，就会在某一时刻发生值已被销毁而我们仍然尝试通过引用来访问该值的情形。反过来说，显然当值合法时引用才有意义。最典型的例子是 **悬垂指针** （Dangling Pointer）问题：即我们尝试在一个函数中返回函数中声明的局部变量的引用，并在调用者函数中试图通过该引用访问已被销毁的局部变量，这会产生未定义行为并导致错误。第二、三条的主要目的则是为了避免通过多个引用对同一个值进行的读写操作产生冲突。例如，当对同一个值的读操作和写操作在时间上相互交错时（即不可变/可变引用的生存期部分重叠），读操作便有可能读到被修改到一半的值，通常这会是一个不合法的值从而导致程序无法正确运行。这可能是由于我们在编程上的疏忽，使得我们在读取一个值的时候忘记它目前正处在被修改到一半的状态，一个可能的例子是在 C++ 中正对容器进行迭代访问的时候修改了容器本身。也有可能被归结为 **别名** （Aliasing）问题，例如在 C 函数中有两个指针参数，如果它们指向相同的地址且编译器没有注意到这一点就进行过激的优化，将会使得编译结果偏离我们期望的语义。
  上述约束条件要求借用同一个值的不可变引用和不可变/可变引用的生存期相互隔离，从而能够解决这些问题。Rust 编译器会在编译时使用 **借用检查器** （Borrow Checker）检查这些约束条件是否被满足：其具体做法是尽可能精确的估计引用和值的生存期并将它们进行比较。随着 Rust 语言的愈发完善，其估计的精确度也会越来越高，使得程序员能够更容易通过借用检查。引用相关的借用检查发生在编译期，因此我们可以称其为编译期借用检查。
  相对的，对值的借用方式运行时可变的情况下，我们可以使用 Rust 内置的数据结构将借用检查推迟到运行时，这可以称为运行时借用检查，它的约束条件和编译期借用检查一致。当我们想要发起借用或终止借用时，只需调用对应数据结构提供的接口即可。值的借用状态会占用一部分额外内存，运行时还会有额外的代码对借用合法性进行检查，这是为满足借用方式的灵活性产生的必要开销。当无法通过借用检查时，将会产生一个不可恢复错误，导致程序打印错误信息并立即退出。具体来说，我们通常使用 `RefCell` 包裹可被借用的值，随后调用 `borrow` 和 `borrow_mut` 便可发起借用并获得一个对值的不可变/可变借用的标志，它们可以像引用一样使用。为了终止借用，我们只需手动销毁这些标志或者等待它们被自动销毁。 `RefCell` 的详细用法请参考 [2](http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/3batch-system.html#rust-refcell) 。
 
应用管理器需要保存和维护的信息都在 `AppManager` 里面。这样设计的原因在于：我们希望将 `AppManager` 实例化为一个全局变量，使得任何函数都可以直接访问。但是里面的 `current_app` 字段表示当前执行的是第几个应用，它是一个可修改的变量，会在系统运行期间发生变化。因此在声明全局变量的时候，采用 `static mut` 是一种比较简单自然的方法。但是在 Rust 中，任何对于 `static mut` 变量的访问控制都是 unsafe 的，而我们要在编程中尽量避免使用 unsafe ，这样才能让编译器负责更多的安全性检查。因此，我们需要考虑如何在尽量避免触及 unsafe 的情况下仍能声明并使用可变的全局变量。
如果单独使用 `static` 而去掉 `mut` 的话，我们可以声明一个初始化之后就不可变的全局变量，但是我们需要 `AppManager` 里面的内容在运行时发生变化。这涉及到 Rust 中的 **内部可变性** （Interior Mutability），也即在变量自身不可变或仅在不可变借用的情况下仍能修改绑定到变量上的值。我们可以通过用上面提到的 `RefCell` 来包裹 `AppManager` ，这样 `RefCell` 无需被声明为 `mut` ，同时被包裹的 `AppManager` 也能被修改。但是，我们能否将 `RefCell` 声明为一个全局变量呢？让我们写一小段代码试一试：
```Rust
// https://play.rust-lang.org/?version=stable&mode=debug&edition=2021&gist=18b0f956b83e6a8a408215edcfcb6d01
use std::cell::RefCell;
static A: RefCell<i32> = RefCell::new(3);
fn main() {
    *A.borrow_mut() = 4;
    println!("{}", A.borrow());
}
```

Rust 编译器提示我们 `RefCell<i32>` 未被标记为 `Sync` ，因此 Rust 编译器认为它不能被安全的在线程间共享，也就不能作为全局变量使用。这可能会令人迷惑，这只是一个单线程程序，因此它不会有任何线程间共享数据的行为，为什么不能通过编译呢？事实上，Rust 对于并发安全的检查较为粗糙，当声明一个全局变量的时候，编译器会默认程序员会在多线程上使用它，而并不会检查程序员是否真的这样做。如果一个变量实际上仅会在单线程上使用，那 Rust 会期待我们将变量分配在栈上作为局部变量而不是全局变量。目前我们的内核仅支持单核，也就意味着只有单线程，那么我们可不可以使用局部变量来绕过这个错误呢？
#Rust多线程
很可惜，在这里和后面章节的很多场景中，有些变量无法作为局部变量使用。这是因为后面内核会*并发执行多条控制流*-->**进程**，这些控制流都会用到这些变量。如果我们最初将变量*分配在某条控制流的栈上*，那么我们就需要考虑如何将变量传递到其他控制流上，由于控制流的切换等操作并非常规的函数调用，我们很难将变量传递出去。*因此最方便的做法是使用全局变量，这意味着在程序的任何地方均可随意访问它们，自然也包括这些控制流*。

除了 `Sync` 的问题之外，看起来 `RefCell` 已经非常接近我们的需求了，因此我们在 `RefCell` 的基础上再封装一个 `UPSafeCell` ，它名字的含义是：允许我们在 _单核_ 上安全使用可变全局变量。

> `lazy_static!` 宏提供了全局变量的运行时初始化功能。一般情况下，全局变量必须在编译期设置一个初始值，但是有些全局变量依赖于运行期间才能得到的数据作为初始值。这导致这些全局变量需要在运行时发生变化，即需要重新设置初始值之后才能使用。如果我们手动实现的话有诸多不便之处，比如需要把这种全局变量声明为 `static mut` 并衍生出很多 unsafe 代码。这种情况下我们可以使用 `lazy_static!` 宏来帮助我们解决这个问题。这里我们借助 `lazy_static!` 声明了一个 `AppManager` 结构的名为 `APP_MANAGER` 的全局实例，且只有在它第一次被使用到的时候，才会进行实际的初始化工作。



# 特权级切换
在 RISC-V 架构中，关于 Trap 有一条重要的规则：在 Trap 前的特权级不会高于 Trap 后的特权级。因此如果触发 Trap 之后切换到 S 特权级（下称 Trap 到 S），说明 Trap 发生之前 CPU 只能运行在 S/U 特权级。但无论如何，只要是 Trap 到 S 特权级，操作系统就会使用 S 特权级中与 Trap 相关的 **控制状态寄存器** (CSR, Control and Status Register) 来辅助 Trap 处理。我们在编写运行在 S 特权级的批处理操作系统中的 Trap 处理相关代码的时候，就需要使用如下所示的 S 模式的 CSR 寄存器。
<table class="colwidths-given docutils align-center" id="id12" style="display: block; margin-left: auto; margin-right: auto; text-align: center; border-collapse: collapse; border-radius: 0.2rem; border-spacing: 0px; box-shadow: rgba (0, 0, 0, 0.05) 0px 0.2rem 0.5rem, rgba (0, 0, 0, 0.1) 0px 0px 0.0625rem; color: rgb (0, 0, 0); font-family: -apple-system, BlinkMacSystemFont, &quot; Segoe UI&quot;, Helvetica, Arial, sans-serif, &quot; Apple Color Emoji&quot;, &quot; Segoe UI Emoji&quot;; font-size: medium; background-color: rgb (255, 255, 255);"><thead><tr class="row-odd"><th class="head" style="background: var (--color-table-header-background); border-bottom: 1px solid var (--color-table-border); border-left: none; border-right: 1px solid var (--color-table-border); padding: 0px 0.25rem;"><p style="margin: 0.25rem;">CSR 名</p></th><th class="head" style="background: var (--color-table-header-background); border-bottom: 1px solid var (--color-table-border); border-left: 1px solid var (--color-table-border); border-right: none; padding: 0px 0.25rem;"><p style="margin: 0.25rem;">该 CSR 与 Trap 相关的功能</p></th></tr></thead><tbody><tr class="row-even"><td style="border-bottom: 1px solid var (--color-table-border); border-left: none; border-right: 1px solid var (--color-table-border); padding: 0px 0.25rem;"><p style="margin: 0.25rem;">sstatus</p></td><td style="border-bottom: 1px solid var (--color-table-border); border-left: 1px solid var (--color-table-border); border-right: none; padding: 0px 0.25rem;"><p style="margin: 0.25rem;"><code class="docutils literal notranslate" style="font-family: var (--font-stack--monospace); font-size: var (--font-size--small--2); background: var (--color-inline-code-background); border-radius: 0.2em; padding: 0.1em 0.2em; border: 1px solid var (--color-background-border);"><span class="pre">SPP</span></code>&nbsp; 等字段给出 Trap 发生之前 CPU 处在哪个特权级（S/U）等信息</p></td></tr><tr class="row-odd"><td style="border-bottom: 1px solid var (--color-table-border); border-left: none; border-right: 1px solid var (--color-table-border); padding: 0px 0.25rem;"><p style="margin: 0.25rem;">sepc</p></td><td style="border-bottom: 1px solid var (--color-table-border); border-left: 1px solid var (--color-table-border); border-right: none; padding: 0px 0.25rem;"><p style="margin: 0.25rem;">当 Trap 是一个异常的时候，记录 Trap 发生之前执行的最后一条指令的地址</p></td></tr><tr class="row-even"><td style="border-bottom: 1px solid var (--color-table-border); border-left: none; border-right: 1px solid var (--color-table-border); padding: 0px 0.25rem;"><p style="margin: 0.25rem;">scause</p></td><td style="border-bottom: 1px solid var (--color-table-border); border-left: 1px solid var (--color-table-border); border-right: none; padding: 0px 0.25rem;"><p style="margin: 0.25rem;">描述 Trap 的原因</p></td></tr><tr class="row-odd"><td style="border-bottom: 1px solid var (--color-table-border); border-left: none; border-right: 1px solid var (--color-table-border); padding: 0px 0.25rem;"><p style="margin: 0.25rem;">stval</p></td><td style="border-bottom: 1px solid var (--color-table-border); border-left: 1px solid var (--color-table-border); border-right: none; padding: 0px 0.25rem;"><p style="margin: 0.25rem;">给出 Trap 附加信息</p></td></tr><tr class="row-even"><td style="border-bottom: 1px solid var (--color-table-border); border-left: none; border-right: 1px solid var (--color-table-border); padding: 0px 0.25rem;"><p style="margin: 0.25rem;">stvec</p></td><td style="border-bottom: 1px solid var (--color-table-border); border-left: 1px solid var (--color-table-border); border-right: none; padding: 0px 0.25rem;"><p style="margin: 0.25rem;">控制 Trap 处理代码的入口地址</p></td></tr></tbody></table> 
>**S 模式下最重要的 sstatus 寄存器**
>注意 `sstatus` 是 S 特权级最重要的 CSR，可以从多个方面控制 S 特权级的 CPU 行为和执行状态。

## 特权级切换的硬件控制机制
当 CPU 执行完一条指令（如 `ecall` ）并准备从用户特权级 陷入（ `Trap` ）到 S 特权级的时候，硬件会自动完成如下这些事情：
-   `sstatus` 的 `SPP` 字段会被修改为 CPU 当前的特权级（U/S）。
    
-   `sepc` 会被修改为 Trap 处理完成后默认会执行的下一条指令的地址。
    
-   `scause/stval` 分别会被修改成这次 Trap 的原因以及相关的附加信息。
    
-   CPU 会跳转到 `stvec` 所设置的 Trap 处理入口地址，并将当前特权级设置为 S ，然后从 Trap 处理入口地址处开始执行

> **stvec 相关细节**
> 
> 在 RV64 中， `stvec` 是一个 *64* 位的 CSR，在中断使能的情况下，*保存了中断处理的入口地址*。它有两个字段：
> -   MODE 位于 [1:0]，长度为 2 bits；
> -   BASE 位于 [63:2]，长度为 62 bits。
>     
> 当 MODE 字段为 0 的时候， `stvec` 被设置为 Direct 模式，此时进入 S 模式的 Trap 无论原因如何，处理 Trap 的入口地址都是 `BASE<<2` ， CPU 会跳转到这个地方进行异常处理。本书中我们只会将 `stvec` 设置为 Direct 模式。而 `stvec` 还可以被设置为 Vectored 模式，有兴趣的同学可以自行参考 RISC-V 指令集特权级规范。


## 用户栈与内核栈

在 Trap 触发的一瞬间， CPU 就会切换到 S 特权级并跳转到 `stvec` 所指示的位置。但是在正式进入 S 特权级的 Trap 处理之前，上面 提到过我们必须保存原控制流的寄存器状态，这一般通过内核栈来保存。注意，我们需要用专门为操作系统准备的内核栈，而不是应用程序运行时用到的用户栈。

使用两个不同的栈主要是为了安全性：如果两个控制流（即应用程序的控制流和内核的控制流）使用同一个栈，在返回之后应用程序就能读到 Trap 控制流的历史信息，比如内核一些函数的地址，这样会带来安全隐患。于是，我们要做的是，在批处理操作系统中添加一段汇编代码，实现从用户栈切换到内核栈，并在内核栈上保存应用程序控制流的寄存器状态。

常数 `USER_STACK_SIZE` 和 `KERNEL_STACK_SIZE` 指出内核栈和用户栈的大小分别为 $8KiB$ 。两个类型是以*全局变量*的形式*实例化*在批处理操作系统的 `.bss` 段中的。
```RUST
struct KernelStack {//内核栈
    data: [u8; KERNEL_STACK_SIZE],
}
struct UserStack {//用户栈
    data: [u8; USER_STACK_SIZE],
}
static KERNEL_STACK: KernelStack = KernelStack {
    data: [0; KERNEL_STACK_SIZE],
};
static USER_STACK: UserStack = UserStack {
    data: [0; USER_STACK_SIZE],
};
```
我们为两个类型实现了 `get_sp` 方法来获取栈顶地址。

接下来是 Trap 上下文（即数据结构 `TrapContext` ），类似前面提到的函数调用上下文，即在 Trap 发生时需要保存的物理资源内容，并将其一起放在一个名为 `TrapContext` 的类型中，定义如下
```RUST
// os/src/trap/context.rs

#[repr(C)]
pub struct TrapContext {
    pub x: [usize; 32],
    pub sstatus: Sstatus,
    pub sepc: usize,
}
```
可以看到里面包含所有的通用寄存器 `x0~x31` ，还有 `sstatus` 和 `sepc` 。那么为什么需要保存它们呢？

-   对于通用寄存器而言，两条控制流（应用程序控制流和内核控制流）运行在不同的特权级，所属的软件也可能由不同的编程语言编写，虽然在 Trap 控制流中只是会执行 Trap 处理相关的代码，但依然可能直接或间接调用很多模块，因此很难甚至不可能找出哪些寄存器无需保存。既然如此我们就只能全部保存了。但这里也有一些例外，如 `x0` 被硬编码为 0 ，它自然不会有变化；还有 `tp(x4)` 寄存器，除非我们手动出于一些特殊用途使用它，否则一般也不会被用到。虽然它们无需保存，但我们仍然在 `TrapContext` 中为它们预留空间，主要是为了后续的实现方便。
    
-   对于 CSR 而言，我们知道进入 Trap 的时候，硬件会立即覆盖掉 `scause/stval/sstatus/sepc` 的全部或是其中一部分。`scause/stval` 的情况是：它总是在 Trap 处理的第一时间就被使用或者是在其他地方保存下来了，因此它没有被修改并造成不良影响的风险。而对于 `sstatus/sepc` 而言，它们会在 Trap 处理的全程有意义（在 Trap 控制流最后 `sret` 的时候还用到了它们），而且确实会出现 Trap 嵌套的情况使得它们的值被覆盖掉。所以我们需要将它们也一起保存下来，并在 `sret` 之前恢复原样。

### Trap 上下文的保存与恢复[]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter2/4trap-handling.html#id8 "永久链接至标题")
首先是具体实现 Trap 上下文保存和恢复的汇编代码。

在批处理操作系统初始化的时候，我们需要修改 `stvec` 寄存器来指向正确的 Trap 处理入口点。

> #RISC risc-V **CSR 相关原子指令**
> RISC-V 中读写 CSR 的指令是一类能不会被打断地完成多个读写操作的指令。这种不会被打断地完成多个操作的指令被称为 **原子指令** (Atomic Instruction)。这里的 **原子** 的含义是“不可分割的最小个体”，也就是说指令的多个操作要么都不完成，要么全部完成，而不会处于某种中间状态。
> 另外，RISC-V 架构中常规的数据处理和访存类指令只能操作通用寄存器而不能操作 CSR 。因此，当想要对 CSR 进行操作时，需要先使用读取 CSR 的指令将 CSR 读到一个通用寄存器中，而后操作该通用寄存器，最后再使用写入 CSR 的指令将该通用寄存器的值写入到 CSR 中。


>**sscratch CSR 的用途**
>在特权级切换的时候，我们需要将 Trap 上下文保存在内核栈上，因此需要一个寄存器暂存内核栈地址，并以它作为基地址指针来依次保存 Trap 上下文的内容。但是所有的通用寄存器都不能够用作基地址指针，因为它们都需要被保存，如果覆盖掉它们，就会影响后续应用控制流的执行。
>事实上我们缺少了一个重要的中转寄存器，而 `sscratch` CSR 正是为此而生。从上面的汇编代码中可以看出，在保存 Trap 上下文的时候，它起到了两个作用：首先是保存了内核栈的地址，其次它可作为一个中转站让 `sp` （目前指向的用户栈的地址）的值可以暂时保存在 `sscratch` 。这样仅需一条 `csrrw  sp, sscratch, sp` 指令（交换对 `sp` 和 `sscratch` 两个寄存器内容）就完成了从用户栈到内核栈的切换，这是一种极其精巧的实现。


发现触发 Trap 的原因是来自 U 特权级的 Environment Call，也就是系统调用。这里我们首先修改保存在内核栈上的 Trap 上下文里面 sepc，让其增加 4。这是因为我们知道这是一个由 `ecall` 指令触发的系统调用，在进入 Trap 的时候，硬件会将 sepc 设置为这条 `ecall` 指令所在的地址（因为它是进入 Trap 之前最后一条执行的指令）

> 在 risc-v 中，系统调用参数和返回值存储在如下所示的寄存器中：
>  *参数*
> -   a0~a5：系统调用参数 1~6。
> -   a7：系统调用编号。
> 
>  *返回值*
> -   a0：系统调用返回值。
> 
> 当系统调用完成时，它会将返回值放入 a0 寄存器中，供调用者进一步使用。

