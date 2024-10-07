# NJUOSLAB M2

## Understand && CODE
1. HOW TO DEBUG 优雅？
```
#ifdef LOCAL_MACHINE
  #define debug(...) printf(__VA_ARGS__)
#else
  #define debug()
#endif
```
然后通过增加 `-DLOCAL_MACHINE` 的编译选项来实现输出控制——在 Online Judge 上，所有的调试输出都会消失。

>  **克服你的惰性**
> 在新手阶段，你很容易觉得做上面两件事会比较受挫：首先，你可以用注释代码的办法立即搞定，所以**你的本能驱使你不去考虑更好的办法**。但当你来回浪费几次时间之后，你应该回来试着优化你的基础设施。可能你会需要一些时间阅读文档或调试你的 Makefile/Cmake，但它们的收获都是值得的。

2. **理解 `co_yield` 发生的时候，我们的程序到底处于什么状态**

3. 理解 stack_switch_call  （*RTFM 阅读介绍内联汇编一个友好的文档*：
http://www.ibiblio.org/gferg/ldp/GCC-Inline-Assembly-HOWTO.html ）
```C
static inline void stack_switch_call(void *sp, void *entry, uintptr_t arg)
{
	asm volatile(
#if __x86_64__
		"movq %0, %%rsp; movq %2, %%rdi; jmp *%1"
		:
		: "b"((uintptr_t)sp), "d"(entry), "a"(arg)
		: "memory"
#else
		"movl %0, %%esp; movl %2, 4(%0); jmp *%1"
		:
		: "b"((uintptr_t)sp - 8), "d"(entry), "a"(arg)
		: "memory"
#endif
	);
} 
```

4. *如何知道这个协程执行完毕，co->status改为dead* ？
>**switch_stack_call()执行完返回时？**

5.  **co_queue的管理:    随机选择一个**

## DEBUG
1. 给出的` struct co` 中 `char* name`  没有分配内存
2.  `current`    一开始 `位于main函数中` 未初始化呀

# BUG： 

stack 分配检查  && stack_switch_call存在问题，现已解决（maybe？？？）

# Question:
调度，not粗暴数组随机数，太垃圾了！！！
已经执行完的线程（回收！）如何调度的问题！！！
