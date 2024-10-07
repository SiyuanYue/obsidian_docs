# <center>实验四           循环神经网络</center>
#### <center>岳思源    **120L021112**</center>


# 1. 实验环境
`CUDA 12.1` ,  `pytorch-cuda=11.8` , `python 3.8`, `RTX2060`
# 2. 实验内容
>利用 Pytorch 自己实现 RNN、GRU、LSTM 和 Bi-LSTM
>不可直接调用 nn. RNN (), nn. GRU (), nn. LSTM ()。
>A. 利用上述四种结构进行文本多分类（60%）
>计算测试结果的准确率、召回率和 F1 值；
>对比分析四种结构的实验结果。
>B. 任选上述一种结构进行温度预测（40%）
>使用五天的温度值预测出未来两天的温度值；
>给出与真实值的平均误差和中位误差。

## 实现 RNN、GRU、LSTM 和 Bi-LSTM
### RNN
给定一个输入序列 $𝒙_1∶𝑇 = (𝒙_1, 𝒙_2, … , 𝒙_𝑡, … , 𝒙_𝑇)$，循环神经网络通过下面公式更新带反馈边的隐藏层的活性值 $𝒉_𝑡$ ：$𝒉_𝑡 = 𝑓(𝒉_𝑡−1, 𝒙_𝑡)$,
其中 $𝒉_0 = 0，𝑓(⋅)$ 为一个非线性函数，可以是一个前馈网络．循环神经网络的拟合能力也十分强大。
一个完全连接的循环网络是任何非线性动力系统的近似器。
![[Pasted image 20230524205657.png]]
一个 RNN 神经元如何在一个时间步里如何计算隐藏状态和输出：
```python
def rnn(inputs, state, params):
    # inputs和outputs皆为num_steps个形状为(batch_size, vocab_size)的矩阵
    W_xh, W_hh, b_h, W_hq, b_q = params
    H, = state
    outputs = []
    for X in inputs:
        H = nd.tanh(nd.dot(X, W_xh) + nd.dot(H, W_hh) + b_h)
        Y = nd.dot(H, W_hq) + b_q
        outputs.append(Y)
    return outputs, (H,)
```
由于 RNN 中可能出现梯度爆炸，导致我们一步走到解空间外，因此要通过裁剪梯度来避免这种状况。
```python
def grad_clipping(params, theta, ctx):
    norm = nd.array([0], ctx)
    for param in params:
        norm += (param.grad ** 2).sum()
    norm = norm.sqrt().asscalar()
    if norm > theta:
        for param in params:
            param.grad[:] *= theta / norm
```

### GRU
GRU 网络引入门控机制来控制信息更新的方式．和 LSTM 不同，GRU 不引入额外的记忆单元，GRU 网络引入一个更新门（Update Gate) 来控制当前状态需要从历史状态中保留多少信息（不经过非线性变换），以及需要从候选状态中接受多少新信息
即 $𝒉_𝑡 = 𝒛_𝑡 ⊙ 𝒉_𝑡−1 + (1 − 𝒛_𝑡) ⊙ 𝑔(𝒙_𝑡, 𝒉_𝑡−1;𝜃)$
GRU 网络直接使用一个门来控制输入和遗忘之间的平衡．当 $𝒛_𝑡$ = 0 时，当前状态 $𝒉_𝑡$ 和前一时刻的状态 $𝒉_𝑡−1$ 之间为非线性函数关系；当 $𝒛_𝑡$ = 1 时，$𝒉_𝑡$ 和 $𝒉_𝑡−1$ 之间为线性函数关系．
其中 $𝒉_𝑡$ 表示当前时刻的候选状态，$𝒓_𝑡$ ∈ \[0, 1\]𝐷 为重置门, 用来控制候选状态的计算是否依赖上一时刻的状态 $𝒉_{𝑡−1}$。
综上，GRU 网络的状态更新方式为
![[Pasted image 20230524212843.png]]
当 $𝒛_𝑡$ = 0, 𝒓 = 1 时，GRU 网络退化为简单循环网络；若 $𝒛_𝑡$ = 0, 𝒓 = 0 时，当前状态 $𝒉_𝑡$ 只和当前输入 $𝒙_𝑡$ 相关，和历史状态 $𝒉_{𝑡−1}$ 无关。
如图：
![[Pasted image 20230524213056.png]]
根据门控循环单元的计算表达式定义模型:
```python
def gru(inputs, state, params):
    W_xz, W_hz, b_z, W_xr, W_hr, b_r, W_xh, W_hh, b_h, W_hq, b_q = params
    H, = state
    outputs = []
    for X in inputs:
        Z = nd.sigmoid(nd.dot(X, W_xz) + nd.dot(H, W_hz) + b_z)
        R = nd.sigmoid(nd.dot(X, W_xr) + nd.dot(H, W_hr) + b_r)
        H_tilda = nd.tanh(nd.dot(X, W_xh) + nd.dot(R * H, W_hh) + b_h)
        H = Z * H + (1 - Z) * H_tilda
        Y = nd.dot(H, W_hq) + b_q
        outputs.append(Y)
    return outputs, (H,)
```

