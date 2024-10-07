
# 所有权


## 关于堆与栈：
 堆是缺乏组织的：当向堆放入数据时，你要请求一定大小的空间。内存分配器（memory allocator）在堆的某处找到一块足够大的空位，把它标记为已使用，并返回一个表示该位置地址的 **指针**（_pointer_）。这个过程称作 **在堆上分配内存**（_allocating on the heap_），有时简称为 “分配”（allocating）。（将数据推入栈中并不被认为是分配）。因为指向放入堆中数据的指针是已知的并且*大小是固定的*（64 位机器是 8 字节），你可以将该指针存储在栈上，不过当需要实际数据时，必须访问指针。
 当然 C 语言的指针是可以指向你在栈上建立的一个局部变量的。
 但也很容易造成野指针和悬垂指针的问题。
 悬垂指针：
 eg:
```C++
 int * return_intPTR(int b)
 {
	 int a=b;
	 return &a;
 }
```
 在函数返回后，a 这个函数调用栈上的变量被释放（栈顶指针变动等），但是返回值这个指针仍旧指着那个已经无效的内存地址，一旦解引用这个返回值，就会产生未知结果，谁也不知道现在那儿存的啥。
 
## 内存与分配

就字符串字面值来说，我们在编译时就知道其内容，所以文本被直接硬编码进最终的可执行文件中。这使得字符串字面值快速且高效。不过这些特性都只得益于字符串字面值的不可变性。不幸的是，我们不能为了每一个在编译时大小未知的文本而将一块内存放入二进制文件中，并且它的大小还可能随着程序运行而改变。
对于 `String` 类型，为了支持一个可变，可增长的文本片段，需要在堆上分配一块在编译时未知大小的内存来存放内容。这意味着：
-   必须在运行时向内存分配器（memory allocator）请求内存。
-   需要一个当我们处理完 `String` 时将内存返回给分配器的方法。

