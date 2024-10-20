
理解 new 运算符  
首先，**new** 关键字是一个运算符，可以被*重载* ！
其次 **new** 与**delete** 一起使用，清理分配的内存。
new ：
1. 通过操作系统 C 库 malloc 内存，并返回对应指针
2. 在内存上调用构造函数

关于 new 数组和 delete 数组采用新运算符：
```CPP
int *b =new int[50]; //operator new[]
delete[] b;
```

通过 new 在特定的内存地址上调用构造函数
```CPP
class Entity  
{  
private:  
    String m_Name;  
public:  
    Entity():m_Name("Unknow"){}  
    Entity(const String &str):m_Name(str){}  
    const String & GetName() const{  
        return this->m_Name;  
    }  
};
int *b =new int[50]; //operator new[]
Entity *c=new(b) Entity();           //***
```

