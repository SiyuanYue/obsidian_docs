# .. 与For_each
```rust
(base_i..base_i + APP_SIZE_LIMIT)
            .for_each(|addr| unsafe { (addr as *mut u8).write_volatile(0) });
```
这段代码使用了一个范围迭代器 `..`，它的左端点为变量 `base_i` 的当前值，右端点为 `base_i + app_size_limit`。该迭代器遍历了从 `base_i` 开始，到 `base_i + app_size_limit - 1` 结束的整数序列。

`.for_each()` 是一个 高阶函数(higher-order function)，它将一个闭包(closure)应用于迭代器中的每个元素，也就是将内存地址(addr)强制转换为 `*mut u8` 类型的指针，并将其写入 `0x00` (即写入内存的最低位置，表示清零)。这里使用了 unsafe 关键字来表示这是一个不安全的操作，并且编译器需要对此进行特殊处理。由于直接操作内存会有潜在的风险，因此只能在需要时使用 unsafe 关键字进行标记。

因此，这段 rust 代码的作用是：将 `base_i` 和 `base_i + app_size_limit - 1` 之间的一块内存清零。

> **Rust 语法卡片：迭代器**
> `a..b` 实际上表示左闭右开区间 \[a, b)，在 Rust 中，它会被表示为类型 `core::ops::Range` ，标准库中为它实现好了 `Iterator` trait，因此它也是一个迭代器。
> 关于迭代器的使用方法如 `map/find` 等，请参考 Rust 官方文档。


> **Rust Tips：Drop Trait**
> Rust 中的 `Drop` Trait 是它的 RAII 内存管理风格可以被有效实践的关键。之前介绍的多种在堆上分配的 Rust 数据结构便都是通过实现 `Drop` Trait 来进行被绑定资源的自动回收的。例如：
> -   `Box<T>` 的 `drop` 方法会回收它控制的分配在堆上的那个变量；
> -   `Rc<T>` 的 `drop` 方法会减少分配在堆上的那个引用计数，一旦变为零则分配在堆上的那个被计数的变量自身也会被回收；
> -   `UPSafeCell<T>` 的 `exclusive_access` 方法会获取内部数据结构的独占借用权并返回一个 `RefMut<'a, T>` （实际上来自 `RefCell<T>` ），它可以被当做一个 `&mut T` 来使用；而 `RefMut<'a, T>` 的 `drop` 方法会将独占借用权交出，从而允许内核内的其他控制流后续对数据结构进行访问。
> `FrameTracker` 的设计也是基于同样的思想，有了它之后我们就不必手动回收物理页帧了，这在编译期就解决了很多潜在的问题。

