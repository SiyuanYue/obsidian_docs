#define __LIBRARY__                              /* 有它，_syscall1等才有效。详见unistd.h */
#include <unistd.h>
#include <stdio.h>
#include <errno.h>
_syscall2(int, whoami,char *,name,unsigned int,size);



int main(int argc,char **argv){
    char username[64] = {0};
    /*调用系统调用whoami()*/
    whoami(username,24);
    printf("%s\n", username);
    return 0;
    return 0;
}