### LSTM
LSTM 中引入了 3 个门，即输入门（input gate）、遗忘门（forget gate）和输出门（output gate）和传统的记忆 cell。整个记忆机制更加复杂：
长短期记忆的门的输入均为当前时间步输入 $X_t$ 与上一时间步隐藏状态 $H_{t−1}$，输出由激活函数为 sigmoid 函数的全连接层计算得到。
（1） 遗忘门 𝒇𝑡 控制上一个时刻的内部状态 𝒄𝑡−1 需要遗忘多少信息．
（2） 输入门 𝒊𝑡 控制当前时刻的候选状态 ̃𝒄𝑡 有多少信息需要保存．
（3） 输出门 𝒐𝑡 控制当前时刻的内部状态 𝒄𝑡 有多少信息需要输出给外部状
态𝒉𝑡
这三个门的取值为（0，1）
$i_t = 𝜎(𝑾_i𝒙_𝑡 + 𝑼_i𝒉_𝑡−1 + 𝒃_i)$
$𝒇_𝑡 = 𝜎(𝑾_𝑓𝒙_𝑡 + 𝑼_𝑓𝒉_𝑡−1 + 𝒃_𝑓)$
$o_t = 𝜎(𝑾_o𝒙_𝑡 + 𝑼_o𝒉_𝑡−1 + 𝒃_o)$
如图，其计算过程为：1）首先利用上一时刻的外部状态 $𝒉_{t−1}$ 和当前时刻的输入 $𝒙_𝑡$ 算出三个门，以及候选状态 $𝒄_𝑡'$    2）结合遗忘门 $𝒇_𝑡$ 和输入门 $𝒊_𝑡$ 来更新记忆单元 $𝒄_𝑡$；3）结合输出门 $𝒐_𝑡$，将内部状态的信息传递给外部状态 $𝒉_t$
![[Pasted image 20230524214655.png]]
```python
def lstm(inputs, state, params):
    [W_xi, W_hi, b_i, W_xf, W_hf, b_f, W_xo, W_ho, b_o, W_xc, W_hc, b_c,
     W_hq, b_q] = params
    (H, C) = state
    outputs = []
    for X in inputs:
        I = torch.sigmoid((X @ W_xi) + (H @ W_hi) + b_i)
        F = torch.sigmoid((X @ W_xf) + (H @ W_hf) + b_f)
        O = torch.sigmoid((X @ W_xo) + (H @ W_ho) + b_o)
        C_tilda = torch.tanh((X @ W_xc) + (H @ W_hc) + b_c)
        C = F * C + I * C_tilda
        H = O * torch.tanh(C)
        Y = (H @ W_hq) + b_q
        outputs.append(Y)
    return torch.cat(outputs, dim=0), (H, C)
```

