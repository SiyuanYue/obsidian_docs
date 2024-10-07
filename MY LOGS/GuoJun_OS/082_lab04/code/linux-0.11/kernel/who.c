#include <errno.h>
#include <string.h>

#include <asm/segment.h>
extern int errno;
char _name[24];
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
