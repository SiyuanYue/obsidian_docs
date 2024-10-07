
#gcc #编译器

 `man gcc`   #man
 （关于 man 指令：[LINUX帮助命令 - 知乎 (zhihu.com)](https://zhuanlan.zhihu.com/p/433100914) ）[man入门教程 · GitBook (nju-projectn.github.io)](https://nju-projectn.github.io/ics-pa-gitbook/ics2019/man.html)
    [Linux入门教程 · GitBook (nju-projectn.github.io)](https://nju-projectn.github.io/ics-pa-gitbook/ics2019/linux.html#%E6%8E%A2%E7%B4%A2%E5%91%BD%E4%BB%A4%E8%A1%8C)   #linux 
 当然你也可以`man man` ,是的，你没看错捏！）

1、预处理（preprocessing）

*  -E 选项指示编译器仅对输入文件进行预处理  

e.g.  `gcc -E test.cpp -o test.i //.i文件`

2、编译（compilation）

*  -S 编译选项 gcc 在为 C 代码产生了汇编语言文件后停止编译  
*  gcc 产生的汇编语言文件的缺省扩展名是 .s //.s文件  

e.g.  `gcc -S test.i -o test.s`

3、汇编（assembly）

* -c 选项告诉 gcc 仅把源代码编译为机器语言的目标代码  
* 默认 gcc 建立的目标代码文件有一个 `.o` 的扩展名。 //`.o文件`

e.g.  `gcc -c test.s -o test.o`

4、链接（link）

* -o 编译选项来为将产生的可执行文件用指定的文件名  

`gcc test.o -o test //bin(二进制)文件`

## GCC重要编译参数

-g 编译带调试信息的可执行文件
```c
# -g 选项告诉 GCC 产生能被 GNU 调试器GDB使用的调试信息，以调试程序。
# 产生带调试信息的可执行文件test
g++ -g test.cpp
```
-O[n] 优化源代码

```c
## 所谓优化，例如省略掉代码中从未使用过的变量、直接将常量表达式用结果值代替等等，这些操作会缩减目标文件所包含的代码量，提高最终生成的可执行文件的运行效率。
# -O 选项告诉 g++ 对源代码进行基本优化。这些优化在大多数情况下都会使程序执行的更快。 -O2 选项告诉 g++ 产生尽可能小和尽可能快的代码。 如-O2，-O3，-On（n 常为0–3）
# -O 同时减小代码的长度和执行时间，其效果等价于-O1
# -O0 表示不做优化
# -O1 为默认优化
# -O2 除了完成-O1的优化之外，还进行一些额外的调整工作，如指令调整等。
# -O3 则包括循环展开和其他一些与处理特性相关的优化工作。
# 选项将使编译的速度比使用 -O 时慢， 但通常产生的代码执行速度会更快。
# 使用 -O2优化源代码，并输出可执行文件
g++ -O2 test.cpp
```

-l (小写*l* )和 -L 指定库文件    |    指定库文件路径

```c
# -l参数(小写)就是用来指定程序要链接的库，-l参数紧接着就是库名
# 在/lib和/usr/lib和/usr/local/lib里的库直接用-l参数就能链接
# 链接glog库
g++ -lglog test.cpp
# 如果库文件没放在上面三个目录里，需要使用-L参数(大写)指定库文件所在目录
# -L参数跟着的是库文件所在的目录名
# 链接mytest库，libmytest.so在/home/bing/mytestlibfolder目录下
g++ -L/home/bing/mytestlibfolder -lmytest test.cpp
```

-I (大写*i* ) 指定头文件搜索目录

```c
# -I 
# /usr/include目录一般是不用指定的，gcc知道去那里找，但 是如果头文件不在/usr/icnclude里我们就要用-I参数指定了，比如头文件放在/myinclude目录里，那编译命令行就要加上-I/myinclude 参数了，如果不加你会得到一个”xxxx.h: No such file or directory”的错误。-I参数可以用相对路径，比如头文件在当前 目录，可以用-I.来指定。上面我们提到的–cflags参数就是用来生成-I参数的。
g++ -I/myinclude test.cpp
```

-Wall 打印警告信息

```text
# 打印出gcc提供的警告信息
g++ -Wall test.cpp
```

-w 关闭警告信息

```text
# 关闭所有警告信息
g++ -w test.cpp
```

-werror 把所有的告警信息转化为错误信息，并在告警发生时终止编译过程

-std=c++11 设置编译标准

```c
# 使用 c++11 标准编译 test.cpp
g++ -std=c++11 test.cpp
```

-o 指定输出文件名

```c
# 指定即将产生的文件名
# 指定输出可执行文件名为test
g++ test.cpp -o test
```

-D 定义宏

```c
# 在使用gcc/g++编译的时候定义宏
# 常用场景：
# -DDEBUG 定义DEBUG宏，可能文件中有DEBUG宏部分的相关信息，用个DDEBUG来选择开启或关闭DEBUG
```

-v 打印出编译器内部编译各过程的命令行信息和编译器的版本

-static 链接静态库

-fPIC
```
在生成动态库时，常常习惯性的加上 fPIC 选项，fPIC 有什么作用和意义，加不加有什么区别，这里做下小结。

fPIC 的全称是 Position Independent Code， 用于生成位置无关代码。

1.不加fPIC
即使不加 fPIC 也可以生成 .so 文件，但是对于源文件有要求，例如因为不加 fPIC 编译的 so 必须要在加载到用户程序的地址空间时重定向所有表目，所以在它里面不能引用其它地方的代码，

2、加 fPIC 选项
加上 fPIC 选项生成的动态库，显然是位置无关的，这样的代码本身就能被放到线性地址空间的任意位置，无需修改就能正确执行。通常的方法是获取指令指针的值，加上一个偏移得到全局变量 / 函数的地址。
加 fPIC 选项的源文件对于它引用的函数头文件编写有很宽松的尺度。比如只需要包含个声明的函数的头文件，即使没有相应的 C 文件来实现，编译成 so 库照样可以通过。

3、在内存引用上，加不加 fPIC 的异同
加了 fPIC 实现真正意义上的多个进程共享 so 文件。
多个进程引用同一个 PIC 动态库时，可以共用内存。这一个库在不同进程中的虚拟地址不同，但操作系统显然会把它们映射到同一块物理内存上。
对于不加 fPIC，则加载 so 文件时，需要对代码段引用的数据对象需要重定位，重定位会修改代码段的内容，这就造成每个使用这个 .so 文件代码段的进程在内核里都会生成这个 .so 文件代码段的 copy。每个 copy 都不一样，取决于这个 .so 文件代码段和数据段内存映射的位置。
可见，这种方式更消耗内存。
但是不加 fPIC 编译的 so 文件的优点是加载速度比较快。

```
链接  https://blog.csdn.net/itworld123/article/details/117587091

-llibrary 连接名为 library 的库文件




----
# [实战]g++/gcc 命令行编译
案例：最初目录结构: 2 directories, 3 files
最初目录结构
```text
├── include
│   └── Swap.h
├── main.cpp
└── src
    └── Swap.cpp
2 directories, 3 files
```

### 1. 直接编译

**最简单的编译，并运行。**
将 `main.cpp src/Swap.cpp` 编译为可执行文件。
`g++ main.cpp src/Swap.cpp -Iinclude`

运行a.out
`./a.out`

**增加参数编译，并运行**
**将 main.cpp src/Swap.cpp 编译为可执行文件 附带一堆参数**
`g++ main.cpp src/Swap.cpp -Iinclude -std=c++11 -O2 -Wall -o b.out`

运行`b.out`
`./b.out`

### 2. 生成库文件并编译

**链接静态库生成可执行文件①：**

进入`src`目录下
`$cd src`

汇编，生成`Swap.o`文件
`g++ Swap.cpp -c -I../include`

生成静态库`libSwap.a`
`ar rs libSwap.a Swap.o`

回到上级目录
`$cd ..`

**链接，生成可执行文件:`staticmain`**
`g++ main.cpp -Iinclude -Lsrc -lSwap -o staticmain`

**链接动态库生成可执行文件②：**

进入src目录下
`$cd src`

生成动态库`libSwap.so`
`g++ Swap.cpp -I../include -fPIC -shared -o libSwap.so`
上面命令等价于以下两条命令:
`# gcc Swap.cpp -I../include -c -fPIC`
`gcc -shared -o libSwap.so Swap.o`

回到上级目录
`$cd ..`

链接，生成可执行文件:`sharemain`
`g++ main.cpp -Iinclude -Lsrc -lSwap -o sharemain`

编译完成后的目录结构
最终目录结构：2 directories, 8 files
```
 最终目录结构
 .
 ├── include
 │   └── Swap.h
 ├── main.cpp
 ├── sharemain
 ├── src
 │   ├── libSwap.a
 │   ├── libSwap.so
1│   ├── Swap.cpp
1│   └── Swap.o
1└── staticmain
1
12 directories, 8 files
```

### 3. 运行可执行文件
运行可执行文件①
```
# 运行可执行文件
./staticmain
```
运行可执行文件②
```
# 运行可执行文件
LD_LIBRARY_PATH=src ./sharemain
```

