# <center>实验三     Kaggle  Plant Seedlings 分类比赛</center>
#### <center>小组成员：*1*. 岳思源    **120L021112**     *2*. 杨晋 **120L020409**</center>
## 1. 实验任务
1. 在 Kaggle Plant Seedlings Classification 数据集上基于 `PyTorch` 实现` VGG/ResNet/SENet `等结构
	- 自己实现 `VGG (11)`：要求 Conv 部分参照论文，可动态调整结构；
	- 自己实现 `ResNet (18)`：要求基于残差块，参照论文，可动态调整；
	- 在 `ResNet` 基础上，添加 `SE block`；
	
	对比其性能表现，要求使用 GPU 基于 *CUDA* 实现.
	
2.  进行性能调优
	- 公共部分（选用一个上述最优的模型）
		- 进行优化器 (SGD 与 Adam) 对比；
		- 进行 data augmentation（翻转、旋转、移位等操作）对比。
	- 自选部分
		- 引入新的模块/换用更好的模型等
		- 内容不限，可有效提升性能即可
	- 在Kaggle竞赛页面提交测试的结果，测得对应的Score。

---
## 2. 三种模型结构与实现
### 2.1 VGGNet:
一个经典卷积神经网络的基本组成部分是下面的这个序列：
1.  带填充以保持分辨率的卷积层；
2.  非线性激活函数，如ReLU；
3.  汇聚层，如最大汇聚层。

