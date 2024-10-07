#  `core::str::bytes(&self)`
```rust
core::str
pub fn bytes(&self) -> Bytes<'_>
```
An iterator over the bytes of a string slice.
As a string slice consists of a sequence of bytes, we can iterate through a string slice by byte. This method returns such an iterator.

---
#   `core::str::chars(&self)`
```rust
core::str
pub fn chars(&self) -> Chars<'_>
```

Returns an iterator over the [`char`]s of a string slice.

As a string slice consists of valid UTF-8, we can iterate through a string slice by [`char`]. This method returns such an iterator.

It's important to remember that [`char`] represents a Unicode Scalar Value, and might not match your idea of what a 'character' is. Iteration over grapheme clusters may be what you actually want. This functionality is not provided by Rust's standard library, check crates.io instead.

---
#  `core::slice::from_raw_parts_mut`
`core::slice::from_raw_parts_mut` 是 Rust 语言标准库 `core` 模块提供的函数之一，它用于将一个指向原始内存数据的裸指针转换成一个可变引用的*切片*类型 `&mut [T]`。

该函数的定义如下：
```rust
pub unsafe fn from_raw_parts_mut<T>(
    ptr: *mut T, 
    len: usize
) -> &mut [T];

```
其中，`ptr` 参数是一个*指向要被转换为切片类型的原始内存数据的裸指针*，而 `len` 则表示该*内存区域所包含的元素个数*。注意，在使用该函数时需要非常小心，因为它会忽略 Rust 语言中很多的安全检查，如果错误地使用了该函数，那么在程序中就很容易引入各种危险和漏洞，导致程序崩溃或出现未定义行为。因此，只有在确信自己知道在干什么并且必须使用裸指针时，才应该使用该函数。

---
#  `core::slice::from_raw_parts`
`core::slice::from_raw_parts` 就是返回不可变的切片。
>`.quad` 是汇编语言中的一个伪指令，通常用于定义一个 64 位整数（8 字节长度）的常量。该常量可以在程序执行期间被读取，但不能修改。
```rust
//link_app.S
_num_app:
    .quad 4
    .quad app_0_start
    .quad app_1_start
    .quad app_2_start
    .quad app_3_start
    .quad app_3_end

//loader.S
let app_start:&[usize] = unsafe { core::slice::from_raw_parts(num_app_ptr.add(1), num_app + 1) };

```

---
#  `copy_from_slice` 
`copy_from_slice` 是 Rust 标准库中 `std::slice::SliceExt` trait 定义的一个方法。该方法可以将源 slice 中的数据复制到目标 slice 中，使目标 slice 中对应位置处的元素变成对应源 slice 位置处元素的副本。

CH2: 
```rust
unsafe fn load_app(&self, app_id: usize) {
     if app_id >= self.num_app {
         panic!("All applications completed!");
     }
     println!("[kernel] Loading app_{}", app_id);
     // clear app area
     core::slice::from_raw_parts_mut(
         APP_BASE_ADDRESS as *mut u8,
         APP_SIZE_LIMIT
    ).fill(0);
    let app_src = core::slice::from_raw_parts(
        self.app_start[app_id] as *const u8,
        self.app_start[app_id + 1] - self.app_start[app_id]
    );
    let app_dst = core::slice::from_raw_parts_mut(
        APP_BASE_ADDRESS as *mut u8,
        app_src.len()
    );
    app_dst.copy_from_slice(app_src);
    // memory fence about fetching the instruction memory
    asm!("fence.i");
}
```

这个方法负责将参数 `app_id` 对应的应用程序的二进制镜像加载到物理内存以 `0x80400000` 起始的位置，这个位置是批处理操作系统和应用程序之间约定的常数地址，回忆上一小节中，我们也调整应用程序的内存布局以同一个地址开头。第 7 行开始，我们首先将一块内存清空，然后找到待加载应用二进制镜像的位置，并将它复制到正确的位置。它本质上是把数据从一块内存复制到另一块内存，从批处理操作系统的角度来看，**是将操作系统数据段的一部分数据（实际上是应用程序）复制到了一个可以执行代码的内存区域**。在这一点上也体现了冯诺依曼计算机的 _代码即数据_ 的特征。

---
#  `read_volite()`
```rust
pub fn get_num_app() -> usize {
    extern "C" {
        fn _num_app();
    }
    unsafe { (_num_app as usize as *const usize).read_volatile() }
}
```

```rust
core::ptr::const_ptr
pub unsafe fn read_volatile (self) -> T  
where  
T: Sized,
```

