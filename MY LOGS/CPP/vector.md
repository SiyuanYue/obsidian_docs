
# data () 获得首地址指针，可用于与 C 库交互
![[Pasted image 20230802185344.png]]

# RAII 安全
![[Pasted image 20230802185443.png]]
# 用 `move` 来延长生命周期
![[Pasted image 20230802185139.png]]

![[Pasted image 20230802185308.png]]

# 重新分配可能会导致野指针
![[Pasted image 20230802185708.png]]
`push_back` 也会导致原本的 data () 返回的变成野指针
*注意 capacity 与 size 分离哦! ! !*
![[Pasted image 20230910022015.png]]
![[Pasted image 20230910022038.png]]
![[Pasted image 20230910022122.png]]