一个 VGG 块与之类似，在最初 VGG 论文中 ([Simonyan and Zisserman, 2014]( https://zh.d2l.ai/chapter_references/zreferences.html#id153 "Simonyan, K., & Zisserman, A. (2014). Very deep convolutional networks for large-scale image recognition. arXiv preprint arXiv: 1409.1556."))，作者使用了带有 $(3\times3)$ 卷积核、填充为 1（保持高度和宽度）的卷积层，和带有 $(2 \times 2)$ 汇聚窗口、步幅为 $2$（每个块后的分辨率减半）的最大汇聚层。
我们借助 pytorch 可以很轻松的定义出这样的一个 vgg 块（每个块有卷积层数和通道数的超参数）：
```python
def vggblock(num_convs, in_channels, out_channels):
    layers = []
    for _ in range(num_convs):
        layers.append(nn.Conv2d(in_channels, out_channels,
                                kernel_size=3, padding=1))
        layers.append(nn.ReLU())
        in_channels = out_channels
    layers.append(nn.MaxPool2d(kernel_size=2,stride=2))
    return nn.Sequential(*layers)
```
VGGNet 网络的核心思想就是抽象出这样的基本块，以块为设计单元，实现卷积层数足够深（在当时）的卷积神经网络。
![[Pasted image 20230517222350.png]]
超参数变量 `conv_arch` 指定了每个 VGG 块里卷积层个数和输出通道数。
原始 VGG 网络有 5 个卷积块，其中前两个块各有一个卷积层，后三个块各包含两个卷积层。第一个模块有 64 个输出通道，每个后续模块将输出通道数量翻倍，直到该数字达到 512。由于该网络使用 8 个卷积层和 3 个全连接层，因此它通常被称为 VGG-11。

### 2.2 ResNet
> 残差网络 `ResNet` 的思想并不局限于卷积神经网络．
> 通过给非线性的卷积层增加直连边（Shortcut Connection）（也称为残差连接（Residual Connection））的方式来提高信息的传播效率

假设在一个深度网络中，我们期望一个非线性单元（可以为一层或多层的卷积层）$𝑓(𝒙; 𝜃)$ 去逼近一个目标函数为 $f(𝒙)$ ．如果将目标函数拆分成两部分：恒等函数（Identity Function）$𝒙$ 和残差函数（Residue Function）$f(𝒙) − 𝒙$ ．
相比去逼近理想映射 $f(x)$，残差映射在现实中往往更容易优化。只需将 $f(x)-x$ 的加权运算（如仿射）的权重和偏置参数设成 0，那么$f (\mathbf{x})$即为恒等映射。实际中，当理想映射$f (\mathbf{x})$极接近于恒等映射时，残差映射也易于捕捉恒等映射的细微波动。
一个残差单元由多个级联的（等宽）卷积层和一个跨层的直连边组成，再经过 ReLU 激活后得到输出，形如：
![[Pasted image 20230517224312.png]]
残差网络就是将很多个残差单元串联起来构成的一个非常深的网络。
ResNet 沿用了 VGG 完整的 $3*3$ 卷积层设计。残差块里首先有 2 个有相同输出通道数的 $3*3$ 卷积层。每个卷积层后接一个批量规范化层和 ReLU 激活函数。然后通过跨层数据通路，跳过这 2 个卷积运算，将输入直接加在最后的 ReLU 激活函数前。这样的设计要求 2 个卷积层的输出与输入形状一样，从而使它们可以相加。通过 `pytorch` 残差块的实现如下：
```python
class Residual(nn.Module):
    def __init__(self, input_channels, num_channels,
                 use_1x1conv=False, strides=1):
        super().__init__()
        self.conv1 = nn.Conv2d(input_channels, num_channels,
                               kernel_size=3, padding=1, stride=strides)
        self.conv2 = nn.Conv2d(num_channels, num_channels,
                               kernel_size=3, padding=1)
        if use_1x1conv:
            self.conv3 = nn.Conv2d(input_channels, num_channels,
                                   kernel_size=1, stride=strides)
        else:
            self.conv3 = None
        self.bn1 = nn.BatchNorm2d(num_channels)
        self.bn2 = nn.BatchNorm2d(num_channels)

    def forward(self, X):
        Y = F.relu(self.bn1(self.conv1(X)))
        Y = self.bn2(self.conv2(Y))
        if self.conv3:
            X = self.conv3(X)
        Y += X
        return F.relu(Y)
```
ResNet 使用 4 个由残差块组成的模块，每个模块使用若干个同样输出通道数的残差块。第一个模块的通道数同输入通道数一致。由于之前已经使用了步幅为 2 的最大汇聚层，所以无须减小高和宽。之后的每个模块在第一个残差块里将上一个模块的通道数翻倍，并将高和宽减半。

### ResNet & SEblock
ResNet 中的 SE（Squeeze-and-Excitation）block 是一种用于增强卷积神经网络中特征提取的模块。它通过学习每个通道的重要性来重新分配特征的权重。SE block 分为两个步骤：squeeze 和 excitation。其中，squeeze 步骤将输入的特征图通过全局平均池化层进行降维，从而生成通道的描述信息。excitation 步骤则是使用两个全连接层来获取自适应权重，然后将其应用于特征图，以加强重要通道的响应。通过这样的方式，SE block 可以学习到不同通道之间的关联性，并以更加有效的方式生成特征表示，提高模型的性能。
```python
class SEBlock(nn.Module):  
    def __init__(self, channels, reduction=16):  
        super(SEBlock, self).__init__()  
        self.avg_pool = nn.AdaptiveAvgPool2d(1)  
        self.fc1 = nn.Linear(channels, channels // reduction)  
        self.relu = nn.ReLU(inplace=True)  
        self.fc2 = nn.Linear(channels // reduction, channels)  
        self.sigmoid = nn.Sigmoid()  
  
    def forward(self, x):  
        b, c, _, _ = x.size()  
        y = self.avg_pool(x).view(b, c)  
        y = self.fc1(y)  
        y = self.relu(y)  
        y = self.fc2(y)  
        y = self.sigmoid(y).view(b, c, 1, 1)  
        return x * y
```
先对输入的特征图执行全局平均池化，以便生成通道描述信息，然后使用两个全连接层来获取一个元素值为 0 到 1 之间的自适应权重，并使用非线性函数 ReLU 和 Sigmoid 对其进行激活处理。最后，将权重应用于特征图中的每个通道，并将其与输入特征图相乘，以使重要特征得到扩大。

---
## 3. 三种模型基础实现与性能对比
我们小组一名成员负责 `VGGNET`, 另一名成员负责 `ResNet` 和 `ResNet&SE block` 
1.  *VGGNET* (使用 *Adam*优化器 , ` lr=1e-4` , `epochs=20` ):

![[Pasted image 20230517192237.png]]
有一定的过拟合，最终的提交成绩为：**0.86901**
![[Pasted image 20230517231350.png]]

2. *ResNet*（使用*Adam*优化器，`lr=1e-4` , `epoch=40`）:

最终提交成绩为 ：**0.86523**
![[Pasted image 20230517231335.png]]

3. *ResNet & SEblock* (使用*Adam*优化器，`lr=1e-4` , `epoch=40`):

最终提交成绩为 ：**0.87405**
![[Pasted image 20230517231532.png]]

---
## 4. 性能调优
### 公共部分
对比**SGD** 优化器和**Adam**优化器，由于我们两人分别负责不同的模型类型，所以 `VGG` 和 `SeResNet` 都做了对比:
1. *VGG*

*VGGNET* (使用 *SGD*优化器 , `lr=1e-3` , `epochs=30` (但在划分出的验证集中 25 epoch 结束时时表现最好，所以最佳模型是第 25 epoch 结束时的模型) ):
![[Pasted image 20230517180945.png]]
最后在测试集上运行，提交的成绩为 **0.78211**
![[Pasted image 20230517181336.png]]
而 VGG 采用*Adam* 的成绩就是 3 中给出的，最终成绩为 **0.86901**，可以看到在 *Adam* 明显学习率更小，`epoch` 也更少的情况下，却能更快的收敛，效果要好于*SGD*

2. *SEResNet*

*SEResNet* 使用*SGD*优化器，`lr=0.01` ，`epoch=40` :
最后在测试集上运行，提交的成绩为 **0.86775**
![[Pasted image 20230517232246.png]]
而 *SEResNet* 采用*Adam* 的成绩就是 3 中给出的，最终成绩为 **0.87405**，可以看到在 *Adam* 明显学习率更小，`epoch` 也更少的情况下，却能更快的收敛，效果要好于*SGD*，两种模型结论一致。

### 自选部分
我们决定加入了学习率调度器，用于在训练神经网络时自动调整学习率，从而加快网络收敛速度、提高模型性能。
例如：
```python
opt = torch.optim.Adam(net.parameters(), lr=lr, weight_decay=weight_decay)
scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer=opt, mode='max', patience=3, factor=0.1,verbose=True,min_lr=lr * 1e-3)
```
在一个 epoch 结束后：
```python
if scheduler is not None:
            scheduler.step(valid_acc)
```
两种模型在加入*scheduler*前后对比:
1. VGGNet

加入前，最终成绩（`Adam , lr=1e-4, epoch=20`）为 **0.86901**
加入后，最终成绩（`Adam , lr=1e-4, epoch=20`）为 **0.90554**
![[Pasted image 20230517233002.png]]

2. SEResNet 

加入前，最终成绩 (`Adam` , `lr=1e-4` ，`epoch=40`) 为 **0.87405**
加入后，最终成绩（`Adam , lr=1e-4, epoch=40`）为 **0.89042**

戏剧性的是加入了 scheduler 的 *VGGNet* 最终反超了 *SEResNet*。

---
这是不同模型与不同调优对应的结果文件和最终分数

|    模型/优化    |  SGD       |    Adam      |  Adam+Scheduler    |
|:-----|:-----|:-----|:-----|
|  VGGNet    |   VGGNet_SGD. csv      *0.78211*   |   VGGNet_Adam. csv          *0.86901*   |  VGGNet_Adam_Scheduler. csv        **0.90554**    |
|  ResNet   |   -   |  ResNet_Adam           *0.86523*    |  -    |
|  SEResNet    | SEResNet_SGD. csv    *0.86775*     |  SEResNet_Adam. csv        *0.87405*    |  SEResNet_Adam_Scheduler. csv       **0.89042**   |

---

## 成员分工
岳思源 ： 1. *VGGNet* 模型代码与训练 2. 对*VGGNet* 模型后面的调优 3. 撰写*报告*
杨晋 ： 1. *ResNet* 和 *SEResNet* 模型代码与训练 2. 对 *SEResNet* 模型后面的调优 

---
### 参考文献
1. 《神经网络与深度学习》
2. 《动手学深度学习（PyTorch 版）》李沐，阿斯顿·张
3. He K, Zhang X, Ren S, et al., 2016. Deep residual learning for image recognition[C]//Proceedingsof the IEEE conference on computer vision and pattern recognition. 770-778.
4. Simonyan K, Zisserman A, 2014. Very deep convolutional networks for large-scale image recogni-tion[J]. arXiv preprint arXiv: 1409.1556.