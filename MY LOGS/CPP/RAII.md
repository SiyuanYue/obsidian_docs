# RAII
[RAII - cppreference.com](https://zh.cppreference.com/w/cpp/language/raii)

_资源获取即初始化_（_Resource Acquisition Is Initialization_），或称 RAII，是一种 C++ 编程技术 ，它将必须在使用前请求的资源（分配的堆内存、执行线程、打开的套接字、打开的文件、锁定的互斥体、磁盘空间、数据库连接等——任何存在受限供给中的事物）的生命周期与一个对象的[生存期]( https://zh.cppreference.com/w/cpp/language/lifetime "cpp/language/lifetime") 相绑定。

RAII 保证资源能够用于任何会访问该对象的函数（资源可用性是一种[类不变式](https://en.wikipedia.org/wiki/Class_invariant "enwiki:Class invariant")，这会消除冗余的运行时测试）。它也保证对象在自己生存期结束时会以获取顺序的逆序释放它控制的所有资源。类似地，如果资源获取失败（构造函数以异常退出），那么已经构造完成的对象和基类子对象所获取的所有资源就会以初始化顺序的逆序释放。这有效地利用了语言特性（[对象生存期](https://zh.cppreference.com/w/cpp/language/lifetime "cpp/language/lifetime")、[退出作用域](https://zh.cppreference.com/w/cpp/language/statements "cpp/language/statements")、[初始化顺序](https://zh.cppreference.com/w/cpp/language/initializer_list#.E5.88.9D.E5.A7.8B.E5.8C.96.E9.A1.BA.E5.BA.8F "cpp/language/initializer list")以及[栈回溯](https://zh.cppreference.com/w/cpp/language/throw#.E6.A0.88.E5.9B.9E.E6.BA.AF "cpp/language/throw")）以消除内存泄漏并保证异常安全。根据 RAII 对象的生存期在退出作用域时结束这一基本状况，此技术也被称为_作用域界定的资源管理_（_Scope-Bound Resource Management_，SBRM）。

RAII 可以总结如下:

- 将每个资源封装入一个类，其中：

- 构造函数请求资源，并建立所有类不变式，或在它无法完成时抛出异常，
- 析构函数释放资源并且决不会抛出异常；

- 在使用资源时始终通过 RAII 类的满足以下要求的实例：

- 自身拥有自动存储期或临时生存期，或
- 具有与自动或临时对象的生存期绑定的生存期

|   |   |
|---|---|
|移动语义使得在对象间，跨作用域，以及在线程内外安全地移动所有权，而同时维护资源安全成为可能。|(C++11 起)|

拥有 `open()/close()`、`lock()/unlock()`，或 `init()/copyFrom()/destroy()` 成员函数的类是典型的非 RAII 类的例子：
```CPP
[std::mutex](http://zh.cppreference.com/w/cpp/thread/mutex) m;
 
void bad() 
{
    m.lock();                    // 请求互斥体
    f();                         // 如果 f() 抛出异常，那么互斥体永远不会被释放
    if(!everything_ok()) return; // 提早返回，互斥体永远不会被释放
    m.unlock();                  // 只有 bad() 抵达此语句，互斥体才会被释放
}
 
void good()
{
    [std::lock_guard](http://zh.cppreference.com/w/cpp/thread/lock_guard)<[std::mutex](http://zh.cppreference.com/w/cpp/thread/mutex)> lk(m); // RAII类：互斥体的请求即是初始化
    f();                               // 如果 f() 抛出异常，那么就会释放互斥体
    if(!everything_ok()) return;       // 提早返回也会释放互斥体
}                                      // 如果 good() 正常返回，那么就会释放互斥体
```

### 标准库

C++ 标准库遵循 RAII 管理其自身的资源：[std::string](https://zh.cppreference.com/w/cpp/string/basic_string "cpp/string/basic string")、[std::vector](https://zh.cppreference.com/w/cpp/container/vector "cpp/container/vector")、[std::jthread](https://zh.cppreference.com/w/cpp/thread/jthread "cpp/thread/jthread") (C++20 起)，以及很多其他在构造函数中获取资源（错误时抛出异常），并在析构函数中将其释放（决不抛出）而不要求显式清理的类。

|   |   |
|---|---|
|另外，标准库提供几种 RAII 包装器以管理用户提供的资源：<br><br>- [std::unique_ptr](https://zh.cppreference.com/w/cpp/memory/unique_ptr "cpp/memory/unique ptr") 及 [std::shared_ptr](https://zh.cppreference.com/w/cpp/memory/shared_ptr "cpp/memory/shared ptr") 用于管理动态分配的内存，或以用户提供的删除器管理任何以普通指针表示的资源；<br>- [std::lock_guard](https://zh.cppreference.com/w/cpp/thread/lock_guard "cpp/thread/lock guard")、[std::unique_lock](https://zh.cppreference.com/w/cpp/thread/unique_lock "cpp/thread/unique lock")、[std::shared_lock](https://zh.cppreference.com/w/cpp/thread/shared_lock "cpp/thread/shared lock") 用于管理互斥体。|(C++11 起)|

### 注解

RAII 不适用于不会在使用前请求的资源：CPU 时间、核心，以及缓存容量、熵池容量、网络带宽、电力消费、栈内存等。