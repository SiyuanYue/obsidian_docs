
#NJUOS #GDB 

写一个使用`setjmp/longjmp`  的示例程序然后使用 #gdb 去调试一步步asm代码。

 `setjmp/longjmp` 。你需要多读一读 `setjmp/longjmp` 的文档和例子——这是很多高端面试职位的必备题目。如果你能解释得非常完美，就说明你对 C 语言有了脱胎换骨的理解。`setjmp/longjmp` 的 “寄存器快照” 机制还被用来做很多有趣的 hacking，例如[实现事务内存](http://www.doc.ic.ac.uk/~phjk/GROW09/papers/03-Transactions-Schwindewolf.pdf)、[在并发 bug 发生以后的线程本地轻量级 recovery](https://doi.acm.org/10.1145/2451116.2451129) 等等。

`setjmp/longjmp` 类似于保存寄存器现场/恢复寄存器现场的行为，其实模拟了操作系统中的上下文切换。因此如果你彻底理解了这个例子，你们一定会觉得操作系统也不过如此——我们在操作系统的进程之上又实现了一个迷你的 “操作系统”。类似的实现还有 AbstractMachine 的native，它是通过 `ucontext.h` 实现的，有兴趣的同学也可以尝试阅读 AbstractMachine 的代码。

