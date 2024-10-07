![[Pasted image 20230722012026.png]]

两倍扩充
通过三个指针控制整个容器
```C++
pointer _M_start;  
pointer _M_finish;  
pointer _M_end_of_storage;
```

```C++
 void  
     push_back(const value_type& __x)  
     {  
if (this->_M_impl._M_finish != this->_M_impl._M_end_of_storage)  
  {  
    _GLIBCXX_ASAN_ANNOTATE_GROW(1);  
    _Alloc_traits::construct(this->_M_impl, this->_M_impl._M_finish,  
              __x);  
    ++this->_M_impl._M_finish;  
    _GLIBCXX_ASAN_ANNOTATE_GREW(1);  
  }  
else  
  _M_realloc_insert(end(), __x);  
     }



```

![[Pasted image 20230722013629.png]]

![[Pasted image 20230722013728.png]]

G4.9:
![[Pasted image 20230724001008.png]]
`3*sizeof (pointer_size)`
![[Pasted image 20230727010358.png]]
![[Pasted image 20230727010407.png]]