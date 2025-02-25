这一章节描述了 `IA-32` 架构的任务管理功能。这些功能只在处理器运行于*保护模式*下时才可用。
本章主要关注于 32 位任务和 32 位 tss 结构。有关*16 位任务和 16 位 tss 结构*的信息，请参见*8.6 节“16 位任务状态段（tss）”*。有关 *64 位模式下特定的任务管理信息*，请参见 *8.7 节“64 位模式下的任务管理”*。

# 1. `TASK`管理概览
任务是处理器可以*调度、执行和挂起的工作单元*。它可以用于*执行程序*、*任务或进程*、操作系统服务实用程序、*中断或异常处理程序*，或内核或执行实用程序。

**IA-32**体系结构提供了*保存任务状态、调度任务执行以及从一任务切换到另一任务的机制*。在**保护模式**下操作时，所有处理器执行都发生在任务内部。即使是简单的系统也必须定义至少一个任务。更复杂的系统可以利用处理器的任务管理功能来支持多任务应用程序。

## 1.1 任务结构
任务由两部分组成：*任务执行空间*和*任务状态段（tss）*。 任务执行空间由代码段、堆栈段和一个或多个数据段组成（请参见图8-1）。如果操作系统或执行程序使用处理器的*特权级保护机制*，则任务执行空间还为*每个特权级提供单独的堆栈*。
![](images/Pasted%20image%2020230430145344.png)
`tss`指定了组成任务执行空间的段，并提供了任务状态信息的存储位置。在多任务系统中，`tss`还提供了链接任务的机制。
TASK 由其 *tss 的段选择器* 来识别。当任务加载到处理器中以执行时，tss 的段选择器、基地址、限制和段描述符属性将被加载到任务寄存器中。
>TR 任务寄存器保存当前任务的 TSS 的 16 位段选择器、基地址（在保护模式下为 32 位，在 IA-32e 模式下为 64 位）、段限制和描述符属性。*16 位选择器引用 GDT 中的 TSS 描述符*。基地址指定 TSS 的字节 0 的线性地址；段限制指定 TSS 中的字节数。
> `LTR` 和 `STR` 指令分别加载和存储任务寄存器的段选择器部分。当 `LTR` 指令在任务寄存器中加载段选择器时，TSS 描述符中的基地址、限制和描述符属性会自动加载到任务寄存器中。在处理器上电或重置时，基地址被设置为默认值 0，限制被设置为 0FFFFH。
>当任务切换发生时，任务寄存器会自动加载新任务的 TSS 的段选择器和描述符。

如果对任务实现了分页，则任务使用的页目录的基地址将被加载到控制寄存器 cr3 中。
我们再回顾一下啊 2.1 中的整个内存中架构的一览图：
![](images/Pasted%20image%2020230430151037.png)


## 1.2 TASK STATE 任务状态
以下是当前任务的状态定义：
-   任务的当前执行空间，由段寄存器（cs，ds，ss，es，fs和gs）中的段选择器定义。
-   通用寄存器的状态。
-   eflags 寄存器的状态。
-   eip 寄存器的状态。
-   控制寄存器 cr3 的状态。
-   任务寄存器的状态。
-   ldtr 寄存器的状态。
-   i/o 映射基地址和 i/o 映射（包含在 tss 中）。
-   *特权级 0、1 和 2 堆栈的堆栈指针*（包含在 tss 中）。
-   指向先前执行的任务的链接（包含在 tss 中）。
-   阴影堆栈指针（ssp）的状态。

在分派任务之前，所有这些内容都包含在任务的 tss 中，除了任务寄存器的状态。此外，ldtr 寄存器的完整内容不包含在 tss 中，*只包含 ldt 的段选择器*。