### Bi_LSTM
双向循环神经网络相比正向的 LSTM 添加了反向传递信息的隐藏层，以便更灵活地处理序列信息。
![[Pasted image 20230524215136.png]]
由于双向循环神经网络使用了过去的和未来的数据，所以我们不能盲目地将这一语言模型应用于任何预测任务。
```python
    def bi_lstm(self, inputs, state, params):
        W_xi, W_hi, b_i, W_xf, W_hf, b_f, W_xo, W_ho, b_o, W_xc, W_hc, b_c, W_xi_b, W_hi_b, b_i_b, W_xf_b, W_hf_b, b_f_b, W_xo_b, W_ho_b, b_o_b, W_xc_b, W_hc_b, b_c_b, W_hq, b_q = params
        (H, C), (H_b, C_b) = state
        outputs = []
        H_forward = []
        for X in inputs:
            I = torch.sigmoid((X @ W_xi) + (H @ W_hi) + b_i)
            F = torch.sigmoid((X @ W_xf) + (H @ W_hf) + b_f)
            O = torch.sigmoid((X @ W_xo) + (H @ W_ho) + b_o)
            C_curved = torch.tanh((X @ W_xc) + (H @ W_hc) + b_c) 
            C = F * C + I * C_curved  # 计算C
            H = O * torch.tanh(C)  # 计算H
            H_forward.append(H)
        inputs_reverse = torch.flip(inputs, dims=[0])
        H_backward = []
        for X in inputs_reverse:
            # 反向
            I_b = torch.sigmoid((X @ W_xi_b) + (H_b @ W_hi_b) + b_i_b)
            F_b = torch.sigmoid((X @ W_xf_b) + (H_b @ W_hf_b) + b_f_b)
            O_b = torch.sigmoid((X @ W_xo_b) + (H_b @ W_ho_b) + b_o_b)
            C_curved_b = torch.tanh((X @ W_xc_b) + (H_b @ W_hc_b) + b_c_b)  
            C_b = F_b * C_b + I_b * C_curved_b  # 计算C
            H_b = O_b * torch.tanh(C_b)  # 计算H
            H_backward.append(H_b)
        length = inputs.shape[0]
        for i in range(length):
            # 拼接H,H_b
            H = H_forward[i]
            H_b = H_backward[length - i - 1]
            H = torch.cat((H, H_b), dim=1)
            # 计算输出
            Y = H @ W_hq + b_q
            outputs.append(Y)
        # 最终按行拼接所有结果
        return outputs = torch.cat(outputs, dim=0)
```
# 3 实验结果
## 3.1 分别用四个模型对 online_shopping_10_cats 进行分类
#### RNN
`lr=1e-3 `          
`weight_decay=1e-4
`epochs=20`
![[Pasted image 20230523233157.png]]
![[Pasted image 20230524021801.png]]
最终在测试集上的 `precision` 是 **0.76**
## GRU
`lr=1e-3 `          
`weight_decay=1e-4
`epochs=20`
![[Pasted image 20230524000141.png]]
![[Pasted image 20230524021823.png]]
最终在测试集上的 `precision` 是 **0.80**
我们可以在使用同样的学习率和优化器算法情况下可以看出 GRU 相比普通 RNN 的收敛速度提升飞快，在第一个 epoch 就有了相当惊人的效果，10 个 epoch 结束后基本已经收敛了，之后其 loss 也无法得到实际减小，但 RNN 收敛慢很多，20 个 epoch 基本 loss 都在逐步减小，最终测试集效果 GRU 也能略胜一筹。
## LSTM
`lr=1e-3`
`weight_decay=1e-4`
`epochs=10`
![[Pasted image 20230524020705.png]]
![[Pasted image 20230524021837.png]]
最终在测试集上的 `precision` 是 **0.87**
LSTM 在同样使用 Adam ，学习率相同的情况下收敛也非常的快，并且最终在测试集上的效果也确实比 GRU 好一些。虽然 LSTM 模型无比复杂，但确实有不错的表现。
## BiLSTM
![[Pasted image 20230524020528.png]]
![[Pasted image 20230524021850.png]]
最终在测试集上的 `precision` 是 **0.87**
Bi_LSTM 的训练速度相比 LSTM 明显放慢，几乎是 LSTM 的两倍训练速度。虽然最终的训练 loss 要比 LSTM 低一丢丢，但其差距过小，而且在测试集上的表现与 LSTM 也基本相当，花了多一倍的时间，但并没有啥实际的效益。
## 3.2 选取一个模型进行温度预测
数据集为 `jena_climate_2009_2016`
给定前五天的数据，预测后两天的数据。
我选择的模型是**LSTM**。
训练过程。
![[Pasted image 20230524152515.png]]
测试集上的测试结果
![[Pasted image 20230524152713.png]]
mean_error = 3.7664
中位误差=3.1463。


