#define __LIBRARY__                              /* 有它，_syscall1等才有效。详见unistd.h */
#include <unistd.h>
#include <linux/kernel.h>
#include <errno.h>
extern int errno;                    /* 有它，编译器才能获知自定义的系统调用的编号 */
_syscall1(int, iam, const char*, name);          /* iam()在用户空间的接口函数 */

int main(int argc,char **argv){
    iam(argv[1]);
    return 0;
}


