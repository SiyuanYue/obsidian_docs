

# iterator
每个 Iterator 都会有的五个typedef
```C++
typedef ptrdiff_t            difference_type;  
typedef std::bidirectional_iterator_tag    iterator_category;  
typedef _Tp             value_type;  
typedef _Tp*            pointer;  
typedef _Tp&            reference;
```

前置++没有参数，后置++有个无用的区分参数：
```C++
     _Self&  
     operator++() _GLIBCXX_NOEXCEPT     //前置加加
     {  
_M_node = _M_node->_M_next;  
return *this;  
     }  
  
     _Self  
     operator++(int) _GLIBCXX_NOEXCEPT  //后置
     {  
_Self __tmp = *this;  //拷贝构造
_M_node = _M_node->_M_next;  
return __tmp;  
     }
```

![[Pasted image 20230717014132.png]]
![[Pasted image 20230717014230.png]]