## 1.3 执行任务
软件或处理器可以通过以下方式之一调度任务执行：
• 使用 `call` 指令显式调用任务。
• 使用 `jmp` 指令显式跳转到任务。
• 处理器隐式调用*中断处理程序任务*。
• 隐式调用*异常处理程序任务*。
• 当 `eflags` 寄存器中的 \# nt 标志被设置时，使用 `iret` 指令发起返回。
所有这些调度任务的方法都*使用指向任务门或任务 tss 的段选择器*来*标识*要调度的任务。使用 call 或 jmp 指令调度任务时，指令中的选择器可以直接选择 tss 或包含 tss 选择器的任务门。在调度任务来处理中断或异常时，*中断或异常的 IDT条目*必须包含一个**持有中断或异常处理程序 tss 选择器的任务门**。
当任务被调度执行时，在当前正在运行的任务与被调度任务之间发生任务切换。在任务切换期间，当前正在执行任务的执行环境（称为任务的状态或上下文）将被保存在其 tss 中，并暂停执行该任务。然后将被调度任务的上下文加载到处理器中，并从新加载的 eip 寄存器所指向的指令开始执行该任务。如果该任务自系统上次初始化后没有运行过，则 eip 将指向任务代码的第一条指令；否则，它将指向任务上次活动时执行的最后一条指令的下一条指令。

如果当前正在执行任务（即调用任务）调用了正在调度的任务（即被调用任务），则调用任务的 tss 段选择器将存储在被调用任务的 tss 中，以提供一个返回到调用任务的链接。

对于所有 IA-32 处理器，**任务不是递归的**。任务不能调用或跳转到自己。

*中断和异常*可以通过任务切换到处理程序任务来处理。在这里，处理器执行任务切换来处理中断或异常，并在从中断处理程序任务或异常处理程序任务返回时自动切换回被中断的任务。*该机制还可以处理在中断任务期间发生的中断*。

作为任务切换的一部分，处理器还可以切换到另一个 *LDT*，允许每个任务对基于 *LDT*的段具有不同的逻辑到物理地址映射。页目录基地址寄存器（*CR3*）也会在任务切换时重新加载，*允许每个任务拥有自己的页面表*。这些保护机制有助于隔离任务并防止它们相互干扰。

如果不使用保护机制，则处理器不会在任务之间提供任何保护。即使有操作系统用于保护的多个特权级别，也是如此。在使用与其他特权级别 3 任务相同的 LDT和页面表的特权级别 3 运行的任务可能会访问代码并破坏其他任务的数据和堆栈。

使用任务管理设施来处理多任务应用程序是可选的。*可以使用软件处理多任务，其中定义的每个软件任务在单个ia-32体系结构任务的上下文中执行。*

# 2 TASK 的数据结构

处理器定义了五个数据结构来处理与任务相关的活动：
• 任务状态段（tss）。
• 任务门描述符。
• tss 描述符。
• 任务寄存器。
• eflag 寄存器中的 nt 标志位。
在保护模式下运行时，必须为至少一个任务创建 tss 和 tss 描述符，并将 tss 的段选择器加载到任务寄存器中（使用 `ltr` 指令）。

## 2.1 TSS
The processor state information needed to restore a task 保存在系统段中，称为任务状态段 (tss)。图 8-2 展示了 32 位 cpu 设计任务的 tss 格式。 tss 的字段分为两个主要类别：动态字段和静态字段。有关 16 位 intel 286 处理器任务结构的信息，请参阅第 8.6 节“16 位任务状态段 (tss)” 。有关 64 位模式任务结构的信息，请参阅第 8.7 节“64 位模式下的任务管理”。
![](images/Pasted%20image%2020230430162935.png)
处理器在任务切换期间暂停任务时更新动态字段。以下是动态字段：
-   通用寄存器字段 - 任务切换前eax、ecx、edx、ebx、*esp、ebp*、esi和edi寄存器的状态。
-   段选择器字段 - 任务切换前存储在es、cs、ss、ds、fs和gs寄存器中的段选择器。
-   eflags 寄存器字段 - 任务切换前 eflags 寄存器的状态。
-  eip (指令指针) 字段 — 任务切换之前 eip 寄存器的状态。
-  先前任务链接字段 — 包含上一个任务 tss 的段选择器（在由调用、中断或异常引发的任务切换中更新）。该字段（有时称为回链字段）允许使用 iret 指令切换回先前的任务。

