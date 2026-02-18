### 概述（Overview）
 - 学一下锁的粒度
 - 原子操作 read、set、cas
- **并发transfer**  `ForwardingNode` => snapshot 快照机制 
- 暂不使用红黑树作为扩展
- 暂不使用分段计数器

### Hierarchy
![](ConcurrentHashMap_Hierarchy.png)
It implements `Serializable`(实现序列化), [`ConcurrentMap<K,​ V>`](https://www.geeksforgeeks.org/concurrentmap-interface-java/), [`Map<K,​ V>`](https://www.geeksforgeeks.org/map-interface-java-examples/) interfaces and extends  `AbstractMap<K, ​V>` class.
###  Data structure  

![83cd4c25ec514003a3dc6a747aa1c68b.png](https://ucc.alicdn.com/pic/developer-ecology/83cd4c25ec514003a3dc6a747aa1c68b.png?x-oss-process=image%2Fresize%2Cw_1400%2Fformat%2Cwebp)

- **存储结构**：`ConcurrentHashMap` 主要作为**桶（bucket）化的哈希表**，每个键值对存储在 `Node` 节点中。  
```java
/**
 * The array of bins. Lazily initialized upon first insertion.
 * Size is always a power of two. Accessed directly by iterators.
 */
transient volatile Node<K,V>[] table;

/**
 * The next table to use; non-null only while resizing.
 */
private transient volatile Node<K,V>[] nextTable;
```
- **节点类型**：  
  - **普通节点 `Node<K,V>`**：包含 `hash`、`key`、`value` 和 `next` 指针。  
  - **树节点  `TreeNode<K,V>`**：当桶中元素过多时，使用平衡树存储，而不是链表。  
  - **树根节点  `TreeBin<K,V>`**：用于管理 `TreeNode`，充当红黑树的根节点。  
  - **转发节点 `ForwardingNode<K,V>`**：在扩容（rehash）过程中，将桶的头结点替换为转发节点，以引导查询操作到新表。  
  - **预留节点 `ReservationNode<K,V>`**：用于 `computeIfAbsent()` 等方法，作为临时占位符。  

**特殊节点（`TreeBin`、`ForwardingNode`、`ReservationNode`）不会存储正常的键值对**，它们的 `hash` 值通常是负数，并且 `key`、`value` 为空，因此可以在搜索过程中轻松区分。

---
### 无锁读写
```java
static final <K,V> Node<K,V> tabAt(Node<K,V>[] tab, int i) {
    return (Node<K,V>)U.getObjectVolatile(tab, ((long)i << ASHIFT) + ABASE);
}
// 通过 CAS（比较并交换）操作原子性地更新哈希表中指定位置的节点。
static final <K,V> boolean casTabAt(Node<K,V>[] tab, int i,
                                    Node<K,V> c, Node<K,V> v) {
    return U.compareAndSwapObject(tab, ((long)i << ASHIFT) + ABASE, c, v);
}
static final <K,V> void setTabAt(Node<K,V>[] tab, int i, Node<K,V> v) {
    U.putObjectVolatile(tab, ((long)i << ASHIFT) + ABASE, v);
}
```
ABASE 和 ASHIFT 是在静态初始化时通过 Unsafe API 确定的，它们分别代表数组中第一个元素的内存基址和索引乘以元素大小对应的位移量。

具体来说：
- ABASE 是通过类似于  
      `ABASE = U.arrayBaseOffset(Node[].class)`
    取得的，它表示数组中第 0 个元素的偏移地址。
- ASHIFT 则由数组中单个元素占用的字节数（即 `U.arrayIndexScale(Node[].class) `返回的值）计算得到，通常计算公式为  
      `ASHIFT = 31 - Integer.numberOfLeadingZeros(scale)  `
    这样就可以用“(long)i << ASHIFT + ABASE”方式快速计算第 i 个元素的内存地址。

这两个值是在*类加载*时、静态初始化块中确定的，与构造函数无关，即在类加载时就已经固定下来。
[JVM 类加载](JVM%20类加载.md)

### sizeCtl 控制
```java
/* 表初始化和调整大小控制。当为负数时，表示表正在初始化或调整大小：-1表示初始化，
 * 否则为-(1 + active resizing线程的数量)。否则，当表为空时，保存创建时使用的初始表大小，
 * 或0表示默认值。初始化后，保存下一个元素计数值，在该值上调整表的大小。
 */
private transient volatile int sizeCtl;
/**
 * The next table index (plus one) to split while resizing.
 */
private transient volatile int transferIndex;
/**
 * Spinlock (locked via CAS) used when resizing and/or creating CounterCells.
 */
private transient volatile int cellsBusy;
```
### Node哈希值处理
- `Node` 的 `hash` 字段的最高位（符号位）用于特殊控制：  
  - 负值：代表该节点是 `ForwardingNode` （-1）或 `TreeBin`（-2）。  
  - 负值节点需要特殊处理，在 `map` 方法中通常被忽略或执行特定逻辑。  

```java
static class Node<K,V> implements Map.Entry<K,V> {
final int hash;
final K key;
volatile V val;
volatile Node<K,V> next;

Node(int hash, K key, V val, Node<K,V> next) {
    this.hash = hash;// !!!!!
    this.key = key;
    this.val = val;
    this.next = next;
}

public final K getKey()       { return key; }
public final V getValue()     { return val; }
public final int hashCode()   { return key.hashCode() ^ val.hashCode(); }
public final String toString(){ return key + "=" + val; }
public final V setValue(V value) {
    throw new UnsupportedOperationException();
}

public final boolean equals(Object o) {
    Object k, v, u; Map.Entry<?,?> e;
    return ((o instanceof Map.Entry) &&
            (k = (e = (Map.Entry<?,?>)o).getKey()) != null &&
            (v = e.getValue()) != null &&
            (k == key || k.equals(key)) &&
            (v == (u = val) || v.equals(u)));
}
```
在 HashMap 中，由于底层数组的长度通常为 2 的幂，所以计算桶索引时会用到位运算 index = hash & (table.length - 1); 这意味着只有哈希值的低位才会影响到最终的索引。如果哈希函数产生的高位信息与低位信息没有充分混合，那么一部分本应有区分度的高位信息就“浪费”了，容易导致哈希冲突（特别是在某些场景下，例如 Float 类型连续的整数值）。为了解决这个问题，就需要对原始哈希值做一个“扰动”或“扩散”处理，将高位的信息通过一定算法影响到低位，从而得到更加均匀的分布。 比如：
```java
// 计算 Node hash 哈希值：将原始哈希码 key.hashCode() 的高低位混合，减少哈希冲突
static final int spread(int h) {
    return (h ^ (h >>> 16)) & HASH_BITS;// 高位参与运算，HASH_BITS为Int最大值，与运算用于屏蔽负数标记
}
```
拿这个值记录在买个Node的hash属性里，作为计算拿取bucket的index的关键。比原本直接hashcode计算降低哈希冲突频率。
![](QQ_1743044633035.png)
用`(tab.length-1)&spread(key.hashCode())`  获得该key的hash值对应的桶的索引



---

### 插入策略
#### putval逻辑
```java
final V putVal(K key, V value, boolean onlyIfAbsent){
int hash = spread(key.hashCode()); //  先对key的hashcode进行处理获得hash值
int binCount = 0;
for (Node<K,V>[] tab = table;;) {
	Node<K,V> f; int n, i, fh;
```
1.  **懒初始化（Lazy Initialization）**  
- `table` 数组在第一次插入数据`putval`时才被初始化，并且长度为**2 的幂次**。  
- 每个桶（bin）通常包含一个 `Node` 链表（大多数情况下长度为 0 或 1）。  
- 由于 `table` 需要支持高并发访问，因此对其的读写操作都使用了**volatile/原子操作（CAS）**，并依赖 `sun.misc.Unsafe` 进行底层优化。  
```java
if (tab == null || (n = tab.length) == 0)
	tab = initTable();
```
2. **空桶的插入（无锁 CAS）**  **最常见情况**
   - 如果目标桶为空，则直接使用 `CAS`（Compare-And-Swap）操作将其插入。  
   - 在多数情况下，这是 `put()` 操作的**最常见情况，性能最高**。 

> //我理解一个Node的节点大小是固定的，这块我们可以用Atomics实现不加锁方案吗
```java
else if ((f = tabAt(tab, i = (n - 1) & hash)) == null) { //原子读该节点为null
    if (casTabAt(tab, i, null,
                 neNode<K,V>(hash, key, value, null)))
        break;                   // no lock when adding to empty bin
}
```
3. 如果是在**扩容** //我们是否要做Java这套扩容体系
```java
else if ((fh = f.hash) == MOVED)
	tab = helpTransfer(tab, f);
```
4. **非空桶的插入（需要加锁）**  
   - **插入、删除和更新** 需要锁定桶。  
```java
else {
V oldVal = null;
synchronized (f) {
// 在加锁后，遍历 f 链表：
// 1. 寻找是否已经包含键 key，如果找到了，则更新对应的值
// 2. 否则，在链表末尾新增一个节点
    if (tabAt(tab, i) == f) { // 插入操作时，必须先检查该节点是否仍是桶的第一个节点，否则需要重新尝试。
        if (fh >= 0) {
            binCount = 1;
            for (Node<K,V> e = f;; ++binCount) {
                K ek;
                if (e.hash == hash &&
                    ((ek = e.key) == key ||
                     (ek != null && key.equals(ek)))) {
                    oldVal = e.val;
                    if (!onlyIfAbsent)
                        e.val = value;
                    break;
                }
                Node<K,V> pred = e;
                if ((e = e.next) == null) {
                    pred.next = new Node<K,V>(hash, key,
                                              value, null);
                    break;
                }
            }
        }
        else if ..
    }
	if ( binCount != 0) {
             if (binCount >= TREEIFY_THRESHOLD)// 超过8个，变红黑树
                 treeifyBin(tab, i);
             if (oldVal != null)
                 return oldVal;
             break;
         }
     }
 }// for循环结束
 addCount(1L, binCount); 
 // 增/减数量
 // （1）addCount()更新元素总数时，发现元素总数超过扩容阈值； 触发扩容
 return null;
```
   注意：`ConcurrentHashMap` **不使用独立的锁对象**，而是**使用桶列表的第一个节点`MapNode`作为锁对象**，并依赖 `synchronized` 进行同步，锁住第一个节点，之后对该条链表的修改进行同步。  
   > [!synchronized] 
   > synchronized 关键字用于获取对象 f 的内置锁（monitor），从而保证在进入同步代码块的时候只有一个线程能执行该块内的代码。也就是说，只有获得 f 锁的线程可以对 f 对应的关联数据结构（比如链表桶内节点）的状态进行修改，其它试图访问该代码块的线程会被阻塞，直到当前线程退出同步块并释放锁。
   > 背后的机制是 JVM 内置的对象监视器，通过字节码指令 monitorenter 和 monitorexit 实现，确保进入同步块前写入的修改对后续的所有线程都是可见的，从而达到线程安全和内存可见性的效果。

 插入操作时，必须先检查该节点是否仍是桶的第一个节点，否则需要重新尝试。  
   ```java
   if (tabAt(tab, i) == f)
   ...
   else if (f instanceof TreeBin)
   ```
   由于新节点总是追加到链表末尾，**因此一旦某个节点成为桶的头部，它会保持头部状态，直到被删除或发生扩容**。  (对呀，不要频繁地改变头结点)

#### addCount 逻辑
```java
private final void addCount(long x, int check) {
    CounterCell[] as; long b, s;
    if ((as = counterCells) != null ||
    	!U.compareAndSwapLong(this, BASECOUNT, b = baseCount, s = b + x)){
        ... //计数逻辑 ...
    }
    if (check >= 0) {    // 数量是增大的时候检查并触发扩容 
        Node<K,V>[] tab, nt; int n, sc;
        while (s >= (long)(sc = sizeCtl) && //元素总数超过阈值sizeCtl,在上次扩容时确定 2n*0.75
                (tab = table) != null &&
               (n = tab.length) < MAXIMUM_CAPACITY) { // 未达最大容量
            // 生成扩容标识
            int rs = resizeStamp(n) << RESIZE_STAMP_SHIFT;
            // sizeCtl小于0，已有其他线程在扩容
            if (sc < 0) { // 说明当前正在扩容
               // 检查扩容是否已完成或协助线程数已达上限（避免过度竞争）
                if ((sc >>> RESIZE_STAMP_SHIFT) != rs ||  // 检查 sc 是否匹配当前的扩容标记
                    sc == rs + MAX_RESIZERS || // 协助线程数是否超限
                    sc == rs + 1 || // 扩容已完成（线程数归零）
                    (nt = nextTable) == null || // 没有新的表，扩容终止
                    transferIndex <= 0)   // 所有桶都已经被转移
                    break;
                // 尝试通过 CAS 增加协助线程数（sizeCtl +1）
                if (U.compareAndSwapInt(this, SIZECTL, sc, sc + 1))
                    transfer(tab, nt);  // 继续数据迁移
            }
            // 当前无扩容，尝试发起新扩容，SIZECTL 低十六位存储扩容线程数，初始设置为2（= 扩容线程数1 + 1），后续扩容完成则是0+1=1，对应上面 sc == rs + 1 判断扩容是否已完成
            else if (U.compareAndSwapInt(this, SIZECTL, sc, rs + 2))
                transfer(tab, null);  // 触发扩容
            ...
        }
    }
}
```
- **`sc`（sizeCtl）**：  
    `sizeCtl` 变量用于控制表的大小和扩容行为。
    - 如果 `sizeCtl` > 0，则表示下一次需要扩容的阈值（即 `threshold`）。
    - 如果 `sizeCtl` < 0，则表示当前正在进行扩容，值的不同表示扩容的状态。例如，它可能包含 `resizeStamp(n)` 和扩容线程的计数信息。
- **`rs`（resizeStamp）**：  
    `resizeStamp(n)` 是一个哈希标记，用于标识当前的扩容阶段，以防止不同大小的表在扩容时发生冲突。
    - `resizeStamp(n)` 计算出来的值会嵌入 `sizeCtl` 的高位，以区分不同的扩容阶段。


---

### **扩容（Resizing）**  
![](QQ_1753085076051.png)
- **触发条件**：当哈希表的负载因子超过 0.75 时，触发扩容。  
- **扩容方式**：
  - **协作式扩容**：发现需要扩容的线程会创建一个新的 `table`，并使用 `ForwardingNode` 作为占位符，其他线程可以协助搬移数据。  
  - **转移策略**：
    - 采用 `transferIndex` 变量，允许多个线程分批次迁移数据，减少锁争用。  
    - 迁移时，元素要么保持原索引，要么移动到 `原索引 + 旧容量` 位置（因为新容量是旧容量的 2 倍）。  
    - **减少对象创建**：如果节点的 `next` 指针不变，则直接复用，而不会创建新节点，减少 GC 压力。  
    - **转发节点 `MOVED`**：迁移完成后，旧表的桶被替换为 `ForwardingNode`，指向新 `table`，后续查询会自动重定向到新表。  
  - **迁移顺序**：  
    - 迁移是从 **table 末尾向前** 进行的，以便遍历过程中能正确处理 `ForwardingNode`。  


*  当表的占用率超过某个百分比阈值（通常为0.75，但见下文）时，表会进行扩容。
* 任何线程发现某个桶过满时，可以在发起扩容的线程分配并设置好新数组后协助进行扩容。
* 然而，这些其他线程不会阻塞，而是可以继续进行插入等操作。使用TreeBin可以在扩容过程中避免最坏情况下的过度填充影响。
* 扩容通过逐个将桶从旧表转移到新表来进行。然而，线程在转移之前会先声明一小块索引范围（通过字段transferIndex），从而减少竞争。
* **字段sizeCtl中的生成标记确保扩容操作不会重叠。由于我们使用2的幂次方进行扩展，每个桶中的元素要么保持在相同的索引位置，要么以2的幂次方偏移量移动。**
* 我们通过捕获旧节点可以重用的情况来避免不必要的节点创建，因为它们的next字段不会改变。平均而言，当表容量翻倍时，只有大约六分之一的节点需要克隆。
* 它们替换的节点将fre在不再被任何可能正在并发遍历表的读线程引用后立即被垃圾回收。
* 在转移过程中，旧表的桶中只包含一个特殊的转发节点（其哈希字段为“MOVED”），该节点将新表作为其键。遇到转发节点时，访问和更新操作会重新开始，使用新表进行操作。


#### 核心函数 `transfer`
```java
private final void transfer(Node<K,V>[] tab, Node<K,V>[] nextTab) {
    int n = tab.length, stride;
    //static final int NCPU = Runtime.getRuntime().availableProcessors();
    // 计算迁移步长 stride 个线程处理的桶区间大小 stride（最小为 MIN_TRANSFER_STRIDE=16）
    if ((stride = (NCPU > 1) ? (n >>> 3) / NCPU : n) < MIN_TRANSFER_STRIDE)
        stride = MIN_TRANSFER_STRIDE; // 保证最小迁移步长

    // 如果 nextTab 为空，则初始化一个新的更大的数组
    if (nextTab == null) {
        try {
            @SuppressWarnings("unchecked")
            Node<K,V>[] nt = (Node<K,V>[])new Node<?,?>[n << 1];// 扩容为数组原来大小两倍
            nextTab = nt;
        } catch (Throwable ex) { // 处理内存溢出异常
            sizeCtl = Integer.MAX_VALUE;
            return;
        }
        this.nextTable = nextTab; // 记录新表
        transferIndex = n; // 初始化迁移索引
    }
    int nextn = nextTab.length;
     // 创建 ForwardingNode 扩容
    ForwardingNode<K,V> fwd = new ForwardingNode<K,V>(nextTab); // 标记已迁移的节点
    boolean advance = true; // 标记是否继续分配任务
    boolean finishing = false; // 迁移完成标志
    // 开始分配任务并迁移数据
    for (int i = 0, bound = 0;;) {
        Node<K,V> f; int fh;
        // ------------------------ 不同线程竞争桶区间分配任务 ------------------------
        while (advance) { // 计算要迁移的桶索引
            int nextIndex, nextBound;
            // 当前区间未处理完 或 迁移已完成, 退出循环
            if (--i >= bound || finishing)
                advance = false;
            // transferIndex <= 0 无剩余任务，后续退出迁移
            else if ((nextIndex = transferIndex) <= 0) { // 迁移完成
                i = -1;
                advance = false;
            
			 // CAS竞争任务区间（transferIndex从nextIndex更新为nextBound）
        	else if (U.compareAndSwapInt
                 	(this, TRANSFERINDEX, nextIndex,
                  	// 每个线程处理的桶区间大小 stride，往前推进
                  	nextBound = (nextIndex > stride ?
                               	nextIndex - stride : 0))) {
            	// 竞争区间 [bound, i] 处理这个区间的扩容迁移任务
            	bound = nextBound;
            	i = nextIndex - 1;
            	advance = false;
        	}
    	}
    
    
		// ------------------------ 迁移完成检查 ------------------------
        if (i < 0 || i >= n || i + n >= nextn) {
            int sc;
            if (finishing) { // 迁移完成，更新表
                this.nextTable = null;
                this.table = nextTab;
                sizeCtl = (n << 1) - (n >>> 1); // 计算新的扩容阈值
                return;
            }
             // CAS减少协助线程数
            if (U.compareAndSwapInt(this, SIZECTL, sc = sizeCtl, sc - 1)) {
                // 若自己是最后一个线程，触发最终检查
                if ((sc - 2) != resizeStamp(n) << RESIZE_STAMP_SHIFT)
                    return;
                finishing = advance = true;
                i = n; // recheck before commit
            }
        }
        else if ((f = tabAt(tab, i)) == null)
            advance = casTabAt(tab, i, null, fwd); // 迁移空桶
            //ForwardingNode<K,V> fwd = new ForwardingNode<K,V>(nextTab);
        else if ((fh = f.hash) == MOVED)
            advance = true; // 该桶已迁移
        else {
        // ------------------------ 迁移 ------------------------
            synchronized (f) { // 加锁迁移
                if (tabAt(tab, i) == f) {// 二次校验防止并发修改
                    Node<K,V> ln, hn;
                     // f.hash >= 0 处理链表节点
                    if (fh >= 0) { // 处理普通链表
                    // 通过 runBit 和 lastRun 快速分割链表，避免逐个节点重新散列。
                    // 这里为什么是 fh & n? 详见下述解释
                        int runBit = fh & n//计算散列位（0或n）,判断低位ln还是扩容后的高位hn
                        Node<K,V> lastRun = f;
                        // 遍历链表，找到最后一段连续相同散列位的节点，主要目的是直接复用 lastRun 之后的节点，减少新建节点开销
                        for (Node<K,V> p = f.next; p != null; p = p.next) {
                            int b = p.hash & n;
                            if (b != runBit) {
                                runBit = b;
                                lastRun = p;
                            }
                        }
                         // lastRun 是低位元素
                        if (runBit == 0) {
                            ln = lastRun;
                            hn = null;
                        }
                        // lastRun 是高位元素
                        else {
                            hn = lastRun;
                            ln = null;
                        }
                        // 迁移 lastRun 之前的节点，到 扩容后的高位/原低位
                        for (Node<K,V> p = f; p != lastRun; p = p.next) {
                            int ph = p.hash; K pk = p.key; V pv = p.val;
                            // 低位迁移
                            if ((ph & n) == 0)
                                ln = new Node<K,V>(ph, pk, pv, ln);
                            else
                                hn = new Node<K,V>(ph, pk, pv, hn);
                        }
                        setTabAt(nextTab, i, ln); // 原位i
                        setTabAt(nextTab, i + n, hn); // 偏移i+n
                        setTabAt(tab, i, fwd); // 标记旧桶为已迁移
                        advance = true;
                    }
                    else if (f instanceof TreeBin) { // 处理红黑树
                        ...
                    }
                }
            }
        }
    }
}

```
runBit 为什么是通过 int runBit = fh & n   来作为切割依据? 
容量是2的幂时，计算key的桶位置是用位操作，即通过 hash & (n-1) 确定的，

假设原容量是n=16，二进制是10000，n-1=1111。此时hash & 1111得到的是0到15的位置。

扩容后的容量是32，二进制是100000，n-1=11111。新的位置是hash & 11111，也就是0到31。

原来的位置是 hash & 1111，而新的位置可能是原来的位置或者原来的位置+16（例如，如果hash的第5位是1的话，如10010，则这个必然在高位）。所以新的位置其实是原位置或者原位置加n。这时候，只需要判断hash的某一位是否为1，就能确定节点应该放在原位还是高位。具体来说，这个位就是n对应的二进制位。

比如，n=16时，二进制是10000，所以检查hash的第5位是否为1，如果是，则新位置是原位置+16，否则保持原位。

`ForwardingNode` 内部类表示迁移节点，可通过 **nextTable**访问新数组。
```java
static final class ForwardingNode<K,V> extends Node<K,V> {
    final Node<K,V>[] nextTable; // 指向新表的引用
    // 需要指定扩容后的新数组 nextTable
    ForwardingNode(Node<K,V>[] tab) {
        super(MOVED, null, null, null);
        this.nextTable = tab;
    }
	// 迁移节点查找，去访问新数组 nextTable  而不是旧数组
    Node<K,V> find(int h, Object k) {// h是spread后的哈希值，k是key
        // loop to avoid arbitrarily deep recursion on forwarding nodes
        outer: for (Node<K,V>[] tab = nextTable;;) {
            Node<K,V> e; int n;
            if (k == null || tab == null || (n = tab.length) == 0 ||
                (e = tabAt(tab, (n - 1) & h)) == null)
                return null;
            for (;;) {
                int eh; K ek;
                if ((eh = e.hash) == h &&
                    ((ek = e.key) == k || (ek != null && k.equals(ek))))
                    return e;
                if (eh < 0) {
                    if (e instanceof ForwardingNode) {
                        tab = ((ForwardingNode<K,V>)e).nextTable;
                        continue outer;
                    }
                    else
                        return e.find(h, k);
                }
                if ((e = e.next) == null)
                    return null;
            }
        }
    }
}
```


####  `helptransfer`

---

### **读操作的优化**  `get`
根据传入的 key 返回对应的 value，如果该 key 没有映射则返回 `null`。同时，如果传入 key 为 null，会抛出 `NullPointerException`（这也是 HashMap 的一个设计要求，虽然部分 Map 实现允许 null 键，但 HashMap 在此处要求不允许）。
- **只读操作（如 `get()`）不会加锁**，依赖 `volatile` 修饰的 `Node.val` 和 `Node.next` 保证可见性，即使在扩容过程中仍然可以读取旧表的数据。  
- **遍历优化**：  
  - 使用 `TableStack` 结构维护遍历位置，减少内存分配和 GC 开销。  
- **扩容兼容性**：若遇到 `ForwardingNode`，通过其 `find()` 方法在新数组中查找数据

```java
public V get(Object key) {
    Node<K,V>[] tab; Node<K,V> e, p; int n, eh; K ek;
    int h = spread(key.hashCode());
    if ((tab = table) != null && (n = tab.length) > 0 &&
        (e = tabAt(tab, (n - 1) & h)) != null) {
        if ((eh = e.hash) == h) {
            // 头节点匹配直接返回
            if ((ek = e.key) == key || (ek != null && key.equals(ek)))
                // 无锁读取
                return e.val;
        }

        // 处理特殊节点（如红黑树或 ForwardingNode）
        else if (eh < 0)
            // 调用红黑树或扩容节点的查找逻辑
            return (p = e.find(h, key)) != null ? p.val : null;
        // 头节点不匹配，链表读取
        while ((e = e.next) != null) {
            if (e.hash == h &&
                ((ek = e.key) == key || (ek != null && key.equals(ek))))// 命中链表中的某个节点
                return e.val;
        }
    }
    return null;
}
```


### remove/replace
主要流程：

（1）通过 _spread 通过原始hash code_ 计算哈希 `hash`，让高位16位也参与计算确保哈希均匀分布；
（2）根据Hash查找对应的桶位置 `(n - 1) & hash`, 若没有返回 null；
（3）若当前桶位置正在扩容，协助迁移数据`helpTransfer`后重试；
（4）加锁处理链表/树，匹配键值，删除节点；
（5）更新元素总数-1；
```java
public V remove(Object key) {
    return replaceNode(key, null, null);
}
/**
 * {@inheritDoc}
 *
 * @throws NullPointerException if the specified key is null
 */
public boolean remove(Object key, Object value) {
    if (key == null)
        throw new NullPointerException();
    return value != null && replaceNode(key, null, value) != null;
}

/**
 * {@inheritDoc}
 *
 * @throws NullPointerException if any of the arguments are null
 */
public boolean replace(K key, V oldValue, V newValue) {
    if (key == null || oldValue == null || newValue == null)
        throw new NullPointerException();
    return replaceNode(key, newValue, oldValue) != null;
}

/**
 * {@inheritDoc}
 *
 * @return the previous value associated with the specified key,
 *         or {@code null} if there was no mapping for the key
 * @throws NullPointerException if the specified key or value is null
 */
public V replace(K key, V value) {
    if (key == null || value == null)
        throw new NullPointerException();
    return replaceNode(key, value, null);
}

/**
 * Implementation for the four public remove/replace methods:
 * Replaces node value with v, conditional upon match of cv if
 * non-null.  If resulting value is null, delete.

 * cv: 非 null 时，只有旧值匹配 cv 时才操作
 */
final V replaceNode(Object key, V value, Object cv) {
    int hash = spread(key.hashCode());
    for (Node<K,V>[] tab = table;;) {
        Node<K,V> f; int n, i, fh;
        // 若表未初始化或桶为空，直接退出
        if (tab == null || (n = tab.length) == 0 ||
            (f = tabAt(tab, i = (n - 1) & hash)) == null)
            break;
        // 若桶正在扩容（MOVED状态），协助扩容后重试
        else if ((fh = f.hash) == MOVED)
            tab = helpTransfer(tab, f);
        else {
            V oldVal = null;
            boolean validated = false;
            // 加锁处理链表或树
            synchronized (f) {
                if (tabAt(tab, i) == f) {
                    // 链表处理
                    if (fh >= 0) {
                        validated = true;
                        for (Node<K,V> e = f, pred = null;;) {
                            K ek;
                            // 匹配键值
                            if (e.hash == hash &&
                                ((ek = e.key) == key ||
                                 (ek != null && key.equals(ek)))) {
                                V ev = e.val;
                                // cv若非空判断cv是否匹配
                                if (cv == null || cv == ev ||
                                    (ev != null && cv.equals(ev))) {
                                    oldVal = ev;
                                    if (value != null)
                                        e.val = value;// 替换值
                                    else if (pred != null)
                                        pred.next = e.next;// 删除中间节点
                                    else
                                        setTabAt(tab, i, e.next);// 删除头节点
                                }
                                break;
                            }
                            pred = e;
                            if ((e = e.next) == null)
                                break;
                        }
                    }
                    // 树处理逻辑
                    else if (f instanceof TreeBin) {
                        validated = true;
                        TreeBin<K,V> t = (TreeBin<K,V>)f;
                        TreeNode<K,V> r, p;
                        if ((r = t.root) != null &&
                            (p = r.findTreeNode(hash, key, null)) != null) {
                            V pv = p.val;
                            if (cv == null || cv == pv ||
                                (pv != null && cv.equals(pv))) {
                                oldVal = pv;
                                if (value != null)
                                    p.val = value;
                                else if (t.removeTreeNode(p))
                                    setTabAt(tab, i, untreeify(t.first));
                            }
                        }
                    }
                }
            }
            // 操作处理完成后，
            if (validated) {
                if (oldVal != null) {
                    if (value == null)
                        addCount(-1L, -1); // 若是删除，更新元素计数-1
                    return oldVal;
                }
                break;
            }
        }
    }
    return null;
}
```

### clear
对每个链表加锁去进行操作，而不是阻塞住其他get、has、set操作
```java
/**
 * Removes all of the mappings from this map.
 */
public void clear() {
    long delta = 0L; // negative number of deletions
    int i = 0;
    Node<K,V>[] tab = table;
    while (tab != null && i < tab.length) { // 每次检验判断一下tab是不是空
        int fh;
        Node<K,V> f = tabAt(tab, i);
        if (f == null)
            ++i;
        else if ((fh = f.hash) == MOVED) {
            tab = helpTransfer(tab, f);
            i = 0; // restart
        }
        else {
            synchronized (f) {
                if (tabAt(tab, i) == f) { // 需要后加锁的话，加锁后回验 index 还是不是那个index 这点很重要
                    Node<K,V> p = (fh >= 0 ? f :
                                   (f instanceof TreeBin) ?
                                   ((TreeBin<K,V>)f).first : null);
                    while (p != null) {
                        --delta;
                        p = p.next;
                    }
                    setTabAt(tab, i++, null);
                }
            }
        }
    }
    if (delta != 0L)
        addCount(delta, -1);
}
```



---

### ~~**LongAdder 计数器优化**~~    先不上，只是copy
- `ConcurrentHashMap` 维护 `size` 计数器，但为了避免竞争，使用了 **LongAdder** 的改进版 `CounterCell` 来减少冲突。  
- 在 `put()` 操作时，仅当某个桶已有 **2 个或更多节点** 时才检查是否需要扩容，避免频繁访问 `size` 计数器导致 CPU 缓存抖动（cache thrashing）。  

`baseCount` 是基础的计数器变量，但在高并发下频繁 CAS 更新会导致性能问题（可能导致U.compareAndSwapLong(this, BASECOUNT, b = baseCount, s = b + x) 频繁失败），因此引入 `CounterCell` 数组分散线程竞争。

例如，在jdk8的时候是有引入一个类Striped64，其中LongAdder和DoubleAdder就是对这个类的实现。这两个方法都是为解决高并发场景而生的。（是AtomicLong的加强版，AtomicLong在高并发场景性能会比LongAdder差。但是LongAdder的空间复杂度会高点）

ConcurrentHashMap 高并发下更新元素计数 的核心方法 fullAddCount _借鉴了 LongAdder 的分段计数思想_，避免所有线程竞争同一变量，分散到不同 `CounterCell` 槽位，减少 CAS 冲突。主要流程：

（1）未初始化_counterCells数组，**cas**加锁初始化数组并插入新的 `CounterCell（x）`；
（2-1）已初始化，若线程probe对应槽位上为空，cas加锁插入新的 `CounterCell（x）`；
（2-2）已初始化，若线程probe对应槽位上不为空，cas加锁更新 _`CounterCell（x）`_ 计数；
（3）若（2-2）更新失败表示存在冲突 `collide=true`，翻倍扩容数组，最大容量为 `NCPU`（与CPU核心数对齐）；
（4）兜底策略 - _当 CounterCell 初始化或扩容失败时，回退到无锁更新 baseCount；_


---
### **桶级别锁的影响**  

- **每个桶只能同时被一个线程修改**，但多个桶可以同时进行修改。  
- 由于 `equals()` 或映射函数的执行时间可能较长，锁竞争会导致某些插入或删除操作等待较长时间。  
- 但在理想情况下，**哈希分布均匀**，并且大多数桶中的节点数符合**泊松分布**（Poisson Distribution），因此冲突概率较低。  

泊松分布计算示例（λ ≈ 0.5）：  

| 链表长度 k | 发生概率       |
| ------ | ---------- |
| 0      | 0.60653066 |
| 1      | 0.30326533 |
| 2      | 0.07581633 |
| 3      | 0.01263606 |
| 4      | 0.00157952 |
| 5      | 0.00015795 |

通常情况下，桶的平均长度不会超过 2，避免了 HashMap 可能出现的性能下降问题。 

**锁冲突概率估算**：
- **如果两个线程访问不同的桶，锁冲突的概率大约为 `1 / (8 × 元素个数)`**。  
- **在极端情况下（大于 `2^30` 个元素），一定会发生哈希冲突**，这时将使用 `TreeBin` 进行优化。  

---

### **总结**  

1. **高效的桶级锁设计**：桶的头节点作为锁，保证高并发性能。  
2. **渐进式扩容**：使用 `ForwardingNode` 进行迁移，支持多线程协作扩容。  
3. **TreeBin 机制**：超过 `8` 个元素时转换为红黑树，优化查询速度。  
4. **读操作无锁**：使用 `volatile` 变量、CAS 操作，保证高效读取。  
5. **避免锁竞争**：通过 `LongAdder` 优化 `size` 统计，减少锁冲突。  

ConcurrentHashMap 通过这些优化，实现了**高并发、高效扩容、无锁读写优化**，适用于多线程环境下的高性能映射存储。



---
### ~~TreeBin 机制（红黑树优化）~~ 由于我们不搞，简单复制AI了

- 当某个桶中元素数量超过 `TREEIFY_THRESHOLD`（默认 8），则该桶会从链表转换为**红黑树**（`TreeBin`）。  
- 树的搜索复杂度从 **O(N)** 降至 **O(log N)**，提高查询效率。  
- 由于 `TreeBin` 允许 Comparable 作为键，因此可以进行高效的二叉搜索。如果键不是 `Comparable`，则通过 `identityHashCode()` 进行排序。  

---

Refer:
[吊打Java面试官之ConcurrentHashMap（线程安全的哈希表） | 二哥的Java进阶之路](https://javabetter.cn/thread/ConcurrentHashMap.html#jdk-1-7)
[【Java并发】源码级解读ConcurrentHashMap，妈妈再也不用担心我的学习\_哔哩哔哩\_bilibili](https://www.bilibili.com/video/BV1FX4y1g7uC/?spm_id_from=333.337.search-card.all.click&vd_source=33d3156975c92d1beb9e11e8b218f8b0) (1.7)



