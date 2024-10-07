
# 环境

```
相机： Astra_s
ROS melodic
Ubuntu 18.04
开发板： nvidia jetson nano
```



###  初始化rosdep（ROS 装好了其实不需要这步，可以无视）
```shell
sudo rosdep init
```
Bug1 - 会出现错误：这个错误是因为网络无法连接，无法下载20-default.list文件
```shell
ERROR: cannot download default sources list from:
https://raw.githubusercontent.com/ros/rosdistro/master/rosdep/sources.list.d/20-default.list
Website may be down.
```
Solution1 - 我们参考[清华源处理方法](https://mirror.tuna.tsinghua.edu.cn/help/rosdistro/)，也有其他更改下载链接方法，请自行百度。
```shell
# 手动模拟 rosdep init
sudo mkdir -p /etc/ros/rosdep/sources.list.d/
sudo curl -o /etc/ros/rosdep/sources.list.d/20-default.list https://mirrors.tuna.tsinghua.edu.cn/github-raw/ros/rosdistro/master/rosdep/sources.list.d/20-default.list
# 为 rosdep update 换源
export ROSDISTRO_INDEX_URL=https://mirrors.tuna.tsinghua.edu.cn/rosdistro/index-v4.yaml

rosdep update
# 每次 rosdep update 之前，均需要增加该环境变量
# 为了持久化该设定，可以将其写入 .bashrc 中，例如
echo 'export ROSDISTRO_INDEX_URL=https://mirrors.tuna.tsinghua.edu.cn/rosdistro/index-v4.yaml' >> ~/.bashrc
```

```shell
#更新
rosdep update
```
出现以下输出：
```shell
reading in sources list data from /etc/ros/rosdep/sources.list.d
Hit https://mirrors.tuna.tsinghua.edu.cn/github-raw/ros/rosdistro/master/rosdep/osx-homebrew.yaml
Hit https://mirrors.tuna.tsinghua.edu.cn/github-raw/ros/rosdistro/master/rosdep/base.yaml
Hit https://mirrors.tuna.tsinghua.edu.cn/github-raw/ros/rosdistro/master/rosdep/python.yaml
Hit https://mirrors.tuna.tsinghua.edu.cn/github-raw/ros/rosdistro/master/rosdep/ruby.yaml
Query rosdistro index https://mirrors.tuna.tsinghua.edu.cn/rosdistro/index-v4.yaml
Skip end-of-life distro "ardent"
Skip end-of-life distro "bouncy"
Skip end-of-life distro "crystal"
Skip end-of-life distro "dashing"
Skip end-of-life distro "eloquent"
Skip end-of-life distro "foxy"
Skip end-of-life distro "galactic"
Skip end-of-life distro "groovy"
Add distro "humble"
Skip end-of-life distro "hydro"
Skip end-of-life distro "indigo"
Add distro "iron"
Skip end-of-life distro "jade"
Skip end-of-life distro "kinetic"
Skip end-of-life distro "lunar"
Skip end-of-life distro "melodic"
Add distro "noetic"
Add distro "rolling"
updated cache in /home/msj/.ros/rosdep/sources.cache
```

# 安装Astra 相机驱动 
部分问题可以参考博客：

 [ROS melodic+Astra s编译运行ros_astra_camera实录（踩坑没填完](https://blog.csdn.net/qq_50220094/article/details/126186616)

 [ ROS_ Melodic + Astra S(如何在该环境下打开摄像机获取rgb/深度图/点云)](https://blog.csdn.net/cau_weiyuhu/article/details/128533386)

初始化ROS 工作空间并下载`astra`驱动源码
```shell

#初始化ROS 工作空间    在之前创建好的工作空间进行可以忽略这步
mkdir -p ~/ws_astra/src
cd ~/ws_astra/src
catkin_init_workspace 
cd ~/ws_astra
catkin_make
source devel/setup.bash 


# 下载astra驱动
cd src
git clone git@github.com:orbbec/ros_astra_camera.git 
```


> **我从官网github 下载的驱动最终编译会有boost相关链接报错，网上查找问题相关的方法都无法解决，使用老师提供的驱动压缩包则没有问题**
> 如遇到相关报错，可以进行以下尝试看看行不行：
> `find_package(Boost REQUIRED COMPONENTS filesystem program_options)`
> `target_link_libraries(${PROJECT_NAME}  ...   ${Boost_LIBRARIES}  -lboost_serialization`


## 下载依赖
```shell
sudo apt-get install ros-melodic-uvc-camera
sudo apt-get install ros-melodic-image-*
sudo apt-get install ros-melodic-rqt-image-view
```

## 编译
```shell
cd ..
catkin_make
```

成功：
![[astra_s相机&ROS melodic.png]]

---

### 部分可能遇到的编译报错解决
1. `/usr/bin/ld: cannot find -luvc`

![[astra_s相机&ROS melodic-1.png]]

解决：

```shell
sudo apt-get install libuvc-dev
```

2.  `/usr/include/opencv` not found

![[astra_s相机&ROS melodic-2.png]]

解决：
我安装了 `opencv4` 在 `/usr/include/opencv4`
建立一个软链接使`cv_bridge` 可以找到相关库：
`sudo ln -s /usr/include/opencv4 /usr/include/opencv`

3.  系统自带的 `opencv3.2` 有相关库找不到？


![[astra_s相机&ROS melodic-3.png]]

再装一下：

`sudo apt install libopencv3.2`

4.  ROS中catkin_make的OpenCV冲突的解决（cv_bridge）

我没遇到，但遇到可以参照：[ROS中catkin\_make的OpenCV冲突的解决（踩坑小记，报错分析）\_/usr/bin/ld: warning: libopencv\_imgcodecs.so.3.2, -CSDN博客](https://blog.csdn.net/m0_46611008/article/details/124321527)

---

# 建立Astra udev规则

```shell
roscd astra_camera 
./scripts/create_udev_rules
```
![[astra_s相机&ROS melodic-4.png]]

再次编译工作空间

```shell
cd ../..
catkin_make
```

# 运行 `launch`

相机是 `Astra s` 型号，运行 `./launch/astra.launch`, 如果型号是 `Astra Stereo S (w/ UVC)` 就运行 `stereo_s.launch`。

```shell
roslaunch astra_camera astra.launch
```

![[astra_s相机&ROS melodic-5.png]]

查看话题

```shell
rostopic list
```

![[astra_s相机&ROS melodic-6.png]]

# 查看相机图像
##  `rqt_image_view`查看
```shell
rqt_image_view
```

选择 `/camera/depth/image` 可以查看深度图，`/rgb/image_raw` 可以查看rgb 照片

![[astra_s相机&ROS melodic-7.png]]

##  `rviz` 查看图像
```shell
rviz
```

左下角add-iamge 后, 然后可以选择**topic** 选择上文提到的需要查看的话题
![[astra_s相机&ROS melodic-9.png]]
查看深度图：
![[astra_s相机驱动安装与ROS查看图像.png]]

add-cloudpoint2, 查看点云：
![[astra_s相机驱动安装与ROS查看图像-1.png]]
注意选好这两项，就可以查看到点云：
![[astra_s相机驱动安装与ROS查看图像-2.png]]