处理器读取静态字段，但通常不会更改它们。这些字段在创建任务时设置。以下是静态字段:
- ldt 段选择器字段 — 包含任务的 ldt 的段选择器。
-  cr3 控制寄存器字段 — 控制寄存器 cr3 也称为页目录基址寄存器 (pdbr)。
- 特权级 0、1 和 2 栈指针字段 — **这些栈指针是由堆栈段的段选择器 (ss0、ss1 和 ss2) 和堆栈偏移量 (esp0、esp1 和 esp2) 组成的逻辑地址**。*请注意，这些字段中的值对于特定任务是静态的*；而 ss 和 esp 的值在任务内进行堆栈切换时将发生动态变化。
- t (调试陷阱) 标志 (第 100 字节、第 0 位) — 设置后，t 标志将导致处理器在切换到该任务时抛出调试异常（参见第 18.3.1.5 节“任务切换异常条件”）。
- i/o 映射基地址字段 — 包含从 tss 基址开始到 i/o 许可位图和中断重定向位图的 16 位偏移量。
* ssp 字段包含任务的影子堆栈指针。任务的影子堆栈应该在由任务 ssp（偏移量 104）指向的地址上具有监督员影子堆栈令牌。使用 call/jmp 指令切换到该影子堆栈时，将验证并使其忙碌，并在使用 iret 指令切换出该任务时释放。

如果使用分页：
- 应将对应于前一个任务 tss、当前任务 tss 和每个任务描述符表项的页面标记为读/写。
- 如果在启动任务切换之前这些结构所在的页面存在于内存中，则可以更快地进行任务切换。

## 2.2 TSS 描述符
*tss（任务状态段）和其他片段一样，是由段描述符定义的*。图 8-3 展示了 tss 描述符的格式。
tss 描述符*只能放置在 gdt 中，不能放置在 ldt 或 idt 中*。使用带有 ti 标志设置（表示当前 ldt）的段选择器尝试访问 tss 会导致在 calls 和 jmps 期间生成 `一般保护异常（#gp）`；在 irets 期间会导致 `无效的tss异常（＃ts）`。如果尝试将 `tss的段选择器加载到段寄存器中，则还会生成一般保护异常`。
类型字段中的忙标志（b）指示任务是否繁忙。繁忙的任务当前正在运行或挂起。类型字段值为 1001b 表示非活动任务；1011b 表示繁忙任务。任务不递归。处理器使用忙标志检测尝试调用其执行已被中断的任务的企图。为确保一个任务仅与一个忙标志相关联，*每个 tss 应仅有一个指向它的 tss 描述符*。

