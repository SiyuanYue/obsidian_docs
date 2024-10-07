
## 调用规范[]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter1/5support-func-call.html#term-calling-convention "永久链接至标题")
**调用规范** (Calling Convention) 约定在某个指令集架构上，某种编程语言的函数调用如何实现。它包括了以下内容：
1.  函数的输入参数和返回值如何传递；

2.  函数调用上下文中调用者/被调用者保存寄存器的划分；

3.  其他的在函数调用流程中对于寄存器的使用方法。

调用规范是对于一种确定的编程语言来说的，因为一般意义上的函数调用只会在编程语言的内部进行。当一种语言想要调用用另一门编程语言编写的函数接口时，编译器就需要同时清楚两门语言的调用规范，并对寄存器的使用做出调整。
![[Pasted image 20230427224739.png]]



## 分配并使用启动栈
通过宏将 `rust_main` 标记为 `#[no_mangle]` 以避免编译器对它的名字进行混淆，不然在链接的时候， `entry.asm` 将找不到 `main.rs` 提供的外部符号 `rust_main` 从而导致链接失败。在 `rust_main` 函数的开场白中，我们将第一次在栈上分配栈帧并保存函数调用上下文，它也是内核运行全程中最底层的栈帧。
在内核初始化中，需要先完成对 `.bss` 段的清零。这是内核很重要的一部分初始化工作，在使用任何被分配到 `.bss` 段的全局变量之前我们需要确保 `.bss` 段已被清零。

>**Rust Tips：外部符号引用**
>extern “C” 可以引用一个外部的 C 函数接口（这意味着调用它的时候要遵从目标平台的 C 语言调用规范）。但我们这里只是引用位置标志并将其转成 usize 获取它的地址。由此可以知道 `.bss` 段两端的地址。



## 使用 RustSBI 提供的服务[]( http://rcore-os.cn/rCore-Tutorial-Book-v3/chapter1/6print-and-shutdown-based-on-sbi.html#rustsbi "永久链接至标题")

之前我们对 RustSBI 的了解仅限于它会在计算机启动时进行它所负责的环境初始化工作，并将计算机控制权移交给内核。但实际上作为内核的执行环境，它还有另一项职责：即在内核运行时响应内核的请求为内核提供服务。当内核发出请求时，计算机会转由 RustSBI 控制来响应内核的请求，待请求处理完毕后，计算机控制权会被交还给内核。从内存布局的角度来思考，每一层执行环境（或称软件栈）都对应到内存中的一段代码和数据，这里的控制权转移指的是 CPU 从执行一层软件的代码到执行另一层软件的代码的过程。这个过程和函数调用比较像，但是内核无法通过函数调用来请求 RustSBI 提供的服务，这是因为内核并没有和 RustSBI 链接到一起，我们仅仅使用 RustSBI 构建后的可执行文件，因此内核对于 RustSBI 的符号一无所知。事实上，内核需要通过另一种复杂的方式来“调用” RustSBI 的服务：
```RUST
// os/src/main.rs
mod sbi;

// os/src/sbi.rs
use core::arch::asm;
#[inline(always)]
fn sbi_call(which: usize, arg0: usize, arg1: usize, arg2: usize) -> usize {
    let mut ret;
    unsafe {
        asm!(

            "ecall",

            inlateout("x10") arg0 => ret,

            in("x11") arg1,

            in("x12") arg2,

            in("x17") which,

        );

    }

    ret

}
```
#RustSBI
我们将内核与 RustSBI 通信的相关功能实现在子模块 `sbi` 中，因此我们需要在 `main.rs` 中加入 `mod sbi` 将该子模块加入我们的项目。在 `os/src/sbi.rs` 中，我们首先关注 `sbi_call` 的函数签名， `which` 表示请求 RustSBI 的服务的类型（RustSBI 可以提供多种不同类型的服务）， `arg0` ~ `arg2` 表示传递给 RustSBI 的 3 个参数，而 RustSBI 在将请求处理完毕后，会给内核一个返回值，这个返回值也会被 `sbi_call` 函数返回。尽管我们还不太理解函数 `sbi_call` 的具体实现，但目前我们已经知道如何使用它了：当需要使用 RustSBI 服务的时候调用它就行了。

```RUST
fn clear_bss() {
    extern "C" {
        fn sbss();
        fn ebss();
    }
    (sbss as usize..ebss as usize).for_each(|a| {
        unsafe { (a as *mut u8).write_volatile(0) }
    });

}
```
#Rust
> \*mut u8 是表明类型变量为原始指针类型，不是解引用。内存是按字节编址的，内存地址是 64 位的整数，每一 64 位地址指向 8 位二进制位数据，for_each 遍历[sbss, ebss]之间的 usize 64 位整数，将其赋值给 a。将 a 转换为指向 8 位宽整型 u8 的指针类型，此时 a 存储地址，通过函数 write_volatile () 写入数据 0。因为直接操作原始指针类型在 rust 中不能保证安全性，需要声明为 unsafe。出现错误时可首先考虑 unsafe 代码块，减少排错复杂度。  
>a.write_volatile(0)方法将0写入指针类型a存储的地址所指向的1字节内存区域