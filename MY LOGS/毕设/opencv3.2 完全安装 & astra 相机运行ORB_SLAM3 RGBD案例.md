#### 修改pointcloudmapping.cc

打开src / pointcloudmapping.cc，110-112行修改如下，将rgb的颜色修改正确

```cpp
p.b = color.ptr<uchar>(m)[n*3+2];p.g = color.ptr<uchar>(m)[n*3+1];p.r = color.ptr<uchar>(m)[n*3];
```

在void PointCloudMapping::viewer() 中的while循环里的最后（200-201之间）加入下面一行，用于保存[点云](https://so.csdn.net/so/search?q=%E7%82%B9%E4%BA%91&spm=1001.2101.3001.7020)地图，同时在开头增加 #include <pcl/io/pcd_io.h>

```cpp
pcl::io::savePCDFileBinary( "vslam.pcd", *globalMap );
```

#### 修改camkelist.txt

打开CMakeLists.txt ，将48行左右的 “ find_package( PCL 1.12 REQUIRED ) ”中的1.12改为1.8，修改后如下： 

```scss
find_package( PCL 1.8 REQUIRED )
```

#### ROS下编译 

打开CMakeLists.txt，增加下面4行:

```cpp

```

ORB_SLAM 3 topic 对齐：
```C
message_filters::Subscriber<sensor_msgs::Image> rgb_sub(nh, "/camera/rgb/image_raw", 1);
message_filters::Subscriber<sensor_msgs::Image> depth_sub(nh, "/camera/depth_registered/image_raw", 1);
```


# 运行演示 ：

开启相机
```shell

cd ws_astra
sudo su
source devel/setup.bash
cd src/

roslaunch astra_carma astra.launch
lsusb
rqt_image_viewer
```


```shell
rosrun ORBSLAM3 RGBD Vocabulary/ORBvoc.txt Examlpe/ROS/ORB_SLAM3/astra.yaml
```