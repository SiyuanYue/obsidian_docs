![[Pasted image 20230721005132.png]]

---
在 C++11 的 STL 中，迭代器有五种不同的 `difference_type`：

1. Input Iterator（输入迭代器）：通常用于一次性遍历容器中的元素，并且只能向前移动。它们之间的距离类型（difference_type）是未定义的。
    
2. Output Iterator（输出迭代器）：用于写入容器元素，并且只能向前移动。它们之间的距离类型（difference_type）也是未定义的。
    
3. Forward Iterator（前向迭代器）：与输入和输出迭代器类似，可以读取和写入容器元素，但可以多次遍历容器。它们之间的距离类型可以是整数类型。
    
4. Bidirectional Iterator（双向迭代器）：除了具有前向迭代器的功能外，还可以向后移动，即反向遍历容器。它们之间的距离类型可以是整数类型。
    
5. Random Access Iterator（随机访问迭代器）：具有双向迭代器的功能，并且支持随机访问容器中的元素。可以使用算术操作符（如+、-）来计算迭代器之间的距离。它们之间的距离类型通常是一个整数类型。
    

这些迭代器类型是通过 C++中的 `iterator_traits` 模板类来定义的，可以根据每种迭代器的特性进行分类和特化。

---

对于 STL 中的迭代器，在 C++11 中也有一个 `value_type` 的类型定义。value_type 表示迭代器所指向的元素类型。不同类型的迭代器有不同的 `value_type`。

在迭代器模板类 `iterator_traits` 中，有一个嵌套类型 `value_type`，用于获取迭代器指向的元素类型。可以通过 `typename iterator_traits<\Iterator>:: value_type` 来获取。

例如，对于 `vector<int>`容器的迭代器，其 `value_type` 是 int。对于 list<\string>:: iterator，其 `value_type` 是 string。

`value_type` 可以方便地获取迭代器指向的元素类型，从而进行相关的操作和处理。

---
![[Pasted image 20230721010403.png]]
![[Pasted image 20230721011053.png]]
![[Pasted image 20230721011124.png]]

加一层中间层
![[Pasted image 20230721012000.png]]
利用**偏特化**来实现对类类型和原始指针类型两种iterator的封装：
![[Pasted image 20230721011725.png]]
完整的五个 TYPE：
![[Pasted image 20230721012154.png]]

标准库中其他的 traits:
- `type traits`
- `iterator traits`
- `char traits`
- `allocator traits`
- `pointer traits`
- `array traits`

