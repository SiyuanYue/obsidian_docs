SBI 是 RISC-V Supervisor Binary Interface 规范的缩写，OpenSBI 是 RISC-V 官方用 C 语言开发的 SBI 参考实现；RustSBI 是用 Rust 语言实现的 SBI。

BIOS 是 Basic Input/Output System，作用是引导计算机系统的启动以及硬件测试，并向OS提供硬件抽象层。

机器上电之后，会从ROM中读取引导代码，引导整个计算机软硬件系统的启动。而整个启动过程是分为多个阶段的，现行通用的多阶段引导模型为：

ROM -> LOADER -> RUNTIME -> BOOTLOADER -> OS

Loader 要干的事情，就是内存初始化，以及加载 Runtime 和 BootLoader 程序。而Loader自己也是一段程序，常见的Loader就包括 BIOS 和 UEFI，后者是前者的继任者。

Runtime 固件程序是为了提供运行时服务（runtime services），它是对硬件最基础的抽象，对OS提供服务，当我们要在同一套硬件系统中运行不同的操作系统，或者做硬件级别的虚拟化时，就离不开Runtime服务的支持。SBI就是RISC-V架构的Runtime规范。

BootLoader 要干的事情包括文件系统引导、网卡引导、操作系统启动配置项设置、操作系统加载等等。常见的 BootLoader 包括GRUB，U-Boot，LinuxBoot等。