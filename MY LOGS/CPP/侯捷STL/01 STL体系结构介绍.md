# 01 STL 体系结构介绍
## 网页
- cppreference. com
- `gcc.gnu.org`
- 
## 六大部件
- 容器
- 适配器
- 算法
- 迭代器
- 适配器
- 仿函数
![[Pasted image 20230630183806.png]]
## “前闭后开”区间
`[ )`
![[Pasted image 20230630182536.png]]

but *C++11*:
```C++
for (int i:{1,2,3,4,5,6,7,8,9})
{
	std::cout<<i<<std::endl;
}

std::vector<double> vec;
for(auto elem:vec){
	std::cout<<elem<<std::endl;
}
for(auto& elem:vec){
	elem *=3;
}

```
## 适度使用 auto

