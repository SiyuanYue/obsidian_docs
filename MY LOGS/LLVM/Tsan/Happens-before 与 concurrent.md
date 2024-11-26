## [Introduction](https://llvm-study-notes.readthedocs.io/en/latest/sanitizer/tsan/dissecting-thread-sanitizer.html#introduction "Permalink to this heading")

ThreadSanitizer(AKA TSan) 是一个集成在 GCC 和 Clang 中的动态分析工具，能够检测 C++ 代码中大多数的数据竞争 (data race) 。它由编译时插桩和运行时库两部分组成，通过编译和链接时添加参数 `-fsanitize=thread`，就可以在运行时检测 data race 。

## Data Race
TSan 是检测 data race 的动态分析工具。我们先看下 data race 指的是什么？

**Data Race**：两个线程 **concurrently** 访问了**同一个内存位置 (memory location)**，并且两个线程的访存操作中**至少一个是写操作**。

注：关于 race condition 和 data race 的区别，见 [Race Condition vs. Data Race – Embedded in Academia](https://blog.regehr.org/archives/490)

例如下述代码：两个线程并发地修改整型全局变量 Global 存在 data race。两个线程执行结束后，全局变量 Global 的值可能是 1 也可能是 2。如果是在读写 STL 容器时存在 data race，则可能导致更严重的后果，比如内存破坏、程序崩溃。

```c++
int Global;

void Thread1() {
  Global = 1;
}

void Thread2() {
  Global = 2;
}
```
根据 data race 的定义，判断代码中是否存在 data race 需要考虑 3 个条件：

1. 两个线程访问的是否为**同一个 memory location**
    
2. 两个线程的访存操作中**至少有一个是写操作**
    
3. 两个线程的访存操作是否 **concurrent**
    

其中前两个条件很容易判断，所以检测 data race 的要解决的关键问题就是怎么判断两个访存操作是否 **concurrent** **！**

## [Happen-Before & Concurrent](https://llvm-study-notes.readthedocs.io/en/latest/sanitizer/tsan/dissecting-thread-sanitizer.html#happen-before-concurrent "Permalink to this heading")

在介绍如何判断两次访问操作是否是 concurrent 之前，我们需要先引入 happen-before 的定义。

Happen-before 的定义最开始是在 [Lamport, L., 1978. Time, clocks, and the ordering of events in a distributed system](https://lamport.azurewebsites.net/pubs/time-clocks.pdf) 中给出的，描述的是分布式系统中事件之间的一种偏序关系。

一个分布式系统是由一系列 processes 组成的，每个 process 又由一系列事件组成， 不同的 process 之间是通过收发消息进行通信的。

**Happen-before** 关系（记作 →）的定义：

1. 如果事件 a 和事件 b 是在同一个 process 中的事件，并且 a 早于 b 发生，那么 a→b
    
2. 如果事件 a 和事件 b 是不同 process 中的事件，且 b 是 a 发送的消息的接收者，那么 a→b
    
3. **Happen-before** 关系是一种严格**偏序**关系 (strict partial order)，即满足 transitive, irreflexive and antisymmetric
    
    1. Transitive。对于任意事件 a,b,c，如果 a→b 且 b→c，那么有 a→c
        
    2. Irreflexive。对于任意事件 a，都有 a↛a
        
    3. Antisymmetric。对于任意事件 a,b，如果 a→b，那么有 b↛a
        

下面通过一个例子对 happen-before 进行说明：

![../../_images/2022-10-20-09-43-40-image.png](https://llvm-study-notes.readthedocs.io/en/latest/_images/2022-10-20-09-43-40-image.png)

上图是对一个分布式系统的某一次 trace：

- 3 条垂直线分别表示 3 个 process: P,Q,R
    
- 垂直线上的点表示事件，在同一条垂直线上纵坐标小的事件发生的时间早于纵坐标大的事件发生的时间。例如事件 p1 早于事件 p2 发生
    
- 连接 process 之间的线表示 process 之间通过收发消息进行通信，p1→q2 表示 process P 于事件 p1 向 process Q 发送消息， 这个消息被 process Q 于事件 q2 接收到
    

那么对于上图分布式系统 trace：

- 根据 **happen-before** 的定义能得出：p1→r4，这是因为 p1→q2, q2→q4, q4→r3, r3→r4，所以 p1→r4。即事件 p1 一定是先于事件 r4 发生，不管上述分布式系统事件运行多少次
    
- 尽管根据本次 trace 看来在时间上事件 q3 是早于事件 p3 发生的，但是 q3↛p3 且 p3↛q3，即事件 q3 和事件 p3 之间是没有 happen-before 关系的。所以不能保证每一次运行，事件 q3 都是早于事件 p3 发生的，也有可能在某一次 trace 中事件 p3 是早于事件 q3 发生的
    

理解了 happen-before 的定义后，我们给出 **concurrent** 的定义：如果 a↛b 且 b↛a，那么称 a 和 b 是 **concurrent** 的。

这样我们就能够将判断两次访存操作之间是否 concurrent 转化为了判断两次访存操作之间是否存在 happen-before 关系。

那么如何判断两次访存操作之间是否存在 happen-before 关系呢？答案是 Vector Clock。

## Vector Clock
vector clock 算法如下：

- 每一个 process Pi 都对应一个 vector clock VCi，VCi 是由 n 个元素组成的向量，n 是分布式系统中 process 的数量。每个 process Pi 的 VCi 都被初始化为 0
    
- 每当 process Pi 发生本地事件之前，更新 vector clock：VCi[i]=VCi[i]+1
    
- Process Pi 向其他 Process 发送消息时，先更新 vector clock：VCi[i]=VCi[i]+1，然后将 VCi 的值包含在消息中
    
- process Pj 接收由 process Pi 发送来的 message，更新 vector clock：VCj[j]=VCj[j]+1,VCj[k]=max(VCj[k],VCi[k]) for all process k
    

下面还是通过一个例子来说明 vector clock 的算法流程：

![../../_images/2022-10-20-10-23-24-image.png](https://llvm-study-notes.readthedocs.io/en/latest/_images/2022-10-20-10-23-24-image.png)

- 初始时 VC1=VC2=VC3=[0,0,0]
    
- Process P 发生内部事件 p1，更新 vector clock：VC1=[0+1,0,0]=[1,0,0]
    
- Process Q 发生内部事件p2，更新 vector clock：VC2=[0,0+1,0]=[0,1,0]
    
- Process R 发生内部事件 p3，更新 vector clock：VC3=[0,0,0+1]=[0,0,1]
    
- process Q 于事件 q2 接收由 process P 于事件 p2 发送的消息，更新 vector clock：
    
    - VC1[1]=1+1=2,VC1=[2,0,0]
        
    - VC2[2]=1+1=2,VC2=[0,2,0]
        
    - VC2=max(VC1,VC2)=[max(2,0),max(0,2),max(0,0)]=[2,2,0]
        
- …
    

Vector clock 解决了 lamport logical clock 的局限性，满足如下性质：

- 如果事件 a **happen-before** 事件 b，那么 VC(a)<VC(b)
    
- 如果 VC(a)<VC(b)，那么事件 a **happen-before** 事件 b
    

即 pa→qbiffVCp(a)<VCq(b)

Vector clock 上的偏序关系如下：

- VCp=VCqiff∀k,VCp[k]=VCq[k]
    
- VCp≠VCqiff\existk,VCp[k]≠VCq[k]
    
- VCp≤VCqiff∀k,VCp[k]≤VCq[k]
    
- VCp<VCqiff(VCp≤VCqandVCp≠VCq)
    

根据 pa→qbiffVCp(a)<VCq(b) 这个性质，我们就能使用 vector clock 来判断两次访存操作之间是否存在 happen-before 关系，即能够基于 vector clock 算法来检测多线程程序中的 data race。