第一部分由我们完成：当调用 `String::from` 时，它的实现 (_implementation_) 请求其所需的内存。这在编程语言中是非常通用的。
然而，第二部分实现起来就各有区别了。在有 **垃圾回收**（_garbage collector_，_GC_）的语言中，GC 记录并清除不再使用的内存，而我们并不需要关心它。在大部分没有 GC 的语言中，识别出不再使用的内存并调用代码显式释放就是我们的责任了，跟请求内存的时候一样。从历史的角度上说正确处理内存回收曾经是一个困难的编程问题。如果忘记回收了会浪费内存。如果过早回收了，将会出现无效变量。如果重复回收，这也是个 bug。我们需要精确的为一个 `allocate` 配对一个 `free`。
Rust 采取了一个不同的策略：内存在拥有它的变量离开作用域后就被自动释放。下面是示例 4-1 中作用域例子的一个使用 `String` 而不是字符串字面值的版本：
```RUST
{         
	let s = String:: from ("hello"); // 从此处起，s 是有效的          
			// 使用 s     
}                                  // 此作用域已结束，                                        // s 不再有效 
```
这是一个将 `String` 需要的内存返回给分配器的很自然的位置：当 `s` 离开作用域的时候。当变量离开作用域，Rust 为我们调用一个特殊的函数。这个函数叫做 [`drop`](https://doc.rust-lang.org/std/ops/trait.Drop.html#tymethod.drop)，在这里 `String` 的作者可以放置释放内存的代码。Rust 在结尾的 `}` 处自动调用 `drop`。

> 注意：在 C++ 中，这种 item 在生命周期结束时释放资源的模式有时被称作 **资源获取即初始化**（_Resource Acquisition Is Initialization (RAII)_）。如果你使用过 RAII 模式的话应该对 Rust 的 `drop` 函数并不陌生。
> RAII:
> 使用局部对象来管理资源的技术称为资源获取即初始化；这里的资源主要是指操作系统中有限的东西如内存、网络套接字等等，局部对象是指存储在栈的对象，它的生命周期是由操作系统（？）来管理的，无需人工介入。

这个模式对编写 Rust 代码的方式有着深远的影响。现在它看起来很简单，不过在更复杂的场景下代码的行为可能是不可预测的，比如当有多个变量使用在堆上分配的内存时。现在让我们探索一些这样的场景。
## 变量与数据交互的方式（一）：移动

在 Rust 中，多个变量可以采取不同的方式与同一数据进行交互。
```RUST
fn main() {
    let x = 5;
    let y = x;
}
```
将 `5` 绑定到 `x`；接着生成一个值 `x` 的拷贝并绑定到 `y`”。现在有了两个变量，`x` 和 `y`，都等于 `5`。这也正是事实上发生了的，因为整数是有已知固定大小的简单值，所以这两个 `5` 被放入了栈中。
```RUST
let s1 = String::from("hello"); 
let s2 = s1;
```
这看起来与上面的代码非常类似，所以我们可能会假设他们的运行方式也是类似的：也就是说，第二行可能会生成一个 `s1` 的拷贝并绑定到 `s2` 上。不过，事实上并不完全是这样。
看看图 4-1 以了解 `String` 的底层会发生什么。`String` 由三部分组成，如图左侧所示：一个指向存放字符串内容内存的指针，一个长度，和一个容量。这一组数据存储在栈上。右侧则是堆上存放内容的内存部分。

![[Pasted image 20230415200049.png]]

图 4-1：将值 `"hello"` 绑定给 `s1` 的 `String` 在内存中的表现形式

长度表示 `String` 的内容当前使用了多少字节的内存。容量是 `String` 从分配器总共获取了多少字节的内存。长度与容量的区别是很重要的，不过在当前上下文中并不重要，所以现在可以忽略容量。
当我们将 `s1` 赋值给 `s2`，`String` 的数据被复制了，这意味着我们从栈上拷贝了它的指针、长度和容量。我们并没有复制指针指向的堆上数据。换句话说，内存中数据的表现如图 4-2 所示。
![[Pasted image 20230415200116.png]]
图 4-2：变量 `s2` 的内存表现，它有一份 `s1` 指针、长度和容量的拷贝

这个表现形式看起来 **并不像** 图 4-3 中的那样，如果 Rust 也拷贝了堆上的数据，那么内存看起来就是这样的。如果 Rust 这么做了，那么操作 `s2 = s1` 在堆上数据比较大的时候会对运行时性能造成非常大的影响。(深拷贝)
![[Pasted image 20230415200129.png]]
图 4-3：另一个 `s2 = s1` 时可能的内存表现，如果 Rust 同时也拷贝了堆上的数据的话
之前我们提到过当变量离开作用域后，Rust 自动调用 `drop` 函数并清理变量的堆内存。不过图 4-2 展示了两个数据指针指向了同一位置。这就有了一个问题：**当 `s2` 和 `s1` 离开作用域，他们都会尝试释放相同的内存**。这是一个叫做 **二次释放**（_double free_）的错误，也是之前提到过的内存安全性 bug 之一。两次释放（相同）内存会导致内存污染，它可能会导致潜在的安全漏洞。
为了确保内存安全，在 `let s2 = s1;` 之后，Rust 认为 `s1` 不再有效，因此 Rust 不需要在 `s1` 离开作用域后清理任何东西。看看在 `s2` 被创建之后尝试使用 `s1` 会发生什么；这段代码不能运行：
```RUST
let s1 = String::from("hello");    
let s2 = s1;    
println!("{}, world!", s1);`
```
![[Pasted image 20230415200335.png]]

>  *拷贝指针、长度和容量而不拷贝数据*可能听起来像浅拷贝。不过因为 Rust *同时使第一个变量无效*了，这个操作被称为 **移动**（_move_），而不是叫做浅拷贝。

因为 move 之后只有 `s2` 是有效的，当其离开作用域，它就释放自己的内存，完毕。
另外，这里还隐含了一个设计选择：Rust 永远也不会自动创建数据的 “深拷贝”。因此，任何 **自动** 的复制可以被认为对运行时性能影响较小。
### [变量与数据交互的方式（二）：克隆](https://kaisery.github.io/trpl-zh-cn/ch04-01-what-is-ownership.html#%E5%8F%98%E9%87%8F%E4%B8%8E%E6%95%B0%E6%8D%AE%E4%BA%A4%E4%BA%92%E7%9A%84%E6%96%B9%E5%BC%8F%E4%BA%8C%E5%85%8B%E9%9A%86)
如果我们 **确实** 需要深度复制 `String` 中堆上的数据，而不仅仅是栈上的数据，可以使用一个叫做 `clone` 的通用函数。第五章会讨论方法语法，不过因为方法在很多语言中是一个常见功能，所以之前你可能已经见过了。
这是一个实际使用 `clone` 方法的例子：
 ```RUST
 let s1 = String::from("hello");     
 let s2 = s1.clone();      
 println!("s1 = {}, s2 = {}", s1, s2);
 ```

这段代码能正常运行，并且明确产生图 4-3 中行为，这里堆上的数据 **确实** 被复制了。
当出现 `clone` 调用时，你知道一些特定的代码被执行而且这些代码可能相当消耗资源。你很容易察觉到一些不寻常的事情正在发生。
### [只在栈上的数据：拷贝](https://kaisery.github.io/trpl-zh-cn/ch04-01-what-is-ownership.html#%E5%8F%AA%E5%9C%A8%E6%A0%88%E4%B8%8A%E7%9A%84%E6%95%B0%E6%8D%AE%E6%8B%B7%E8%B4%9D)
这里还有一个没有提到的小窍门。这些代码使用了整型并且是有效的，他们是示例 4-2 中的一部分：
    `let x = 5;     let y = x;      println!("x = {}, y = {}", x, y);`
但这段代码似乎与我们刚刚学到的内容相矛盾：没有调用 `clone`，不过 `x` 依然有效且没有被移动到 `y` 中。
原因是像整型这样的在编译时已知大小的类型被整个存储在栈上，所以拷贝其实际的值是快速的。这意味着没有理由在创建变量 `y` 后使 `x` 无效。换句话说，这里**没有深浅拷贝的区别**，所以这里调用 `clone` 并不会与通常的浅拷贝有什么不同，我们可以不用管它。

Rust 有一个叫做 `Copy` trait 的特殊注解，可以用在类似整型这样的存储在栈上的类型上（[第十章](https://kaisery.github.io/trpl-zh-cn/ch10-00-generics.html)将会详细讲解 trait）。如果一个类型实现了 `Copy` trait，那么一个旧的变量在将其赋值给其他变量后仍然可用。

Rust 不允许自身或其任何部分实现了 `Drop` trait 的类型使用 `Copy` trait。如果我们对其值离开作用域时需要特殊处理的类型使用 `Copy` 注解，将会出现一个编译时错误。要学习如何为你的类型添加 `Copy` 注解以实现该 trait，请阅读附录 C 中的 [“可派生的 trait”](https://kaisery.github.io/trpl-zh-cn/appendix-03-derivable-traits.html)。

那么哪些类型实现了 `Copy` trait 呢？你可以查看给定类型的文档来确认，不过作为一个通用的规则，任何一组简单标量值的组合都可以实现 `Copy`，任何*不需要分配内存或某种形式资源的类型*都可以实现 `Copy` 。如下是一些 `Copy` 的类型：

-   所有整数类型，比如 `u32`。
-   布尔类型，`bool`，它的值是 `true` 和 `false`。
-   所有浮点数类型，比如 `f64`。
-   字符类型，`char`。
-   元组，当且仅当其包含的类型也都实现 `Copy` 的时候。比如，`(i32, i32)` 实现了 `Copy`，但 `(i32, String)` 就没有。


## [所有权与函数](https://kaisery.github.io/trpl-zh-cn/ch04-01-what-is-ownership.html#%E6%89%80%E6%9C%89%E6%9D%83%E4%B8%8E%E5%87%BD%E6%95%B0)

将*值传递给函数*与*给变量赋值*的原理相似。向函数传递值可能会移动或者复制，就像赋值语句一样。示例 4-3 使用注释展示变量何时进入和离开作用域：
一个移动，一个拷贝
```RUST
fn main() {     
	let s = String::from("hello");  // s 进入作用域      
	takes_ownership(s);             // s 的值移动到函数里 ...                                     
									// ... 所以到这里不再有效      
	let x = 5;                      // x 进入作用域      
	makes_copy(x);                  // x 应该移动函数里，                                     
						// 但 i32 是 Copy 的，                                    
						 // 所以在后面可继续使用 x  
	} // 这里，x 先移出了作用域，然后是 s。但因为 s 的值已被移走，   
	 // 没有特殊之处  
fn takes_ownership(some_string: String) { 
// some_string 进入作用域     
	println!("{}", some_string); 
} // 这里，some_string 移出作用域并调用 `drop` 方法。   
  // 占用的内存被释放  
fn makes_copy(some_integer: i32) { 
// some_integer 进入作用域     
	println!("{}", some_integer); 
} 
// 这里，some_integer 移出作用域。没有特殊之处
```
示例 4-3：带有所有权和作用域注释的函数

当尝试在调用 `takes_ownership` 后使用 `s` 时，Rust 会抛出一个编译时错误。这些静态检查使我们免于犯错。
## [返回值与作用域](https://kaisery.github.io/trpl-zh-cn/ch04-01-what-is-ownership.html#%E8%BF%94%E5%9B%9E%E5%80%BC%E4%B8%8E%E4%BD%9C%E7%94%A8%E5%9F%9F)
**返回值也可以转移所有权。** 示例 4-4 展示了一个返回了某些值的示例，与示例 4-3 一样带有类似的注释。
文件名：src/main. rs
```RUST
fn main() {
    let s1 = gives_ownership();         // gives_ownership 将返回值转移给 s1
    let s2 = String::from("hello");     // s2 进入作用域
    let s3 = takes_and_gives_back(s2);  // s2 被移动到takes_and_gives_back 中，
                                        // 它也将返回值移给 s3
} 
// 这里，s3 移出作用域并被丢弃。s2 也移出作用域，但已被移走，
// 所以什么也不会发生。s1 离开作用域并被丢弃

fn gives_ownership() -> String {// gives_ownership 会将返回值移动给调用它的函数
    let some_string = String::from("yours"); // some_string 进入作用域。
    some_string                              // 返回 some_string 
                                    // 并移出给调用的函数
}

// takes_and_gives_back 将传入字符串并返回该值
fn takes_and_gives_back(a_string: String) -> String { // a_string 进入作用域 
    a_string  // 返回 a_string 并移出给调用的函数
}

```
示例 4-4: 转移返回值的所有权

**变量的所有权总是遵循相同的模式：将值赋给另一个变量时移动它。当持有堆中数据值的变量离开作用域时，其值将通过 `drop` 被清理掉，除非数据被移动为另一个变量所有。**

虽然这样是可以的，但是在每一个函数中都获取所有权并接着返回所有权有些啰嗦。*如果我们想要函数使用一个值但不获取所有权该怎么办呢？* 如果我们还要接着使用它的话，每次都传进去再返回来就有点烦人了，除此之外，我们也可能想返回函数体中产生的一些数据。
我们可以使用元组来返回多个值，如示例:
```Rust
fn main() {
    let s1 = String::from("hello");
    let (s2, len) = calculate_length(s1);
    println!("The length of '{}' is {}.", s2, len);
}
fn calculate_length(s: String) -> (String, usize) {
    let length = s.len(); // len() 返回字符串的长度
    (s, length)
}

```
示例 4-5: 返回参数的所有权
但是这未免有些形式主义，而且这种场景应该很常见。幸运的是，Rust 对此提供了一个不用获取所有权就可以使用值的功能，叫做 **引用**（_references_）。
# 引用与借用
示例 4-5 中的元组代码有这样一个问题：我们必须将 `String` 返回给调用函数，以便在调用 `calculate_length` 后仍能使用 `String`，因为 `String` 被移动到了 `calculate_length` 内。相反我们可以提供一个 `String` 值的引用（reference）。**引用**（_reference_）像一个*指针*（就是），因为它是一个地址，我们可以由此访问储存于该地址的属于其他变量的数据。与指针不同，引用确保指向某个特定类型的有效值。

下面是如何定义并使用一个（新的）`calculate_length` 函数，它以一个对象的*引用作为参数而不是获取值的所有权*：

```rust
fn main() {
    let s1 = String::from("hello");

    let len = calculate_length(&s1);

    println!("The length of '{}' is {}.", s1, len);
}

fn calculate_length(s: &String) -> usize {
    s.len()
}

```

首先，注意变量声明和函数返回值中的所有元组代码都消失了。其次，注意我们传递 `&s1` 给 `calculate_length`，同时在函数定义中，我们获取 `&String` 而不是 `String`。这些 & 符号就是 **引用**，它们允许你使用值但不获取其所有权。

> 注意：与使用 `&` 引用相反的操作是 **解引用**（_dereferencing_），它使用解引用运算符，`*`。我们将会在第八章遇到一些解引用运算符，并在第十五章详细讨论解引用。

仔细看看这个函数调用：
`let s1 = String::from("hello");      let len = calculate_length(&s1);`
`&s1` 语法让我们创建一个 **指向** 值 `s1` 的引用，但是并不拥有它。因为并不拥有这个值，所以当引用停止使用时，它所指向的值也不会被丢弃。
同理，函数签名使用 `&` 来表明参数 `s` 的类型是一个引用。让我们增加一些解释性的注释：
```RUST

fn calculate_length(s: &String) -> usize { // s 是 String 的引用 
	s.len() 
} // 这里，s 离开了作用域。但因为它并不拥有引用值的所有权，
// 所以什么也不会发生
```

变量 `s` 有效的作用域与函数参数的作用域一样，不过当 `s` 停止使用时并不丢弃引用指向的数据，因为 `s` 并没有所有权。当函数使用引用而不是实际值作为参数，无需返回值来交还所有权，因为就不曾拥有所有权。
我们将创建一个引用的行为称为 **借用**（_borrowing_）。正如现实生活中，如果一个人拥有某样东西，你可以从他那里借来。当你使用完毕，必须还回去。我们并不拥有它。
正如变量默认是不可变的，引用也一样。（默认）不允许修改引用的值。
### [可变引用](https://kaisery.github.io/trpl-zh-cn/ch04-02-references-and-borrowing.html#%E5%8F%AF%E5%8F%98%E5%BC%95%E7%94%A8)
我们通过一个小调整就能修复前面中的错误，允许我们修改一个借用的值，这就是 **可变引用**（_mutable reference_）：
文件名：src/main.rs

`fn main() {     let mut s = String::from("hello");      change(&mut s); }  fn change(some_string: &mut String) {     some_string.push_str(", world"); }`

首先，我们必须将 `s` 改为 `mut`。然后在调用 `change` 函数的地方创建一个可变引用 `&mut s`，并更新函数签名以接受一个可变引用 `some_string: &mut String`。这就非常清楚地表明，`change` 函数将改变它所借用的值。

可变引用有一个很大的限制：如果你有一个对该变量的可变引用，你就不能再创建对该变量的引用。这些尝试创建两个 `s` 的可变引用的代码会失败：
    `let mut s = String::from("hello");      let r1 = &mut s;     let r2 = &mut s;      println!("{}, {}", r1, r2);`
错误如下：
``$ cargo run    Compiling ownership v0.1.0 (file:///projects/ownership) error[E0499]: cannot borrow `s` as mutable more than once at a time  --> src/main.rs:5:14   | 4 |     let r1 = &mut s;   |              ------ first mutable borrow occurs here 5 |     let r2 = &mut s;   |              ^^^^^^ second mutable borrow occurs here 6 | 7 |     println!("{}, {}", r1, r2);   |                        -- first borrow later used here  For more information about this error, try `rustc --explain E0499`. error: could not compile `ownership` due to previous error``

这个报错说这段代码是无效的，因为我们不能在同一时间多次将 `s` 作为可变变量借用。第一个可变的借入在 `r1` 中，并且必须持续到在 `println！` 中使用它，但是在那个可变引用的创建和它的使用之间，我们又尝试在 `r2` 中创建另一个可变引用，该引用借用与 `r1` 相同的数据。
这一限制以一种非常小心谨慎的方式允许可变性，防止同一时间对同一数据存在多个可变引用。新 Rustacean 们经常难以适应这一点，因为大部分语言中变量任何时候都是可变的。这个限制的好处是 Rust 可以在编译时就避免数据竞争。**数据竞争**（_data race_）类似于竞态条件，它可由这三个行为造成：
-   两个或更多指针同时访问同一数据。
-   至少有一个指针被用来写入数据。
-   没有同步数据访问的机制。

数据竞争会导致未定义行为，难以在运行时追踪，并且难以诊断和修复；Rust 避免了这种情况的发生，因为它甚至不会编译存在数据竞争的代码！
一如既往，可以使用大括号来创建一个新的作用域，以允许拥有多个可变引用，只是不能 **同时** 拥有：

   ```rust
   let mut s = String::from("hello");      
   {         
	   let r1 = &mut s;     
   } // r1 在这里离开了作用域，所以我们完全可以创建一个新的引用      
   let r2 = &mut s;
   ```

Rust 在同时使用可变与不可变引用时也采用的类似的规则。这些代码会导致一个错误：
```rust
  fn main() {
    let mut s = String::from("hello");

    let r1 = &s; // 没问题
    let r2 = &s; // 没问题
    let r3 = &mut s; // 大问题

    println!("{}, {}, and {}", r1, r2, r3);
}
 
```

哇哦！我们 **也** 不能在拥有不可变引用的同时拥有可变引用。
不可变引用的用户可不希望在他们的眼皮底下值就被意外的改变了！然而，多个不可变引用是可以的，因为没有哪个只能读取数据的人有能力影响其他人读取到的数据。
注意一个引用的作用域从声明的地方开始一直持续到最后一次使用为止。例如，因为最后一次使用不可变引用（`println!`)，发生在声明可变引用之前，所以如下代码是可以编译的：
```rust
fn main() {
    let mut s = String::from("hello");

    let r1 = &s; // 没问题
    let r2 = &s; // 没问题
    println!("{} and {}", r1, r2);
    // 此位置之后 r1 和 r2 不再使用

    let r3 = &mut s; // 没问题
    println!("{}", r3);
}

```
不可变引用 `r1` 和 `r2` 的作用域在 `println!` 最后一次使用之后结束，这也是创建可变引用 `r3` 的地方。它们的作用域没有重叠，所以代码是可以编译的。*编译器*可以在作用域结束之前*判断* **不再使用的引用**。

尽管这些错误有时使人沮丧，但请牢记这是 Rust 编译器在提前指出一个潜在的 bug（在编译时而不是在运行时）并精准显示问题所在。这样你就不必去跟踪为何数据并不是你想象中的那样。

### [悬垂引用（Dangling References）](https://kaisery.github.io/trpl-zh-cn/ch04-02-references-and-borrowing.html#%E6%82%AC%E5%9E%82%E5%BC%95%E7%94%A8dangling-references)

在具有指针的语言中，很容易通过释放内存时保留指向它的指针而错误地生成一个 **悬垂指针**（_dangling pointer_），所谓悬垂指针是其指向的内存可能已经被分配给其它持有者。相比之下，在 Rust 中编译器确保引用永远也不会变成悬垂状态：当你拥有一些数据的引用，编译器确保数据不会在其引用之前离开作用域。
让我们尝试创建一个悬垂引用，Rust 会通过一个编译时错误来避免：
`fn main() {     let reference_to_nothing = dangle(); }  fn dangle() -> &String {     let s = String::from("hello");      &s }`
这里是错误：
``$ cargo run    Compiling ownership v0.1.0 (file:///projects/ownership) error[E0106]: missing lifetime specifier  --> src/main.rs:5:16   | 5 | fn dangle() -> &String {   |                ^ expected named lifetime parameter   |   = help: this function's return type contains a borrowed value, but there is no value for it to be borrowed from help: consider using the `'static` lifetime   | 5 | fn dangle() -> &'static String {   |                 +++++++  For more information about this error, try `rustc --explain E0106`. error: could not compile `ownership` due to previous error``

错误信息引用了一个我们还未介绍的功能：生命周期（lifetimes）。第十章会详细介绍生命周期。不过，如果你不理会生命周期部分，错误信息中确实包含了为什么这段代码有问题的关键信息：
`this function's return type contains a borrowed value, but there is no value for it to be borrowed from`

因为 `s` 是在 `dangle` 函数内创建的，当 `dangle` 的代码执行完毕后，`s` 将被释放。不过我们尝试返回它的引用。这意味着这个引用会指向一个无效的 `String`，这可不对！Rust 不会允许我们这么做。
这里的解决方法是直接返回 `String`：
`fn no_dangle() -> String {     let s = String::from("hello");      s }`
这样就没有任何错误了。所有权被移动出去，所以没有值被释放。
### [引用的规则](https://kaisery.github.io/trpl-zh-cn/ch04-02-references-and-borrowing.html#%E5%BC%95%E7%94%A8%E7%9A%84%E8%A7%84%E5%88%99)
让我们概括一下之前对引用的讨论：
-   在任意给定时间，**要么** 只能有一个可变引用，**要么** 只能有多个不可变引用。
-   引用必须总是有效的。

# Option<\T>
当有一个 `Some` 值时，我们就知道存在一个值，而这个值保存在 `Some` 中。当有个 `None` 值时，在某种意义上，它跟空值具有相同的意义：并没有一个有效的值。那么，`Option<T>` 为什么就比空值要好呢？

简而言之，因为 `Option<T>` 和 `T`（这里 `T` 可以是任何类型）是不同的类型，编译器不允许像一个肯定有效的值那样使用 `Option<T>`。例如，这段代码不能编译，因为它尝试将 `Option<i8>` 与 `i8` 相加：

```RUST
fn main () {
    let x: i8 = 5;
    let y: Option<i8> = Some (5);

    let sum = x + y;
}

```

如果运行这些代码，将得到错误.
事实上，错误信息意味着 Rust 不知道该如何将 `Option<i8>` 与 `i8` 相加，因为它们的类型不同。当在 Rust 中拥有一个像 `i8` 这样类型的值时，编译器确保它总是有一个有效的值。我们可以自信使用而无需做空值检查。只有当使用 `Option<i8>`（或者任何用到的类型）的时候需要担心可能没有值，而编译器会确保我们在使用值之前处理了为空的情况。

换句话说，在对 `Option<T>` 进行运算之前必须将其转换为 `T`。通常这能帮助我们捕获到空值最常见的问题之一：假设某值不为空但实际上为空的情况。

# match 

Rust 有一个叫做 `match` 的极为强大的控制流运算符，它允许我们将一个值与一系列的模式相比较，并根据相匹配的模式执行相应代码。模式可由字面值、变量、通配符和许多其他内容构成；[第十八章](https://kaisery.github.io/trpl-zh-cn/ch18-00-patterns.html)会涉及到所有不同种类的模式以及它们的作用。`match` 的力量来源于模式的表现力以及编译器检查，它确保了所有可能的情况都得到处理。

可以把 `match` 表达式想象成某种硬币分类器：硬币滑入有着不同大小孔洞的轨道，每一个硬币都会掉入符合它大小的孔洞。同样地，值也会通过 `match` 的每一个模式，并且在遇到第一个 “符合” 的模式时，值会进入相关联的代码块并在执行中被使用。

>**模式**（_Patterns_）是 Rust 中特殊的语法，它用来匹配类型中的结构，无论类型是简单还是复杂。结合使用模式和 `match` 表达式以及其他结构可以提供更多对程序控制流的支配权。模式由如下一些内容组合而成：
>-   字面值
>-   解构的数组、枚举、结构体或者元组
>-   变量
>-   通配符
>-   占位符

>一些模式的例子包括 `x`, `(a, 3)` 和 `Some(Color::Red)`。在模式为有效的上下文中，这些部分描述了数据的形状。接着可以用其匹配值来决定程序是否拥有正确的数据来运行特定部分的代码。

>我们通过将一些值与模式相比较来使用它。如果模式匹配这些值，我们对值部分进行相应处理。回忆一下第六章讨论 `match` 表达式时像硬币分类器那样使用模式。如果数据符合这个形状，就可以使用这些命名的片段。如果不符合，与该模式相关的代码则不会运行。

>本章是所有模式相关内容的参考。我们将涉及到使用模式的有效位置，_refutable_ 与 _irrefutable_ 模式的区别，和你可能会见到的不同类型的模式语法。在最后，你将会看到如何使用模式创建强大而简洁的代码。
> [所有可能会用到模式的位置 - Rust 程序设计语言 简体中文版 (kaisery.github.io)](https://kaisery.github.io/trpl-zh-cn/ch18-01-all-the-places-for-patterns.html) s

# Module
## Path
路径有两种形式：
-   **绝对路径**（_absolute path_）是以 crate 根（root）开头的全路径；对于外部 crate 的代码，是以 crate 名开头的绝对路径，对于对于当前 crate 的代码，则以字面值 `crate` 开头。
-   **相对路径**（_relative path_）从当前模块开始，以 `self`、`super` 或当前模块的标识符开头。

绝对路径和相对路径都后跟一个或多个由双冒号（`::`）分割的标识符。

##  使用 `use` 关键字将路径引入作用域

* use 引用依旧**遵循私有规则**
* 使用 `use` 引入**结构体、枚举和其他项时**，习惯是指定它们的*完整路径*。示例 7-14 展示了将 `HashMap` 结构体引入二进制 crate 作用域的习惯用法。
* 针对**函数**，我没让你通常引用到它的**父模块**
* 同名条目 ： 引入到父级
```RUST
use std::fmt;
use std::io;

fn function1() -> fmt::Result {
    // --snip--
    Ok(())
}

fn function2() -> io::Result<()> {
    // --snip--
    Ok(())
}

```
或者使用*As*
```RUST
use std::fmt;
use std::io;

fn function1() -> fmt::Result {
    // --snip--
    Ok(())
}

fn function2() -> io::Result<()> {
    // --snip--
    Ok(())
}

```

*  [使用 `pub use` 重导出名称](https://kaisery.github.io/trpl-zh-cn/ch07-04-bringing-paths-into-scope-with-the-use-keyword.html#%E4%BD%BF%E7%94%A8-pub-use-%E9%87%8D%E5%AF%BC%E5%87%BA%E5%90%8D%E7%A7%B0)

使用 `use` 关键字，将某个名称导入当前作用域后，这个名称在此作用域中就可以使用了，但它对此作用域之外还是私有的。如果想让其他人调用我们的代码时，也能够正常使用这个名称，就好像它本来就在当前作用域一样，那我们可以将 `pub` 和 `use` 合起来使用。这种技术被称为 “_重导出_（_re-exporting_）”：我们不仅将一个名称导入了当前作用域，还允许别人把它导入他们自己的作用域。


# 生命周期

# 迭代器


# More about cargo and crates. io
在 Rust 中 **发布配置**（_release profiles_）是预定义的、可定制的带有不同选项的配置，他们允许程序员更灵活地控制代码编译的多种选项。每一个配置都彼此相互独立。

Cargo 有两个主要的配置：
* 运行 `cargo build` 时采用的 `dev` 配置, `dev` 配置被定义为开发时的好的默认配置，
* 运行 `cargo build --release` 的 `release` 配置, `release` 配置则有着良好的发布构建的默认配置。

这些配置名称可能很眼熟，因为它们出现在构建的输出中：

```shell
$ cargo build
    Finished dev [unoptimized + debuginfo] target(s) in 0.0s
$ cargo build --release
    Finished release [optimized] target(s) in 0.0s

```

构建输出中的 `dev` 和 `release` 表明编译器在使用不同的配置。
![[Pasted image 20230412233235.png]]

关于每个配置选项比如 `opt-level` 优化程度等的官方文档：
https://doc.rust-lang.org/cargo/reference/profiles.html

## doc
一些 crate 作者经常在文档注释中使用的部分有：

-   **Panics**：这个函数可能会 `panic!` 的场景。并不希望程序崩溃的函数调用者应该确保他们不会在这些情况下调用此函数。
-   **Errors**：如果这个函数返回 `Result`，此部分描述可能会出现何种错误以及什么情况会造成这些错误，这有助于调用者编写代码来采用不同的方式处理不同的错误。
-   **Safety**：如果这个函数使用 `unsafe` 代码（这会在第十九章讨论），这一部分应该会涉及到期望函数调用者支持的确保 `unsafe` 块中代码正常工作的不变条件（invariants）。

大部分文档注释不需要所有这些部分，不过这是一个提醒你检查调用你代码的用户有兴趣了解的内容的列表。

### [文档注释作为测试](https://kaisery.github.io/trpl-zh-cn/ch14-02-publishing-to-crates-io.html#%E6%96%87%E6%A1%A3%E6%B3%A8%E9%87%8A%E4%BD%9C%E4%B8%BA%E6%B5%8B%E8%AF%95)

在文档注释中增加示例代码块是一个清楚的表明如何使用库的方法，这么做还有一个额外的好处：`cargo test` 也会像测试那样运行文档中的示例代码！没有什么比有例子的文档更好的了，但最糟糕的莫过于写完文档后改动了代码，而导致例子不能正常工作。尝试 `cargo test` 运行像示例 14-1 中 `add_one` 函数的文档；应该在测试结果中看到像这样的部分：

   `Doc-tests my_crate  running 1 test test src/lib.rs - add_one (line 5) ... ok  test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.27s`

现在尝试改变函数或例子来使例子中的 `assert_eq!` 产生 panic。再次运行 `cargo test`，你将会看到文档测试捕获到了例子与代码不再同步！

### [注释包含项的结构](https://kaisery.github.io/trpl-zh-cn/ch14-02-publishing-to-crates-io.html#%E6%B3%A8%E9%87%8A%E5%8C%85%E5%90%AB%E9%A1%B9%E7%9A%84%E7%BB%93%E6%9E%84)

文档注释风格 `//!` 为包含注释的项，而不是位于注释之后的项增加文档。这通常用于 crate 根文件（通常是 _src/lib.rs_）或模块的根文件为 crate 或模块整体提供文档。

作为一个例子，为了增加描述包含 `add_one` 函数的 `my_crate` crate 目的的文档，可以在 _src/lib. rs_ 开头增加以 `//!` 开头的注释

# 智能指针

## Box<\T>
box 允许你将一个值放在堆上而不是栈上。留在栈上的则是指向堆数据的指针。如果你想回顾一下栈与堆的区别请参考第四章。
除了数据被储存在堆上而不是栈上之外，box 没有性能损失。不过也没有很多额外的功能。它们多用于如下场景：
-   当有一**个在编译时未知大小**的类型，而又想要在需要确切大小的上下文中使用这个类型值的时候
-   当有大量数据并希望在确保数据**不被拷贝的情况下转移所有权**的时候
-   *当希望拥有一个值并只关心它的类型是否实现了特定 trait 而不是其具体类型的时候*

 box 在 离开作用域时，它将被释放。这个释放过程作用于 box 本身（位于栈上）和它所指向的数据（位于堆上）。
###  Box<\T> 允许创建递归类型
**递归类型**（_recursive type_）的值可以拥有另一个同类型的值作为其的一部分。这会产生一个问题因为 Rust 需要在编译时知道类型占用多少空间。递归类型的值嵌套理论上可以无限的进行下去，*所以 Rust 不知道递归类型需要多少空间*。**因为 box 有一个已知的大小，所以通过在循环类型定义中插入 box，就可以创建递归类型了**。
作为一个递归类型的例子，让我们探索一下 _cons list_。这是一个函数式编程语言中常见的数据类型，来展示这个（递归类型）概念。除了递归之外，我们将要定义的 cons list 类型是很直白的，所以这个例子中的概念，在任何遇到更为复杂的涉及到递归类型的场景时都很实用。（**链表**）
![[Pasted image 20230415180129.png]]

![[Pasted image 20230415180255.png]]

因为 `Box<T>` 是一个指针，我们总是知道它需要多少空间：指针的大小并不会根据其指向的数据量而改变。这意味着可以将 `Box` 放入 `Cons` 成员中而不是直接存放另一个 `List` 值。`Box` 会指向另一个位于堆上的 `List` 值，而不是存放在 `Cons` 成员中。从概念上讲，我们仍然有一个通过在其中 “存放” 其他列表创建的列表，不过现在实现这个概念的方式更像是一个项挨着另一项，而不是一项包含另一项。
`Cons` 成员将会需要一个 `i32` 的大小加上储存 box 指针数据的空间。`Nil` 成员不储存值，所以它比 `Cons` 成员需要更少的空间。现在我们知道了任何 `List` 值最多需要一个 `i32` 加上 box 指针数据的大小。通过使用 box，打破了这无限递归的连锁，这样编译器就能够计算出储存 `List` 值需要的大小了。图 15-2 展示了现在 `Cons` 成员看起来像什么：
![A finite Cons list](https://kaisery.github.io/trpl-zh-cn/img/trpl15-02.svg)

图 15-2：因为 `Cons` 存放一个 `Box` 所以 `List` 不是无限大小的了

box 只提供了间接存储和堆分配；他们并没有任何其他特殊的功能，比如我们将会见到的其他智能指针。它们也没有这些特殊功能带来的性能损失，所以他们可以用于像 cons list 这样只需要间接存储的场景。我们还将在第十七章看到 box 的更多应用场景。
`Box<T>` 类型是一个智能指针，因为它实现了 `Deref` trait，它允许 `Box<T>` 值被当作引用对待。当 `Box<T>` 值离开作用域时，由于 `Box<T>` 类型 `Drop` trait 的实现，box 所指向的堆数据也会被清除。这两个 trait 对于在本章余下讨论的其他智能指针所提供的功能中，将会更为重要。

### [追踪指针的值](https://kaisery.github.io/trpl-zh-cn/ch15-02-deref.html#%E8%BF%BD%E8%B8%AA%E6%8C%87%E9%92%88%E7%9A%84%E5%80%BC)
常规引用是一个指针类型，一种理解指针的方式是将其看成指向储存在其他某处值的箭头。在示例 15-6 中，创建了一个 `i32` 值的引用，接着使用解引用运算符来跟踪所引用的值：
文件名：src/main. rs
```RUST
fn main() {     
let x = 5;     
let y = &x;      
assert_eq!(5, x);     
assert_eq!(5, *y); 
}
```

示例 15-6：使用解引用运算符来跟踪 `i32` 值的引用
变量 `x` 存放了一个 `i32` 值 `5`。`y` 等于 `x` 的一个引用。可以断言 `x` 等于 `5`。然而，如果希望对 `y` 的值做出断言，必须使用 `*y` 来追踪引用所指向的值（也就是 **解引用**），这样编译器就可以比较实际的值了。一旦解引用了 `y`，就可以访问 `y` 所指向的整型值并可以与 `5` 做比较。
相反如果尝试编写 `assert_eq!(5, y);`，则会得到如下编译错误：
![[Pasted image 20230415181602.png]]

不允许比较数字的引用与数字，因为它们是不同的类型。必须使用解引用运算符追踪引用所指向的值。
  


## Deref<\T>
实现 `Deref` trait 允许我们重载 **解引用运算符**（_dereference operator_）`*`（不要与乘法运算符或通配符相混淆）。通过这种方式实现 `Deref` trait 的智能指针可以被当作常规引用来对待，可以编写操作引用的代码并用于智能指针。

没有 `Deref` trait 的话，编译器只会解引用 `&` 引用类型。`deref` 方法向编译器提供了获取任何实现了 `Deref` trait 的类型的值，并且调用这个类型的 `deref` 方法来获取一个它知道如何解引用的 `&` 引用的能力。
当我们在示例 15-9 中输入 `*y` 时，Rust 事实上在底层运行了如下代码：
`*(y.deref())`
Rust 将 `*` 运算符替换为先调用 `deref` 方法再进行普通解引用的操作，如此我们便不用担心是否还需手动调用 `deref` 方法了。Rust 的这个特性可以让我们写出行为一致的代码，无论是面对的是常规引用还是实现了 `Deref` 的类型。
`deref` 方法返回值的引用，以及 `*(y.deref())` 括号外边的普通解引用仍为必须的原因在于所有权。如果 `deref` 方法直接返回值而不是值的引用，其值（的所有权）将被移出 `self`。在这里以及大部分使用解引用运算符的情况下我们并不希望获取 `MyBox<T>` 内部值的所有权。
注意，每次当我们在代码中使用 `*` 时， `*` 运算符都被替换成了先调用 `deref` 方法再接着使用 `*` 解引用的操作，且只会发生一次，不会对 `*` 操作符无限递归替换，解引用出上面 `i32` 类型的值就停止了，这个值与示例 15-9 中 `assert_eq!` 的 `5` 相匹配。
### [函数和方法的隐式 Deref 强制转换](https://kaisery.github.io/trpl-zh-cn/ch15-02-deref.html#%E5%87%BD%E6%95%B0%E5%92%8C%E6%96%B9%E6%B3%95%E7%9A%84%E9%9A%90%E5%BC%8F-deref-%E5%BC%BA%E5%88%B6%E8%BD%AC%E6%8D%A2)

**Deref转换**（_deref coercions_）将实现了 `Deref` trait 的类型的引用转换为另一种类型的引用。例如，Deref 强制转换可以将 `&String` 转换为 `&str`，因为 `String` 实现了 `Deref` trait 因此可以返回 `&str`。Deref 强制转换是 Rust 在函数或方法传参上的一种便利操作，并且只能作用于实现了 `Deref` trait 的类型。当这种特定类型的引用作为实参传递给和形参类型不同的函数或方法时将自动进行。这时会有一系列的 `deref` 方法被调用，把我们提供的类型转换成了参数所需的类型。

![[Pasted image 20230415203655.png]]

作为展示 Deref 强制转换的实例，让我们使用示例 15-8 中定义的 `MyBox<T>`，以及示例 15-10 中增加的 `Deref` 实现。示例 15-11 展示了一个有着字符串 slice 参数的函数定义：
```RUST
fn hello(name: &str) {
    println!("Hello, {name}!");
}

```

示例 15-11：`hello` 函数有着 `&str` 类型的参数 `name`

可以使用字符串 slice 作为参数调用 `hello` 函数，比如 `hello("Rust");`。Deref 强制转换使得用 `MyBox<String>` 类型值的引用调用 `hello` 成为可能，如示例 15-12 所示：
```RUST
fn main() 
{ 
let m = MyBox::new(String::from("Rust"));
hello(&m);
}
```
示例 15-12：因为 Deref 强制转换，使用 `MyBox<String>` 的引用调用 `hello` 是可行的
这里使用 `&m` 调用 `hello` 函数，其为 `MyBox<String>` 值的引用。因为示例 15-10 中在 `MyBox<T>` 上实现了 `Deref` trait，Rust 可以通过 `deref` 调用将 `&MyBox<String>` 变为 `&String`。标准库中提供了 `String` 上的 `Deref` 实现，其会返回字符串 slice (`&str`)，这可以在 `Deref` 的 API 文档中看到。Rust 再次调用 `deref` 将 `&String` 变为 `&str`，这就符合 `hello` 函数的定义了。

当所涉及到的类型定义了 `Deref` trait，Rust 会分析这些类型并使用任意多次 `Deref::deref` 调用以获得匹配参数的类型。这些解析都发生在*编译*时，所以利用 Deref 强制转换并没有运行时损耗！

## RefCell 与内部可变性模式

**内部可变性**（_Interior mutability_）是 Rust 中的一个*设计模式*，它允许你即使在有不可变引用时也可以改变数据，这通常是借用规则所不允许的。为了改变数据，该模式在数据结构中使用 `unsafe` 代码来模糊 Rust 通常的可变性和借用规则。不安全代码表明我们在手动检查这些规则而不是让编译器替我们检查。第十九章会更详细地介绍不安全代码。

当你可以确保代码在运行时会遵守借用规则时，即使编译器不能保证，你可以选择使用那些运用*内部可变性模式*的类型。所涉及的 `unsafe` 代码将被封装进安全的 API 中，而*外部类型仍然是不可变*的。

让我们通过遵循内部可变性模式的 `RefCell<T>` 类型来开始探索。
对于引用，如果违反这些规则，会得到一个编译错误。而对于 `RefCell<T>`，如果违反这些规则程序会 panic 并退出。
在运行时检查借用规则的好处则是允许出现特定内存安全的场景，而它们在编译时检查中是不允许的。静态分析，正如 Rust 编译器，是天生保守的。但代码的一些属性不可能通过分析代码发现：其中最著名的就是 [停机问题（Halting Problem）](https://zh.wikipedia.org/wiki/%E5%81%9C%E6%9C%BA%E9%97%AE%E9%A2%98)，这超出了本书的范畴，不过如果你感兴趣的话这是一个值得研究的有趣主题。
因为*一些分析是不可能的*，此时即使代码安全但 Rust 编译器不能通过所有权规则编译，它可能会**拒绝一个正确的程序**；从这种角度考虑它是*保守*的。如果 Rust 接受不正确的程序，那么用户也就不会相信 Rust 所做的保证了。然而，如果 Rust 拒绝正确的程序，虽然会给程序员带来不便，但不会带来灾难。
`RefCell<T>` 正是用于当*你* 确信代码遵守借用规则，而编译器不能理解和确定的时候。

类似于 `Rc<T>`，`RefCell<T>` 只能用于单线程场景。如果尝试在多线程上下文中使用 `RefCell<T>`，会得到一个编译错误。第十六章会介绍如何在多线程程序中使用 `RefCell<T>` 的功能。

如下为选择 `Box<T>`，`Rc<T>` 或 `RefCell<T>` 的理由：
1.  `Rc<T>` 允许相同数据有多个所有者；`Box<T>` 和 `RefCell<T>` 有单一所有者。
2. 
-  `Box<T>` 允许在编译时执行*不可变或可变借用检查*；
- `Rc<T>` 仅允许在编译时执行*不可变借用* 检查 (RC 有多个多有者，所以由于遵守编译时借用检查规则，RC 只能提供不可变借用)；
- `RefCell<T>` 允许在*运行时*执行*不可变或可变借用*检查。
-   **因为 `RefCell<T>` 允许在运行时执行可变借用检查，所以我们可以在即便 `RefCell<T>` 自身是不可变的情况下修改其内部的值**

在不可变值内部改变值就是 **内部可变性** 模式。让我们看看何时内部可变性是有用的，并讨论这是如何成为可能的。
![[Pasted image 20230415205810.png]]
![[Pasted image 20230415205844.png]]

### [结合 `Rc<T>` 和 `RefCell<T>` 来拥有多个可变数据所有者](https://kaisery.github.io/trpl-zh-cn/ch15-05-interior-mutability.html#%E7%BB%93%E5%90%88-rct-%E5%92%8C-refcellt-%E6%9D%A5%E6%8B%A5%E6%9C%89%E5%A4%9A%E4%B8%AA%E5%8F%AF%E5%8F%98%E6%95%B0%E6%8D%AE%E6%89%80%E6%9C%89%E8%80%85)
Rc::clone () 会复制 pointer , value. clone () 会真正的另在堆中 clone 一份值
```RUST
#[derive(Debug)]
enum List {
    Cons(Rc<RefCell<i32>>, Rc<List>),
    Nil,
}
use crate::List::{Cons, Nil};
use std::cell::RefCell;
use std::rc::Rc;
fn main() {
    let value = Rc::new(RefCell::new(5));
    //注意  Rc::clone() 会复制pointer , value.clone()会真正的另在堆中clone一份值
    let a = Rc::new(Cons(Rc::clone(&value), Rc::new(Nil)));
    let b = Cons(Rc::new(RefCell::new(3)), Rc::clone(&a));
    let c = Cons(Rc::new(RefCell::new(4)), Rc::clone(&a));
    *value.borrow_mut() += 10;//value 这个 Rc 会自动解引用(deref)出里面的RefCell ,
                            //RefCell.borrow_mut() ->RefMut<> ,RefMut 会自动deref出里面的i32
    println!("a after = {:?}", a);
    println!("b after = {:?}", b);
    println!("c after = {:?}", c);
}
```


![[Pasted image 20230415211134.png]]


## 循环引用导致内存泄漏
[引用循环会导致内存泄漏 - Rust 程序设计语言 简体中文版 (kaisery.github.io)](https://kaisery.github.io/trpl-zh-cn/ch15-06-reference-cycles.html)
### [避免引用循环：将 `Rc<T>` 变为 `Weak<T>`](https://kaisery.github.io/trpl-zh-cn/ch15-06-reference-cycles.html#%E9%81%BF%E5%85%8D%E5%BC%95%E7%94%A8%E5%BE%AA%E7%8E%AF%E5%B0%86-rct-%E5%8F%98%E4%B8%BA-weakt)
到目前为止，我们已经展示了调用 `Rc::clone` 会增加 `Rc<T>` 实例的 `strong_count`，和只在其 `strong_count` 为 0 时才会被清理的 `Rc<T>` 实例。你也可以通过调用 `Rc::downgrade` 并传递 `Rc<T>` 实例的引用来创建其值的 **弱引用**（_weak reference_）。强引用代表如何共享 `Rc<T>` 实例的所有权。弱引用并不属于所有权关系，当 `Rc<T>` 实例被清理时其计数没有影响。他们不会造成引用循环，因为任何弱引用的循环会在其相关的强引用计数为 0 时被打断。
调用 `Rc::downgrade` 时会得到 `Weak<T>` 类型的智能指针。不同于将 `Rc<T>` 实例的 `strong_count` 加 1，调用 `Rc::downgrade` 会将 `weak_count` 加 1。`Rc<T>` 类型使用 `weak_count` 来记录其存在多少个 `Weak<T>` 引用，类似于 `strong_count`。其区别在于 `weak_count` 无需计数为 0 就能使 `Rc<T>` 实例被清理。
强引用代表如何共享 `Rc<T>` 实例的所有权，但弱引用并不属于所有权关系。他们不会造成引用循环，因为任何弱引用的循环会在其相关的强引用计数为 0 时被打断。
因为 `Weak<T>` 引用的值可能已经被丢弃了，为了使用 `Weak<T>` 所指向的值，我们必须确保其值仍然有效。为此可以调用 `Weak<T>` 实例的 `upgrade` 方法，这会返回 `Option<Rc<T>>`。如果 `Rc<T>` 值还未被丢弃，则结果是 `Some`；如果 `Rc<T>` 已被丢弃，则结果是 `None`。因为 `upgrade` 返回一个 `Option<Rc<T>>`，Rust 会确保处理 `Some` 和 `None` 的情况，所以它不会返回非法指针。
我们会创建一个某项知道其子项和父项的树形结构的例子，而不是只知道其下一项的列表。

# 多线程&并发
### [使用 `spawn` 创建新线程](https://kaisery.github.io/trpl-zh-cn/ch16-01-threads.html#%E4%BD%BF%E7%94%A8-spawn-%E5%88%9B%E5%BB%BA%E6%96%B0%E7%BA%BF%E7%A8%8B)
为了创建一个新线程，需要调用 `thread::spawn` 函数并传递一个闭包（第十三章学习了闭包），并在其中包含希望在新线程运行的代码。
注意当 Rust 程序的主线程结束时，新线程也会结束，而不管其是否执行完毕。
#### [使用 `join` 等待所有线程结束](https://kaisery.github.io/trpl-zh-cn/ch16-01-threads.html#%E4%BD%BF%E7%94%A8-join-%E7%AD%89%E5%BE%85%E6%89%80%E6%9C%89%E7%BA%BF%E7%A8%8B%E7%BB%93%E6%9D%9F)
由于主线程结束，示例 16-1 中的代码大部分时候不光会提早结束新建线程，因为无法保证线程运行的顺序，我们甚至不能实际保证新建线程会被执行！
可以通过将 `thread::spawn` 的返回值储存在变量中来修复新建线程部分没有执行或者完全没有执行的问题。`thread::spawn` 的返回值类型是 `JoinHandle`。`JoinHandle` 是一个拥有所有权的值，当对其调用 `join` 方法时，它会等待其线程结束。
```rust
use std::thread;
use std::time::Duration;

fn main() {
    let handle = thread::spawn(|| {
        for i in 1..10 {
            println!("hi number {} from the spawned thread!", i);
            thread::sleep(Duration::from_millis(1));
        }
    });

    for i in 1..5 {
        println!("hi number {} from the main thread!", i);
        thread::sleep(Duration::from_millis(1));
    }

    handle.join().unwrap();
}


```
### [线程与 `move` 闭包](https://kaisery.github.io/trpl-zh-cn/ch16-01-threads.html#%E7%BA%BF%E7%A8%8B%E4%B8%8E-move-%E9%97%AD%E5%8C%85)

`move` 关键字经常用于传递给 `thread::spawn` 的闭包，因为闭包会获取从环境中取得的值的所有权，因此会将这些值的所有权从一个线程传送到另一个线程。在第十三章 [“闭包会捕获其环境”](https://kaisery.github.io/trpl-zh-cn/ch13-01-closures.html#%E9%97%AD%E5%8C%85%E4%BC%9A%E6%8D%95%E8%8E%B7%E5%85%B6%E7%8E%AF%E5%A2%83) 部分讨论了闭包上下文中的 `move`。现在我们会更专注于 `move` 和 `thread::spawn` 之间的交互。

在第十三章中，我们讲到可以在参数列表前使用 `move` 关键字强制闭包获取其使用的环境值的所有权。这个技巧在创建新线程将值的所有权从一个线程移动到另一个线程时最为实用。

通过在闭包之前增加 `move` 关键字，我们强制闭包获取其使用的值的所有权，而不是任由 Rust 推断它应该借用值。
```rust
use std::thread;

fn main() {
    let v = vec![1, 2, 3];

    let handle = thread::spawn(move || {
        println!("Here's a vector: {:?}", v);
    });

    handle.join().unwrap();
}

```
Rust 的所有权规则又一次帮助了我们！通过告诉 Rust 将 `v` 的所有权移动到新建线程，我们向 Rust 保证主线程不会再使用 `v`。

