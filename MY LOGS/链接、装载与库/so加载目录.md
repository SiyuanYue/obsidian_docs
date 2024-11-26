#  `LD_LIBRARY_PATH` 环境变量
要设置共享库（动态链接库）的加载目录，具体的方法取决于你使用的操作系统。下面是 Windows 和 Linux/macOS 的常见方法：

### 在 Linux/macOS 上：
1. **使用 `LD_LIBRARY_PATH` 环境变量**： 你可以通过设置 `LD_LIBRARY_PATH` 环境变量来指定共享库的加载目录。可以在终端中使用以下命令：

    
    `export LD_LIBRARY_PATH=/path/to/your/libs:$LD_LIBRARY_PATH`
    
    如果想要在每次启动终端时都加载这个路径，可以将上述命令添加到你的 `~/.bashrc` 或 `~/.bash_profile` 文件中。
    
2. **使用 `ldconfig`**： 如果你有权限，可以将库文件放入 `/usr/local/lib` 或 `/usr/lib` 目录中，然后运行 `ldconfig` 更新链接缓存。可以使用以下命令：

    `sudo cp yourlib.so /usr/local/lib sudo ldconfig`
    

### 在 Windows 上：
1. **使用 `PATH` 环境变量**： 在 Windows 中，你可以通过修改 `PATH` 环境变量来指定共享库的搜索路径。在命令提示符下，可以使用以下命令：
    
    `set PATH=C:\path\to\your\libs;%PATH%`
    
    或者，可以在系统属性中手动添加路径：
    
    - 右键点击“计算机”或“此电脑”，选择“属性”。
    - 点击“高级系统设置”。
    - 在“系统属性”窗口中，点击“环境变量”。
    - 在“系统变量”中找到 `Path`，然后编辑，添加你的库路径。
2. **放置在可执行文件同一目录**： 另一种方法是将共享库放置在你的可执行文件的同一目录下，Windows 会自动搜索这个目录。


#  `RUNPATH`

`RUNPATH` 是一种用于指定共享库搜索路径的机制，通常在 ELF 格式的可执行文件和共享库中使用。它允许在运行时指定哪些目录应该被搜索以找到依赖的共享库。`RUNPATH` 是可执行文件在编译时指定的，主要用于 Linux 和其他类 Unix 系统。

### 如何设置 `RUNPATH`

1. **使用编译选项**： 在编译程序时，可以通过 `-Wl,-rpath` 选项来设置 `RUNPATH`。例如，使用 `gcc` 编译 C 语言程序时，可以这样设置：
    
    `gcc -o my_program my_program.c -Wl,-rpath,/path/to/your/libs`
    这将把 `/path/to/your/libs` 添加到 `RUNPATH` 中。
    
2. **使用 `chrpath` 工具**： 如果你已经有了一个可执行文件，可以使用 `chrpath` 工具来修改其 `RUNPATH`。例如：
    
    `chrpath -r /new/path/to/libs my_program`
    
3. **使用 `patchelf` 工具**： `patchelf` 是另一个工具，可以用来设置或修改可执行文件的 `RUNPATH`。例如：
    
    `patchelf --set-rpath /path/to/your/libs my_program`
    

### 优先级

`RUNPATH` 的优先级低于 `LD_LIBRARY_PATH` 和 `LD_PRELOAD`，但高于默认的系统库路径。这意味着：

- 如果在运行时设置了 `LD_LIBRARY_PATH`，系统会优先搜索这个环境变量中指定的路径。
- 如果没有设置 `LD_LIBRARY_PATH`，则会搜索 `RUNPATH` 中指定的路径。
- 如果 `RUNPATH` 也没有，系统会搜索默认的系统库路径（如 `/lib`, `/usr/lib` 等）。

### 注意事项

- 使用 `RUNPATH` 是一种更安全的方法，因为它是在编译时就已经确定的，而不依赖于运行时的环境设置。
- 不同于 `RPATH`，如果使用 `RUNPATH`，在系统的库路径中找不到库时会抛出错误，而不是从 `RUNPATH` 中的路径继续查找。