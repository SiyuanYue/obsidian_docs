# Lab4 系统调用
# 实验目的
- 建立对系统调用接口的深入认识

- 掌握系统调用的基本过程

- 能完成系统调用的全面控制

- 为后续实验做准备

# 实验环境：
vmware 16；Ubuntu 20x04 ; 老师提供的新环境

# 实验内容：
此次实验的基本内容是：在 `Linux 0.11` 上添加两个系统调用，并编写两个简单的应用程序测试它们。

### 1. `iam()`
第一个系统调用是 `iam()` ，其原型为：
`int iam(const char * name);`
完成的功能是将字符串参数 `name` 的内容拷贝到内核中保存下来。 要求 `name` 的长度不能超过 `23` 个字符。返回值是拷贝的字符数。 如果 `name` 的字符个数超过了 `23` ，则返回 `-1` ，并置 `errno` 为 `EINVAL` 。
```C
int sys_iam(const char * name){
    //完成的功能是将字符串参数 name 的内容拷贝到内核中保存下来。 要求 name 的长度不能超过 23 个字符。返回值是拷贝的字符数。 如果 name 的字符个数超过了 23 ，则返回 -1 ，并置 errno 为 EINVAL 。
    char myname[25]={0};
    int idx=0;
    do{
        myname[idx]=get_fs_byte(name+idx);
    }while(myname[idx]!=0 && idx++<=23);
    if(strlen(myname)>23){
        errno=EINVAL;
        return (-1);
    }
    // printk("%s\n",myname);
    strcpy(_name,myname);
    _name[23]=0;
    // printk("%s\n",_name);
    return idx;
}
```

### 2. `whoami()`
第二个系统调用是 `whoami()` ，其原型为：
`int whoami(char* name, unsigned int size);`

它将内核中由 `iam()` 保存的名字拷贝到 `name` 指向的用户地址空间中， 同时确保不会对 `name` 越界访存（ `name` 的大小由 `size` 说明）。 返回值是拷贝的字符数。如果 `size` 小于需要的空间，则返回 `-1` ，并置 `errno` 为 `EINVAL` 。
```C
int sys_whoami(char* name, unsigned int size){
    //它将内核中由 iam() 保存的名字拷贝到 name 指向的用户地址空间中， 同时确保不会对 name 越界访存（ name 的大小由 size 说明）。 返回值是拷贝的字符数。如果 size 小于需要的空间，则返回 -1 ，并置 errno 为 EINVAL 。
    int len=strlen(_name);
    if(size<len)
    {
        errno=EINVAL;
        return (-1);
    }
    else{
        int i = 0;
        for (i = 0; i < len; i++)
        {
            // copy from kernel mode to user mode
            put_fs_byte(_name[i], name + i);
        }
        return len;
    }
}
```

>注意内核数据段和用户态是不一样的，在这两个地址空间交换数据，要通过两个函数 `get_fs_byte()` 和`put_fs_byte()`
### 测试程序
运行添加过新系统调用的 `Linux 0.11` ，在其环境下编写两个测试程序 `iam.c` 和 `whoami.c` 。最终的运行结果是：
![](images/Pasted%20image%2020230622163945.png)


# 实验结果：
1. 将 `testlab2.c` 在修改过的 `Linux 0.11` 上编译运行，显示的结果：
![](images/Pasted%20image%2020230622163945.png)
在用户名超过 23 个字符后， `errno` 的值没有置为 `EINVAL`, 但是在系统调用里明明实现了这一项，一查看，发现 `_syscall1()` 宏中，当返回-1 时，会将 errno 的值强行更改为 1，这跟本实验验收方式冲突了：
![](images/Pasted%20image%2020230622164623.png)
2. 运行 `testlab2.sh`，通过。
![](images/Pasted%20image%2020230622165315.png)

# 问题解答

- 从 `Linux 0.11` 现在的机制看，它的系统调用最多能传递几个参数？
    就三个：Linux 系统使用了通用寄存器传递方法，寄存器 ebx、ecx 和 edx。
- 你能想出办法来扩大这个限制吗？
    1. 使用堆栈传递参数：在堆栈中为系统调用分配一定的空间，用于传递参数。
    2. 使用结构体传递参数：将所有参数封装到一个结构体中，并将指向该结构体的指针作为系统调用的参数进行传递。
- 用文字简要描述向 `Linux 0.11` 添加一个系统调用 `foo()` 的步骤。
	1. 添加 iam 和 whoami 系统调用编号的宏，文件：*include/unistd. h*,  E.G:  `#define __NR_foo   74`
	2. 修改系统调用总数（+1）, 文件：*kernel/system_call. s*
	3. 为新增的系统调用添加系统调用名并维护系统调用表，文件：*include/linux/sys. h*
	4. 编写 foo 系统调用的实现代码
	5. 修改 Makefile : `OBJS` 后加入 `foo.o` , `Dependencies` 中加入 foo 相关依赖。