Performs a volatile read of the value from `self` without moving it. This leaves the memory in `self` unchanged.

Volatile operations are intended to act on I/O memory, and are guaranteed to not be elided or reordered by the compiler across other volatile operations.

相对应的：
#   `write_volatile（）`
[[RUST迭代与闭包#.. 与For_each]]

---
#  `const_ptr. add ()`
```rust
core::ptr::const_ptr
pub const unsafe fn add(self, count: usize) -> Self  
where  
T: Sized,
```

---
#  `as_mut`
通过传进来的可变指针解引用出可变变量

```rust
core::ptr::mut_ptr
pub const unsafe fn as_mut<'a>(self) -> Option<&'a mut T>
```

Returns `None` if the pointer is null, or else returns a unique reference to the value wrapped in `Some`. If the value may be uninitialized, [`as_uninit_mut`] must be used instead.

For the shared counterpart see [`as_ref`].

-   You must enforce Rust's aliasing rules, since the returned lifetime `'a` is arbitrarily chosen and does not necessarily reflect the actual lifetime of the data. In particular, while this reference exists, the memory the pointer points to must not get accessed (read or written) through any other pointer.
- 你必须遵守 Rust 的别名规则，因为返回的生命周期 `'a` 是任意选择的，并不一定反映实际数据的生命周期。特别是，当这个引用存在时，指针指向的内存不能通过任何其他指针访问（读取或写入）
>指针必须被正确地对齐.
>它必须在 [模块文档] 中定义的意义下是“可解引用的”。
>指针必须指向一个已初始化的 T 实例。

```rust
let mut s = [1, 2, 3];  
let ptr: *mut u32 = s.as_mut_ptr();  
let first_value = unsafe { ptr.as_mut().unwrap() };  
*first_value = 4;  
println!("{s:?}"); // It'll print: "[4, 2, 3]".
```

---

#  `from_utf8`
```rust
core::str::converts
pub const fn from_utf8(v: &[u8]) -> Result<&str, Utf8Error>
```

Converts a slice of bytes to a string slice.

A string slice ([`&str`]) is made of bytes ([`u8`](vscode-file://vscode-app/d:/Programfiles/Microsoft%20VS%20Code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html "https://doc.rust-lang.org/nightly/core/primitive.u8.html")), and a byte slice ([`&[u8]`](vscode-file://vscode-app/d:/Programfiles/Microsoft%20VS%20Code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html "slice")) is made of bytes, so this function converts between the two. Not all byte slices are valid string slices, however: [`&str`] requires that it is valid UTF-8. `from_utf8()` checks to ensure that the bytes are valid UTF-8, and then does the conversion.

If you are sure that the byte slice is valid UTF-8, and you don't want to incur the overhead of the validity check, there is an unsafe version of this function, [`from_utf8_unchecked`](vscode-file://vscode-app/d:/Programfiles/Microsoft%20VS%20Code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html "https://doc.rust-lang.org/nightly/core/str/converts/fn.from_utf8_unchecked.html"), which has the same behavior but skips the check.

If you need a `String` instead of a `&str`, consider [`String::from_utf8`](vscode-file://vscode-app/d:/Programfiles/Microsoft%20VS%20Code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html "https://doc.rust-lang.org/nightly/core/std/string/struct.String.html#method.from_utf8").

Because you can stack-allocate a `[u8; N]`, and you can take a [`&[u8]`](vscode-file://vscode-app/d:/Programfiles/Microsoft%20VS%20Code/resources/app/out/vs/code/electron-sandbox/workbench/workbench. html "slice") of it, this function is one way to have a stack-allocated string. There is an example of this in the examples section below.

---
#  `size_of<T>()`
```rust
core::mem
pub const fn size_of<T>() -> usize
```

Returns the size of a type in bytes.

More specifically, this is the offset in bytes between successive elements in an array with that item type including alignment padding. Thus, for any type `T` and length `n`, `[T; n]` has a size of `n * size_of::<T>()`.

In general, the size of a type is not stable across compilations, but specific types such as primitives are.

E.g.
```rust
let ptr_mut = (kernel_stack_top - core::mem::size_of::<T>()) as *mut T;
unsafe {
	*ptr_mut = value;
}
```


---
```rust
core::option::Option
pub const fn take(&mut self) -> Option<T>
```

Takes the value out of the option, leaving a [`None`](vscode-file://vscode-app/d:/Programfiles/Microsoft%20VS%20Code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html "https://doc.rust-lang.org/nightly/core/option/enum.Option.html") in its place