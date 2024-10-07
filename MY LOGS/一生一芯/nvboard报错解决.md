```shell
Error: ‘TTF_SetFontSize’ was not declared in this scope; did you mean ‘TTF_SetFontStyle’?
   20 |   TTF_SetFontSize (font, CH_HEIGHT);
      |   ^~~~~~~~~~~~~~~
      |   TTF_SetFontStyle 
```

解决方法：
先`sudo apt remove libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev` 删掉 `apt` 或者默认安装的这三个库
然后在github上分别重新安装这三个库
先安装 `SDL2`：
[Releases · libsdl-org/SDL (github.com)](https://github.com/libsdl-org/SDL/releases)
Ubuntu 是 linux 系统，我选的是这个版本：[SDL2-2.30.1.tar.gz](https://github.com/libsdl-org/SDL/releases/download/release-2.30.1/SDL2-2.30.1.tar.gz) 
在 Ubuntu 内下好解压后 `cd SDL2-2.30.1/` 进入目录
然后输入：
`./configure --prefix=/usr` 这样设置后会生成 Makefile, 并在待会 `install` 时指定头文件装在 `/usr/include/SDL2`，等会编译出的动态库和静态库装在 `/usr/lib`
然后 `make -j3` 编译即可
然后 `sudo make install` 这里会将编译出的动态库和静态库会装在 `/usr/lib` 我们前面设定好的地方
然后安装 `SDL2_ttf`:
https://github.com/libsdl-org/SDL_ttf/releases/download/release-2.20.0/SDL2_ttf-2.20.0.tar.gz
编译安装步骤与 `SDL2` 一模一样
最后安装 `SDL2_img`:
https://github.com/libsdl-org/SDL_image/releases/download/release-2.8.2/SDL2_image-2.8.2.tar.gz
编译安装步骤与前面两个一样
然后进入 `nvboard/example` 目录下：
`make run` 即可
![[Pasted image 20240324013233.png]]

如果 `make` 成功，`make run` 或者 `./build/top` 运行失败，报这种类似的错误：
```shell
make run
top: /home/ysy/Desktop/code/ysyx/ysyx-workbench/nvboard/src/render. Cpp:19: SDL_Texture* surface 2 texture (SDL_Renderer*, SDL_Surface*): Assertion `t != NULL' failed.
Make: *** [Makefile:52: run] Aborted (core dumped) 
```
可以输入
`ldd ./build/top`  这个命令来查看该可执行程序链接的动态库位置是不是我们在 `/usr/lib` 下装好的库：
```shell
Ldd ./build/top
        Linux-vdso. So. 1 (0 x 00007 fffe 27 e 0000)
        LibSDL 2-2.0. So. 0 => /usr/lib/libSDL 2-2.0. So. 0 (0 x 00007 fe 260 e 8 e 000)
        LibSDL 2_image-2.0. So. 0 => /usr/lib/libSDL 2_image-2.0. So. 0 (0 x 00007 fe 260 e 62000)
        LibSDL 2_ttf-2.0. So. 0 => /usr/lib/libSDL 2_ttf-2.0. So. 0 (0 x 00007 fe 260 ca 5000) 
        ...
```
要对上，如果链接的是 `/lib/x86_64-linux-gnu/`，那是 `apt` 或者默认安装的库，库版本存在 BUG 或者版本过老，可以直接删掉（别删错多删别的东西），删掉后会链接到我们前面装好的库。
一般前面我们运行 `sudo apt remove libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev` 时候就会删掉 `apt` 或者默认安装的库的。

后面是废话


---

排查历程：
折腾好长时间查出来是 Ubuntu 用`apt install libsdl2-ttf-dev` 的 SDL_ttf 库中就是没有这两个函数的声明和定义。只能删掉装的 `sdl_ttf` 库去 https://github.com/libsdl-org/SDL_ttf/ 重新下载，这里面的 sdl_ttf. H 是有这两函数声明和定义的。 
但是依旧无法安装，编译报错找不到 `ft2build.h`, 但明明已经安装了 `libfreetype 6-dev`。上网查询使用软连接 `ln -s /usr/include/freetype 2/freetype/ /usr/include/freetype` 
这下可以找到头文件了，但是又报新错误了：`undefined reference to FT_MulFix' 。 
啊！！！！ 
 
之后查了查谷歌和官网，打算再度装一下 `SDL_ttf `
我装了这个： https://github.com/libsdl-org/SDL_ttf/releases/download/release-2.20.0/SDL2_ttf-2.20.0.tar.gz 这次起码可以正常编译了，不会报告有关 freetype 的错误，注意不要下载 2.20 release 下的 source code，上面就是下的那个，不知道为什么会编译报告 freetype 的错。 
还试过下载 2.0.28，但 2.0.28 要求安装的 SDL 2 version > 2.0.12, 所以又换回了 SDL_fft 2.20.0 ,这个要求 SDL 2 version > 2.0.10, 刚好是满足的（apt 安装的 SDL 2 就是 2.0.10的版本） 
如下步骤编译安装 SDL_fft:
`$./configure  --prefix=/usr`（之前没用 configure 导致做了一堆无用功，这个库没什么文档和提示很烦，通过--prefix=/usr 会让头文件复制到/usr/include 编译出的动态库静态库会在/usr/lib）
`$ make `
`$ sudo make install `
 
然后回到 nvboard/example 下：输入 `make run`： 
Build/top: symbol lookup error: build/top: undefined symbol: TTF_RenderText_Shaded_Wrapped
Make: *** [Makefile:52: run] Error 127  

---- 

啊！！！！！终于解决了 ： 

修改 NVBoard/Example 下的 Makefile，让它指定链接到刚刚编译 SDL 2_ttf 生成的名为 libSDL 2_ttf. So 的动态库。（前面编译安装到了系统目录/usr/lib） :
`LDFLAGS += -lSDL 2_ttf`
后面 LDFLAGS 变量会被传递给编译用的指令（观察前面 make 报错指示的 Makefile 行数） 。 
`make` 输出的编译命令最后一条：`g++    auto_bind. O main. O verilated. O verilated_threads. O Vtop__ALL. A   /home/ysy/Desktop/code/ysyx/ysyx-workbench/nvboard/build/nvboard. A -lSDL 2_ttf -lSDL 2 -lSDL 2_image -lSDL 2_ttf  -pthread -lpthread -latomic   -o /home/ysy/Desktop/code/ysyx/ysyx-workbench/nvboard/example/build/top` 
也可以看出成功链接到 SDL 2_ttf 库，`make`终于不报错了, 解决！！！！！！！！！！！ 

---
解决个屁！而且根本不需要改这个 Makefile，我眼瞎了都没发现上面那条编译命令 `lSDL2_ttf -lSDL 2 -lSDL 2_image -lSDL2_ttf` 出现了两次 `lSDL2_ttf`, 把 Makefile 自己添加的删了，复原。
因为重新安了 SDL_ttf 库并删除了系统装的可以通过编译。
但是一旦运行 top 或者 make run 还是报错
————
解决了!!
学会了一招：
```shell
 ldd ./build/top
 linux-vdso.so.1 (0x00007ffc68df4000)
        libSDL2-2.0.so.0 => /lib/x86_64-linux-gnu/libSDL2-2.0.so.0 (0x00007f742dd9b000)
        libSDL2_image-2.0.so.0 => /lib/x86_64-linux-gnu/libSDL2_image-2.0.so.0 (0x00007f742dd78000)
        libSDL2_ttf-2.0.so.0 => /lib/x86_64-linux-gnu/libSDL2_ttf-2.0.so.0 (0x00007f742dd6f000)
        libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007f742dd4c000)
        libstdc++.so.6 => /lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007f742db6a000)
        ...
```
可以看到并没有链接到前面安装的 `/usr/lib/libSDL2_ttf-2.0.so`, 而是在链接 `/lib/x86_64-linux-gnu/libSDL2_ttf-2.0.so.0 `
直接删除掉这个可能存在错误的库。
之后成功链接到前面安装的库：
```shell
ldd ./build/top
        linux-vdso.so.1 (0x00007ffdf5bd0000)
        libSDL2-2.0.so.0 => /lib/x86_64-linux-gnu/libSDL2-2.0.so.0 (0x00007fd931e7c000)
        libSDL2_image-2.0.so.0 => /lib/x86_64-linux-gnu/libSDL2_image-2.0.so.0 (0x00007fd931e59000)
        libSDL2_ttf-2.0.so.0 => /lib/libSDL2_ttf-2.0.so.0 (0x00007fd931c9c000)
        ...
```
终于不报这个报错了!!

但是： 
```shell
make run
top: /home/ysy/Desktop/code/ysyx/ysyx-workbench/nvboard/src/render. Cpp:19: SDL_Texture* surface 2 texture (SDL_Renderer*, SDL_Surface*): Assertion `t != NULL' failed.
Make: *** [Makefile:52: run] Aborted (core dumped) 
```
`nvboard` 自己代码中的 `assert` 触发停掉了。。。 
我感觉还是 SDL 库的问题，所以把 `apt` 下载的 SDL 2 和 SDL 2_img 都 `remove` 了。 
全部从 github 上下载了比较新的版本代码，跟上面 SDL 2_ttf 库一样的编译安装流程。然后 nvboard 的样例 make 后的 top： 

```shell
Ldd ./build/top
        Linux-vdso. So. 1 (0 x 00007 fffe 27 e 0000)
        LibSDL 2-2.0. So. 0 => /usr/lib/libSDL 2-2.0. So. 0 (0 x 00007 fe 260 e 8 e 000)
        LibSDL 2_image-2.0. So. 0 => /usr/lib/libSDL 2_image-2.0. So. 0 (0 x 00007 fe 260 e 62000)
        LibSDL 2_ttf-2.0. So. 0 => /usr/lib/libSDL 2_ttf-2.0. So. 0 (0 x 00007 fe 260 ca 5000) 
        ...
```
 终于 `make run` 成功出现了 nvboard 画面！！！！！！解决！！！！！！！！！！！！！！！！！！

![[Pasted image 20240324013233.png]]