![](images/Pasted%20image%2020230430162841.png)
基址 (base)、限制 (limit) 和 dpl 字段，以及粒度 (granularity) 和存在标志 (present flags) 的功能类似于它们在数据段描述符中 (参见第 3.4.5 节“段描述符”) 的使用。
当 32 位 tss (task-state segment) 的 tss 描述符中的 G 标志为 0 时，limit 字段必须具有等于或大于 67h 的值，这是一个 tss 的最小大小减去一个字节。尝试切换到 tss 描述符具有小于 67h 的限制的任务会生成无效 tss 异常 ( \ #ts )。如果包括 I/O 权限位图或操作系统存储额外数据，则需要更大的限制。处理器在任务切换时不检查超过 67h 的限制；但是，在访问 i/o 权限位图或中断重定向位图时，它会进行检查。
任何可以访问 tss 描述符 (即其 cpl 数值相等或小于 tss 描述符的 dpl) 的程序或过程都可以通过调用或跳转来分派任务。在大多数系统中，tss 描述符的 dpl 设置为小于 3 的值，以便只允许特权软件执行任务切换。但是，在多任务应用程序中，某些 tss 描述符的 dpl 可能被设置为 3，以允许应用程序 (或用户) 特权级别的任务切换。
## 2.3 TR 任务寄存器
**任务寄存器**包含 *16 位段选择器*和*整个段描述符*（32 位基地址（在 ia-32e 模式下为 64 位），16 位段限制和描述符属性），用于当前任务的 tss（参见图 2-6）。*此信息从当前任务在 gdt 中的 tss 描述符中复制*。图 8-5 显示了处理器使用的*访问 tss 的路径*（使用任务寄存器中的信息）。
![](images/Pasted%20image%2020230430163823.png)
任务寄存器有一个可见部分（可以被软件读取和更改）和一个不可见部分（由处理器维护，无法由软件访问）。可见部分中的*段选择器*指向 gdt 中的 tss 描述符。处理器使用*任务寄存器的不可见部分缓存 tss 的段描述符*。将这些值缓存在寄存器中可以使*任务的执行更有效率*。ltr（加载任务寄存器）和 str（存储任务寄存器）*指令加载和读取任务寄存器的可见部分*：
ltr 指令将段选择器（源操作数）加载到任务寄存器中，*该选择器指向 gdt 中的 tss 描述符*。然后，它将任务寄存器的不可见部分从 tss 描述符中填充信息。*ltr 是一条特权指令，只能在 cpl 为 0 时执行*。它在系统初始化期间用于将初始值放入任务寄存器。随后，当任务切换发生时，任务寄存器的内容隐式更改。
str（存储任务寄存器）指令将任务寄存器的可见部分存储在通用寄存器或内存中。该指令可以由任何特权级别的代码执行，以确定当前正在运行的任务。然而，通常仅由操作系统软件使用。（如果 cr4. umip = 1，则只能在 cpl = 0 时执行 str。）
在处理器上电或复位时，段选择器和基地址设置为默认值0；限制设置为ffffh。
## 2.4 Task-Gate Descriptor
*任务门描述符提供对任务的间接保护引用*（见图 8-6）。它可以放置在 gdt、ldt 或 idt 中。任务门描述符中的 tss 段选择子字段指向 gdt 中的 tss 描述符。该段选择子中的 rpl 未被使用。

任务门描述符的 `dpl` 控制*任务切换期间访问 tss 描述符的权限*。
**当程序或过程通过任务门调用或跳转到任务时**，指向任务门的*门选择器*的cpl和rpl字段必须小于或等于任务门描述符的dpl。请注意，使用任务门时，目标tss描述符的dpl未使用。
![](images/Pasted%20image%2020230430163952.png)
一个任务通过任务门描述符或 tss 描述符可以被访问。这些结构都满足以下需求：
• 任务仅需要一个忙标志 — 因为任务的忙标志存储在 tss 描述符中，每个任务只应该有一个 tss 描述符。然而可能有几个任务门引用同一个 tss 描述符。
• 选择性地访问任务 — 任务门满足这种需求，因为它们可以驻留在 ldt 中并且可以具有不同于 tss 描述符 dpl 的 dpl。一个没有足够特权来访问 gdt 中任务的 tss 描述符（通常具有 dpl 0）的程序或过程可以通过具有更高 dpl 的任务门访问任务。任务门给操作系统更大的灵活性以限制对特定任务的访问。
• *一个任务处理中断或异常* — 任务门也可以驻留在**idt**中，*允许中断和异常由处理器任务处理*。**当中断或异常向量指向一个任务门**时，处理器会切换到指定任务。图 8-7 说明了如何在 ldt 中的任务门、gdt 中的任务门和 idt 中的任务门都可以指向同一个任务。

![](images/Pasted%20image%2020230430164439.png)

# 3. 任务切换
处理器在以下四种情况下将执行权转移给另一个任务：
• 当前程序、任务或过程执行 gdt 中 tss 描述符的 jmp 或 call 指令。
• 当前程序、任务或过程执行 gdt 或当前 ldt 中任务门描述符的 jmp 或 call 指令。
• 中断或异常向量指向 idt 中任务门描述符。
• 当 eflags 寄存器中的 nt 标志被置位时，当前任务执行 iret。
jmp、call 和 iret 指令以及中断和异常都是将程序重定向的机制。引用 tss 描述符或任务门（在调用或跳转到任务时）或执行 iret 指令时 nt 标志的状态（when executing an IRET instruction）决定是否发生任务切换。

当切换到新任务时，处理器执行以下操作：
1. 从任务门获取新任务的 tss 段选择器作为 jmp 或 call 指令的运算数，或从前一个任务链接字段（对于使用 iret 指令启动的任务切换）中获取。
2. 检查当前（旧的）任务是否允许切换到新任务。数据访问特权规则适用于 jmp 和 call 指令。当前（旧）任务的 cpl 和新任务的段选择器的 rpl 必须小于或等于正在引用的 tss 描述符或任务门的 dpl。异常、中断（除了下一句中标识的那些），以及 iret 和 int1 指令可以无论目的地任务门或 tss 描述符的 dpl 如何都可以切换任务。对于通过 int n、int3 和 into 指令生成的中断，将检查 dpl，并在其小于 cpl 时产生通用保护例外（ #gp ）。
3. 检查新任务的 tss 描述符是否已标记为存在并具有有效限制（大于或等于 67h）。如果任务切换是由 iret 引发的，并且阴影堆栈在当前 cpl 处启用，则 ssp 必须对齐到 8 字节，否则会生成 #ts （当前任务 tss）故障。如果 cr4. cet 为 1，则 tss 必须是 32 位 tss，新任务的 tss 限制必须大于或等于 107 字节，否则会生成 #ts （新任务 tss）故障。
4. 检查新任务是否可用（调用、跳转、异常或中断）或繁忙（iret 返回）。
5. 检查任务切换中使用的当前（旧）tss、新tss和所有段描述符是否被分页到系统内存中。
6.  将当前（旧）任务的状态保存在当前任务的tss中。处理器在任务寄存器中找到当前tss的基地址，然后将以下寄存器的状态复制到当前tss中：所有通用寄存器、段寄存器中的段选择符、临时保存的eflags寄存器图像和指令指针寄存器（eip）。
7.  使用新任务的 tss 的段选择符和描述符加载任务寄存器。
8. 翻译：tss 状态被加载到处理器中。这包括 ldtr 寄存器、pdbr（控制寄存器 cr3）、eflags 寄存器、eip 寄存器、通用寄存器和段选择器。如果在加载此状态期间出现故障，可能会破坏体系结构状态。（如果未启用分页，将从新任务的 tss 中读取 pdbr 值，但不会加载到 cr3 中。）
9. 如果使用 jmp 或 iret 指令发起任务切换，则处理器会清除当前（旧）任务 tss 描述符中的忙碌（b）标志；如果使用 call 指令、异常或中断发起，则忙碌（b）标志保持设置。（请参见表 8-2。）
10. 如果使用 iret 指令发起任务切换，则处理器会清除一张暂时保存的 eflags 寄存器图像中的 nt 标志；如果使用 call 或 jmp 指令、异常或中断发起，则 nt 标志在保存的 eflags 图像中保持不变
11. **如果使用call指令、异常或中断发起任务切换**，则处理器将从新任务加载的eflags中设置nt标志。如果使用iret指令或jmp指令发起，则nt标志将反映从新任务加载的eflags中的nt状态（参见表8-2）。
12.  如果使用call指令、jmp指令、**异常或中断发起任务切换**，则处理器将在新任务的tss描述符中设置忙碌（b）标志；如果使用iret指令发起，则保持忙碌（b）标志。
13.  与段选择器相关联的描述符被加载和确认。与此加载和确认相关的任何错误都会发生在新任务的上下文中，并可能破坏体系结构状态。

在成功切换任务时，当前正在执行的任务的状态总是会被保存。如果重新启动任务，则执行从保存的 EIP 值所指示的指令开始，并且寄存器将被恢复为任务暂停时的值。
在切换任务时，新任务的特权级不会继承自已挂起的任务。新任务将以加载自 TSS 的 CS 寄存器中的 CPL 字段中指定的特权级开始执行。由于任务由它们各自的地址空间和 TSS 隔离，并且由特权规则控制对 TSS 的访问，因此软件不需要对任务切换执行显式特权检查。
表 8-1 显示了处理器在切换任务时*检查的异常条件*。它还显示了如果检测到错误，则每个检查会生成哪个异常以及引用错误代码的段。（该表中检查的顺序是 P6 家族处理器使用的顺序。确切的顺序是型号特定的，并且可能对其他 IA-32 处理器有所不同。）设计用于处理这些异常的异常处理程序可能会受到递归调用的影响，如果它们尝试重新加载生成异常的段选择器，则会发生。在重新加载选择器之前，应修复异常的原因（或多个原因中的第一个）。
每次发生任务切换时，控制寄存器 CR0 中的 TS（任务切换）标志都会被设置。系统软件使用 TS 标志来协调浮点单元在生成浮点异常时与处理器的其余部分的操作。TS 标志指示浮点单元的上下文可能与当前任务不同。有关 TS 标志的功能和用法的详细描述，请参见“控制寄存器”一节。
# 4. 任务链
TSS 的先前任务链接字段（有时称为“后向链接”）和 EFLAGS 寄存器中的 NT 标志用于将执行返回到先前的任务。
EFLAGS. NT = 1 表示当前执行的任务嵌套在另一个任务的执行中。
当 CALL 指令、中断或异常引起任务切换时，处理器将当前 TSS 的段选择器复制到新任务的 TSS 的先前任务链接字段中，然后设置 EFLAGS. NT = 1。
如果软件使用IRET指令来暂停新任务，则处理器会检查EFLAGS.NT = 1；然后使用先前任务链接字段中的值返回到先前的任务。请参见图8-8。当JMP指令导致任务切换时，新任务不是嵌套的。先前任务链接字段不会被使用，而EFLAGS.NT = 0。在不需要嵌套的情况下，使用JMP指令来调度新任务。

![](images/Pasted%20image%2020230430170008.png)
# 5. 任务地址空间
任务的地址空间由任务可以访问的段组成。这些段包括在 TSS 中引用的代码、数据、堆栈和系统段，以及任务代码访问的任何其他段。这些段被映射到处理器的线性地址空间中，然后再映射到处理器的物理地址空间中（直接映射或通过分页）。

TSS中的LDT段字段可用于为每个任务提供其自己的LDT。给予任务自己的LDT可以将与任务相关的所有段描述符放置在任务的LDT中，从而将任务地址空间与其他任务隔离开来。同时，也可以有多个任务使用相同的LDT。这是一种内存有效的方法，可以允许特定任务相互通信或控制，而不会降低整个系统的保护屏障。

因为所有任务都可以访问 GDT，所以也可以通过在该表中的段描述符访问共享段来创建共享段。如果启用了分页，那么 TSS 中的 CR3 寄存器（PDBR）字段允许每个任务拥有自己的页面表，用于将线性地址映射到物理地址。或者，几个任务可以共享同一组页面表。

## 5.1 任务映射到线性地址空间和物理地址空间
将任务映射到线性地址空间和物理地址空间可以通过以下两种方式之一实现： 
* 所有任务共享一个线性到物理地址空间映射。-当未启用分页时，这是唯一的选择。没有分页时，所有线性地址映射到相同的物理地址。当启用分页时，使用一个页面目录供所有任务使用，可以获得这种形式的线性到物理地址空间映射。如果支持按需分页虚拟内存，则线性地址空间可能超出可用的物理空间。
* 每个任务都有自己的线性地址空间，映射到物理地址空间。-通过为每个任务使用不同的页面目录来实现这种映射。因为 PDBR（控制寄存器 CR3）在任务切换上被加载，所以每个任务可以有一个不同的页面目录。

不同任务的线性地址空间可以映射到完全不同的物理地址。如果不同页面目录的条目指向不同的页表，并且页表指向物理内存的不同页面，则任务不共享物理地址。
使用任何一种任务线性地址空间映射方法，所有任务的 TSS 都必须位于物理空间的共享区域中，该区域对所有任务都是可访问的。必须进行此映射，以便在处理器在任务切换期间读取和更新 TSS 时，TSS 地址的映射不会更改。 GDT 映射的线性地址空间也应映射到物理空间的共享区域；否则，GDT 的目的就会失败。图 8-9 显示了两个任务的线性地址空间如何通过共享页表在物理空间中重叠。
![](images/Pasted%20image%2020230430170542.png)

## 任务的逻辑地址空间
将任务逻辑地址空间映射到物理地址空间，可以使用以下技术创建共享的逻辑到物理地址空间映射： 
- 通过 GDT 中的段描述符-所有任务必须能够访问 GDT 中的段描述符。如果 GDT 中的某些段描述符指向线性地址空间中映射到所有任务共享的物理地址空间区域的段，则所有任务可以共享这些段中的数据和代码。
- 通过共享的 LDT-如果两个或多个任务使用相同的 LDT，那么它们可以共享该 LDT。如果共享 LDT 中的某些段描述符指向映射到物理地址空间的公共区域的段，那么这些段中的数据和代码可以在共享同一 LDT 的任务之间共享。这种共享方法比通过 GDT 共享更加有选择性，因为共享可以限制在特定任务之间进行。系统中的其他任务可能具有不同的 LDT，这些 LDT 不能使它们访问共享段。
- 通过映射到线性地址空间中公共地址的不同 LDT 中的段描述符-如果每个任务的线性地址空间的这个公共区域映射到物理地址空间的相同区域，则这些段描述符允许任务共享段。这种段描述符通常称为别名。这种共享方法甚至比上述方法更具选择性，因为 LDT 中的其他段描述符可能指向不共享的独立线性地址。
