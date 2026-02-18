
## 1. `ConcurrentHashMap` 是什么
- `ConcurrentHashMap` 是 Java 并发包（`java.util.concurrent`）中的一个线程安全的哈希表实现。
- 主要用来替代 `HashMap`（非线程安全）或 `Hashtable`（线程安全但效率低下）。
- **特点**：在高并发场景下提供 **高性能的线程安全访问**

---

## 2. 使用场景

- 多线程环境下需要共享访问和修改 `Map` 的场合，比如：
    
    - 缓存（Cache）
    - 任务调度器中的任务注册表
    - 在线用户管理表
    - IoC 容器中 bean 的注册表

**为什么用它而不是其他？**

- `HashMap` 在多线程下会出问题（扩容时可能导致死循环）。
- `Hashtable` 对所有操作加 `synchronized`，粒度太粗，性能差。
- `ConcurrentHashMap` 提供了更细粒度的并发控制，读操作基本无锁，写操作冲突概率低。
    

---

## 3. 核心方法（部分）

|方法|行为|
|---|---|
|`get(key)`|高效的读操作（无锁或极低锁开销）。|
|`put(key, value)`|插入或更新，必要时触发扩容。|
|`remove(key)`|删除键值对。|
|`computeIfAbsent(key, f)`|若 key 不存在则执行函数插入。|
|`forEach`、`reduce`|内置并行操作（JDK 8+）。|

---

## 4. 实现原理

### HashMap实现原理:
内部维护一个bucket数组（初始length是8），每个bucket内是相同哈希值对应的元素的链表
插入一个元素：
- 若槽位为空，直接插入。
- 若槽位有元素：
    - key 相同 → 覆盖 value；
    - key 不同 → 插入链表尾部；链表超过阈值 → 转红黑树。



1. 哈希值高位参加运算
```java
static final int spreaHash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
}
```
很多 key 的哈希值低位分布不均（例如自增 id），所以要让高位也参与 bucket 索引的计算。
- `h ^ (h >>> 16)`：让高 16 位和低 16 位混合，增加低位的随机性。
- 减少哈希冲突，使元素分布更均匀。


2. hash获取bucket index

`index = (n - 1) & hash` （位运算比取模快）
index是该key 哈希后对应的bucket的索引


3. 扩容机制的优化

buckets数组长度是2的倍数，每次扩容，长度x2 即*length的二进制表示会在高位多出1bit*
- 当容量从 `length` 扩展为 `2 * length` 时，实际上只是 **增加了 1 个高位 bit**。

    - 例如 `length = 16 (10000b)` → `length = 32 (100000b)`。
- 旧索引计算公式：
    `oldIndex = (length - 1) & hash;`
- 新索引计算公式：
    `newIndex = (2*length - 1) & hash;
- 由于 `2*length = length << 1`，所以新的掩码比旧掩码多了一个 **高位 bit**。
- **因此：扩容时元素要么留在原 bucket，要么移动到“原索引 + oldLength” 的位置**。

举例：
- 原来 `length = 16`，index = `hash & 0b1111`。
- 扩容后 `length = 32`，index = `hash & 0b11111`。
- 结果：
    - 如果新增的 bit = 0 → 元素仍在原位置；
    - 如果新增的 bit = 1 → 元素迁移到“原位置 + 16”。

扩容时不需要完全重新计算 hash → 只需判断 **高位 bit 是 0 还是 1**，直接决定是留在原 bucket 还是移动到新 bucket。

### JDK 7 实现

- **分段锁（Segment Locking）**
    
    - 整个 Map 被分成若干段（Segment），每个 Segment 内部维护一个小型的 HashMap。
    - 每个 Segment 有独立的 `ReentrantLock`。
    - 多个线程访问不同 Segment 时可以并行执行。
    - 但 Segment 数量固定，扩展性有限。

---

### JDK 8 实现

- 放弃 Segment，采用 CAS + synchronized + Node 数组 + 红黑树：
    
    1. 存储结构：等同HashMap，但不能存放null
        - 底层是 `Node<K,V>[] table`，类似 `HashMap`。
        - 冲突时采用链表/红黑树（同 `HashMap` 8+）。

    2. 并发控制：
        - **读操作（get）**：无锁，直接读 volatile 变量。     —— fastpath
        - **写操作（put/remove）**：
            - 首次插入某个 bin 时，用 **CAS** 创建新链表。     —— *fastpath* 没有哈希冲突
            - 如果 bin 已存在，使用 `synchronized` 锁住 bin 头节点进行插入/删除。 —— *slowpath*
        - **动态扩容（resize）**：多线程协作，线程帮忙迁移数据。

    3. **树化**：当某个桶链表长度超过阈值（8），转为红黑树，提高查询效率。


---

## 5. 工作机制总结

- **读多写少场景下性能优异**（无锁读操作）。
- **写操作冲突粒度小**（只锁住某个桶，而不是整个表）。
- **扩容时多个线程可以并发搬迁桶，避免单线程扩容瓶颈**。
    

---

## 6. 示例代码

```java
import java.util.concurrent.*;

public class CHMExample {
    public static void main(String[] args) {
        ConcurrentHashMap<String, Integer> map = new ConcurrentHashMap<>();

        // put
        map.put("apple", 1);

        // get
        System.out.println(map.get("apple"));

        // computeIfAbsent
        map.computeIfAbsent("banana", k -> 2);

        // 多线程安全访问
        ExecutorService pool = Executors.newFixedThreadPool(4);
        for (int i = 0; i < 10; i++) {
            int finalI = i;
            pool.submit(() -> map.put("key" + finalI, finalI));
        }
        pool.shutdown();
    }
}
```

---







## 7. 对比表

| 特性   | HashMap   | Hashtable | ConcurrentHashMap |
| ---- | --------- | --------- | ----------------- |
| 线程安全 | ❌         | ✅（全表锁）    | ✅（分桶/局部锁+CAS）     |
| 性能   | 高（单线程）    | 低（全锁）     | 高（多线程）            |
| 底层结构 | 数组+链表/红黑树 | 同上        | 数组+链表/红黑树         |
| 适用场景 | 单线程       | 简单多线程（过时） | 并发编程              |

---

✅ **一句话总结**：  
`ConcurrentHashMap` 是高效的线程安全哈希表，在 **高并发读写场景** 下是首选，内部通过 **CAS + synchronized（桶级锁）+ 红黑树优化 + 并行扩容** 来实现。
