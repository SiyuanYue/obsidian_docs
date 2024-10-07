
# 两个线程睡眠与唤醒
# pattern 存放在全局静态区合适吗？

# 稀疏重建
[由上述代码分析可知,](https://www.yuque.com/chenhai-7zi1m/se4n14/tr6dg3#7e5c4bf5) 每次完成ORB特征点提取之后,图像金字塔信息就作废了,下一帧图像到来时调用ComputePyramid () 函数会覆盖掉本帧图像的图像金字塔信息; 但从金字塔中提取的图像特征点的信息会被保存在Frame对象中. 所以ORB-SLAM2是稀疏重建,对每帧图像只保留最多nfeatures个特征点 (及其对应的地图点).

#  `nObs` 应该是protected 的
![[ORB修改？.png]]


#  SLAM 3 的双目处理跟 2 对比?？


# ORB 中很多 `update` 实际上是原来清空重建新的，改成渐进式更新是否更好更快？（局部地图跟踪？）


