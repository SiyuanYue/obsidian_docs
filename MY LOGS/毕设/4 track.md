##  词袋匹配
聚类先分成几个类别，再去匹配特征点的描述子，不在一类的必然匹配不上，减少运算量


# Tracking流程中的关键问题 (暗线)  

## 地图点的创建与删除  
1.  Tracking线程中初始化过程 (`Tracking:: MonocularInitialization () `和`Tracking:: StereoInitialization ()`) 会创建新的地图点.  
2. Tracking线程中创建新的关键帧 (`Tracking:: CreateNewKeyFrame ()`) 双目会创建新的地图点，单目不创建.  
3. Tracking线程中根据恒速运动模型估计初始位姿 (`Tracking:: TrackWithMotionModel ()`) 也会产生临时地图点, 但这些临时地图点在跟踪成功后会被马上删除.  

所有的非临时地图点都是由关键帧建立的,`Tracking::TrackWithMotionModel()`中由非关键帧建立的关键点被设为临时关键点,很快会被删掉,仅作增强帧间匹配用,不会对建图产生任何影响.这也不违反**只有关键帧才能参与LocalMapping和LoppClosing线程**的原则.  

* 思考: 为什么跟踪失败的话不删除这些局部地图点  

跟踪失败的话不会产生关键帧, 这些地图点也不会被注册进地图, 不会对之后的建图产生影响.  

* 思考: 那会不会发生内存泄漏呢?  

不会的, 因为最后总会有一帧跟踪上, 这些临时地图点都被保存在了成员变量 `mlpTemporalPoints` 中, 跟踪成功后会删除所有之前的临时地图点.

## 关键帧与地图点间发生关系的时机  
●新创建出来的非临时地图点都会与创建它的关键帧建立双向连接.  
●通过`ORBmatcher::SearchByXXX()`函数匹配得到的*帧点关系*只建立单向连接:  
○只在关键帧中添加了对地图点的观测(将地图点加入到关键帧对象的成员变量`mvpMapPoints`中了).  
○没有在地图点中添加对关键帧的观测(地图点的成员变量`mObservations`中没有该关键帧).  
这为后文中LocalMapping线程中函数 `LocalMapping::ProcessNewKeyFrame()` 对关键帧中地图点的处理埋下了伏笔. 该函数通过检查地图点中是否有对关键点的观测来判断该地图点是否是新生成的.
```CPP
void LocalMapping::ProcessNewKeyFrame() {
// 遍历关键帧中的地图点
const vector<MapPoint *> vpMapPointMatches = mpCurrentKeyFrame->GetMapPointMatches();
for (MapPoint *pMP : vpMapPointMatches) {
	if (!pMP->IsInKeyFrame(mpCurrentKeyFrame)) {
		// step3.1. 该地图点是跟踪本关键帧时匹配得到的,在地图点中加入对当前关键帧的观测
		pMP->AddObservation(mpCurrentKeyFrame, i);
		pMP->UpdateNormalAndDepth();
		pMP->ComputeDistinctiveDescriptors();
	} else
		{
		// step3.2. 该地图点是跟踪本关键帧时新生成的,将其加入容器mlpRecentAddedMapPoints待筛选
		mlpRecentAddedMapPoints.push_back(pMP);
		}
}
// ...
}
```

##  参考关键帧 : `mpReferenceKF`
* 参考关键帧的用途:  

a.  Tracking线程中函数`Tracking:: TrackReferenceKeyFrame()` 根据参考关键帧估计初始位姿.  
b.  用于初始化新创建的MapPoint的成员变量参考帧 `mpRefKF`, 函数 `MapPoint:: UpdateNormalAndDepth()` 中根据参考关键帧 `mpRefKF` 更新地图点的平均观测距离.  
* 参考关键帧的指定:  

a. Traking线程中函数`Tracking:: CreateNewKeyFrame()` 创建完新关键帧后, 会将新创建的关键帧设为参考关键帧.  
b. Tracking线程中函数 `Tracking:: TrackLocalMap()` 跟踪局部地图过程中调用函数`Tracking:: UpdateLocalMap()`, 其中调用函数`Tracking:: UpdateLocalKeyFrames()`, 将与当前帧共视程度最高的关键帧设为参考关键帧.
