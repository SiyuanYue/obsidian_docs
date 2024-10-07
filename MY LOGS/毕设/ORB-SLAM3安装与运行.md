
记录编译安装 `ORB_SLAM3` ,并运行EuRoC 数据集的ROS bag

首先，默认 `g++`, `cmake`，`make`, `ROS` 等等最基本工具已经安装。

**ROS 安装**可以参考 [blog](https://blog.csdn.net/KIK9973/article/details/118755045?ops_request_misc=%257B%2522request%255Fid%2522%253A%2522164722886416780261979841%2522%252C%2522scm%2522%253A%252220140713.130102334.pc%255Fall.%2522%257D&request_id=164722886416780261979841&biz_id=0&utm_medium=distribute.pc_search_result.none-task-blog-2~all~first_rank_ecpm_v1~times_rank-4-118755045.first_rank_v2_pc_rank_v29_v2&utm_term=ros%E5%AE%89%E8%A3%85%2018&spm=1018.2226.3001.4187) 或其他教程

# 依赖库安装
## Eigen 3.3.4
下载 `Eigen3.3.4` 并进行编译与安装 （目前编译ORB_SLAM3 时 `Eigen` 这个版本 (>3.3.0) 没遇到问题，版本过高或过低可能会遇到一些问题，需要修改CMakeList 等等，编译ORB_SLAM2 需要Eigen 3.2）

注意尽量不要用 `apt` 来装eigen，很可能找不到或版本不兼容，可以 `sudo apt remove libeigen3-dev` 将之前这样装的eigen 卸载。

下载所需版本的源码 ：[发布 · libeigen / eigen · GitLab](https://gitlab.com/libeigen/eigen/-/releases)
```shell
tar -xzvf eigen-3.3.4.tar.gz
//如果下载的是.zip:
unzip eigen-3.3.4.zip

cd eigen-3.3.4
mkdir build && cd build
cmake ..
sudo make install
```
查看自己下载的Eigen 版本方法：

`cat /usr/include/eigen3/Eigen/src/Core/util/Macros.h | grep VERSION` 或

`cat /usr/local/include/eigen3/Eigen/src/Core/util/Macros.h | grep VERSION`  

## Pangolin 0.6
[Pangolin 0.6](https://github.com/stevenlovegrove/Pangolin/releases) 下载源码

按照首页readme安装[GitHub - stevenlovegrove/Pangolin at v0.6](https://github.com/stevenlovegrove/Pangolin/tree/v0.6)
```shell
sudo apt install libgl1-mesa-dev
sudo apt install libglew-dev
sudo apt install libpython2.7-dev
sudo apt install pkg-config
sudo apt install libegl1-mesa-dev libwayland-dev libxkbcommon-dev wayland-protocols


unzip Pangolin-0.6.zip
cd Pangolin
mkdir build
cd build
cmake ..
make -j3
sudo make install
```
测试：
```shell
cd Pangolin-0.6/examples/HelloPangolin 
mkdir build 
cd build
cmake .. 
make 
./HelloPangolin
```
成功运行一个红绿蓝立方体
## Boost 库安装
[boost 1.80.0](https://boostorg.jfrog.io/artifactory/main/release/1.80.0/source/) 下载源码

解压到合适位置
```shell
cd boost-1.80.0
sudo ./bootstrap.sh   //这一步较占内存可能卡死
```
`bootstrap.sh` 会生成 `b2` 工具，继续执行
```shell
sudo ./b2 install
```
![[ORB-SLAM3安装与运行-4.png]]

之后 `/usr/local/include` 下会有boost的头文件，`/usr/local/lib` 下面会生成boost库

# 下载编译ORB-SLAM 3 源码
[ORB-SLAM3](https://github.com/UZ-SLAMLab/ORB_SLAM3)

`git clone https://github.com/UZ-SLAMLab/ORB_SLAM3.git`
```shell
cd ORB_SLAM3
cat build.sh
```
一步一步在命令行手动执行 `build. sh` 中的命令，这样可以方便解决报错
```shell
echo "Configuring and building Thirdparty/DBoW2 ..."

cd Thirdparty/DBoW2
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j

cd ../../g2o

echo "Configuring and building Thirdparty/g2o ..."

mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j

cd ../../Sophus

echo "Configuring and building Thirdparty/Sophus ..."

mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j

cd ../../../

echo "Uncompress vocabulary ..."

cd Vocabulary
tar -xf ORBvoc.txt.tar.gz
cd ..

echo "Configuring and building ORB_SLAM3 ..."

mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j

```
先编译安装 `Thirdparty` 目录下的 `DBoW2`，`g2o`，`Sophus`，再解压 `Vocabulary` 下词典，最后编译 `ORB-SLAM`，在 `lib/` 下生成 `libORB_SLAM3.so`，并编译好 `Example/` 下的执行程序。

我当时只编译安装 `Thirdparty` 目录下的 `DBoW2`，`g2o`，`Sophus`，再解压 `Vocabulary` 下词典，因为要通过**ROS**运行，没有进行最后一步编译 `ORB-SLAM`，在 `lib/` 下生成 `libORB_SLAM3.so`。（后面又回来执行了最后一步）

同样一步步执行 `build_ros.sh` 的内容：
```shell
cd Examples/ROS/ORB_SLAM3
mkdir build
cd build
cmake .. -DROS_BUILD_TYPE=Release
make -j

```
但最新的官方源码里的 `Examples` 下没有ROS 目录，可能是误删了，从 `Examples_old/` 下复制或者从这个详细注释版本 [ORB_SLAM3_detailed_comments](https://github.com/electech6/ORB_SLAM3_detailed_comments) 里相同目录下复制过去即可。

编译时会报错：
![[ORB-SLAM3安装与运行.png]]

没有添加该目录为 `ROS_PACKAGE_PATH`

修改 `~/.bashrc` ，最后加一句：`export ROS_PACKAGE_PATH=${ROS_PACKAGE_PATH}:/home/hitrobot822/Desktop/ORB_SLAM3/Examples/ROS`

重新运行 `cmake .. -DROS_BUILD_TYPE=Release`

报错：
![[ORB-SLAM3安装与运行-1.png]]

是 `opencv` 出现问题
##  `opencv` 安装
我根据这个博客： [ORBSLAM3 安装及测试教程（Ubuntu20.04） - 滑稽果 - 博客园](https://www.cnblogs.com/xiaoaug/p/17766112.html)安装了opencv 4.4.0。

[opencv](https://opencv.org/releases/) 下载 4.4.0 源码    （其实最好是安装 3.4.0 版本的，但我因为先安装了 4.4.0，3.4.0 出现问题装不上，可以参照 [ubuntu18.04系统,opencv3.4.9+contrib完全安装指南](https://zhuanlan.zhihu.com/p/142254644) 博客尝试安装 3.4 版本的 `opencv`）

[opencv_contrib](https://github.com/opencv/opencv_contrib/tree/4.4.0) 下载与**opencv 版本一致**的扩展库

目录结构为
```
opencv
| - opencv-4.4.0      // 4.4.0 源码
| - opencv_contrib-4.4.0  //与opencv 版本一致的扩展库
```

[https://wwtt.lanzouw.com/if60o1cwvv4h](https://wwtt.lanzouw.com/if60o1cwvv4h) 密码: d5fx 下载 `boostdesc_bgm` 与 `vgg_generated`，将这里面的十几个文件放到 `opencv_contrib-4.4.0/modules/xfeatures2d/src` 目录中

修改 `opencv_contrib-4.4.0/modules/xfeatures2d/test/test_features2d.cpp`

第 51~52 行代码路径改为
```CPP
#include "../../../../opencv-4.4.0/modules/features2d/test/test_detectors_regression.impl.hpp" 		    #include "../../../../opencv-4.4.0/modules/features2d/test/test_descriptors_regression.impl.hpp"
```

修改 `opencv_contrib-4.4.0/modules/xfeatures2d/test/test_rotation_and_scale_invariance.cpp` 文件，将里面的第 7~8 行代码路径改为：
```CPp
#include "../../../../opencv-4.4.0/modules/features2d/test/test_detectors_invariance.impl.hpp" // main OpenCV repo
#include "../../../../opencv-4.4.0/modules/features2d/test/test_descriptors_invariance.impl.hpp" // main OpenCV repo
```

然后编译安装
```shell
cd opencv 
mkdir -p build && cd build 
cmake -DOPENCV_EXTRA_MODULES_PATH= ../opencv_contrib-4.4.0/modules   ../opencv-4.4.0
make -j4    #这步就要开四个，编译很慢
sudo make install # 别忘了
```

`opencv` 在 `make` 过程中报错：
![[ORB-SLAM3安装与运行-2.png]]

依照 [blog](https://blog.csdn.net/weixin_40649372/article/details/124979958) 解决

将 `opencv_contrib-4.4.0\modules\xfeatures2d \include\opencv2` 此目录下所有文件复制到opencv的安装位置 `opencv\build\include\opencv2` 中，这样 `#include<opencv2/xfeatures2.hpp>` 不会报错

继续 `make -j4` 成功编译
![[ORB-SLAM3安装与运行-3.png]]

---

## 继续编译ORB-SLAM 3

重新编译 `Examples/ROS/ORB_SLAM3/`，  根据 `build_ros.sh` 的内容：
```shell
cd Examples/ROS/ORB_SLAM3
mkdir build
cd build
cmake .. -DROS_BUILD_TYPE=Release
make -j
```

然而 `cmake .. -DROS_BUILD_TYPE=Release` 依旧会报一样的错

应该是opencv 4.0 太新了，但上面又说大于 3.2 即可，有点凌乱，又有博客说 4.4 没问题。

最后直接用一种粗暴方式解决了：

直接修改 `CMakeList.txt`, 将
```Cmake
find_package(OpenCV 3.0 QUIET)
if(NOT OpenCV_FOUND)
   find_package(OpenCV 2.4.3 QUIET)
   if(NOT OpenCV_FOUND)
      message(FATAL_ERROR "OpenCV > 2.4.3 not found.")
   endif()
endif()
```

第一行修改为 `find_package(OpenCV 4.4)`

重新 `make`

提示缺少 `libORB_SLAM3.so`


---

回去在 `ORB_SLAM3/build` 下 

`cmake .. -DCMAKE_BUILD_TYPE=Release`

`make -j`  （很慢，极容易卡死）

成功编译
![[ORB-SLAM3安装与运行-5.png]]

接着 `Examples/ROS/ORB_SLAM3/build` 下执行编译完，也通过了！
# 运行EuRoC双目数据集
从 [kmavvisualinertialdatasets – ASL Datasets](https://projects.asl.ethz.ch/datasets/doku.php?id=kmavvisualinertialdatasets#downloads) 下载Euroc 双目数据集
![[ORB-SLAM3安装与运行-6.png]]

我选择了MH 03 的ROS bag，但官网下的很卡而且ubuntu 上可能下不了，最好搜索搜索在百度网盘 [SLAM数据集（百度网盘）\_ntu rgb d 120深度 数据集下载百度网盘-CSDN博客](https://rupingcen.blog.csdn.net/article/details/103340020) 上下到自己电脑上，然后u 盘拷到板子上。

打开一个终端运行 `roscore`

另开一个运行 `rosrun ORB_SLAM3 Stereo_Inertial Vocabulary/ORBvoc.txt Examples/Stereo-Inertial/EuRoC.yaml false`
(为什么这里是false ，参见 [https://github.com/UZ-SLAMLab/ORB_SLAM3/issues/237](https://github.com/UZ-SLAMLab/ORB_SLAM3/issues/237)，不显式打出默认就是false，显式用true 会运行失败)

再开一个运行bag：`rosbag play dataset/MH_03_medium.bag /cam0/image_raw:=/camera/left/image_raw /cam1/image_raw:=/camera/right/image_raw /imu0:=/imu`

成功运行：
![[ORB-SLAM3安装与运行-7.png]]

---

# 一些可能遇到的问题
### 在虚拟机编译ORB_SLAM 2可能遇到的问题
1.  Pangolin could not be found because dependency Eigen 3 could not be found
![[ORB-SLAM3安装与运行-8.png|444]]

解决：[Pangolin could not be found because dependency Eigen3 could not be found · Issue #1015 · raulmur/ORB\_SLAM2 · GitHub](https://github.com/raulmur/ORB_SLAM2/issues/1015)

   2. 编译ORB_SLAM2报错  'usleep' was not declared in this scope：
 
 ```shell
 /home/sankuai/Projects/ORB_SLAM2/src/System.cc: In member function ‘cv::Mat ORB_SLAM2::System::TrackStereo(const cv::Mat&, const cv::Mat&, const double&)’:  
/home/sankuai/Projects/ORB_SLAM2/src/System.cc:134:28: error: ‘usleep’ was not declared in this scope  
usleep(1000);  
^  
/home/sankuai/Projects/ORB_SLAM2/src/System.cc: In member function ‘cv::Mat ORB_SLAM2::System::TrackRGBD(const cv::Mat&, const cv::Mat&, const double&)’:  
/home/sankuai/Projects/ORB_SLAM2/src/System.cc:185:28: error: ‘usleep’ was not declared in this scope  
usleep(1000);
 ```
 参见：[ORB_SLAM2/issues/317](https://github.com/raulmur/ORB_SLAM2/issues/317)
 
 [Fixed compilation error on usleep by mpdmanash · Pull Request #144 · raulmur/ORB\_SLAM2 · GitHub](https://github.com/raulmur/ORB_SLAM2/pull/144)
 
 可以尝试：
 >　Instead of adding `#include <unistd.h>` to every .cc files, you can put it in `System.h` instead. All other files include `System.h` in a nested manner.


3. 编译 ORB_SLAM2出现如下错误　`static assertion failed: std::map must have the same value_type as its allocator static_assert(is_same<typename _Alloc::value_type, value_type>::value`　
![[ORB-SLAM3安装与运行-9.png]]

参见 [ORB-SLAM2编译错误\_89: recipe for target 'frontend/cmakefiles/fronten-CSDN博客](https://blog.csdn.net/lixujie666/article/details/90023059)
### 在虚拟机编译 ORB_SLAM 3 可能遇到的问题
编译ORB_SLAM3/ThirdParty 中自带的 Sophus 出错
![[构建-2.png]]

通过 locate 查询到电脑装了两个 Eigen 库，查看 Eigen 版本：

一个位于 `/usr/local/include/eigen3/Eigen` 为 3.2.0，另一个位于 `/usr/include/eigen3/Eigen` 为 3.3.7。它默认寻找了Eigen 3.2.0 那个，与Sophus 所需版本不匹配。

解决方式：
```
EIGEN3_INCLUDE_DIR - Directory where signature_of_eigen3_matrix_library can be found  
EIGEN3_INCLUDE_DIRS - List of directories of Eigen and it's dependencies  
EIGEN3_ROOT_DIR - The base directory of Eigen
```
设置 `Eigen3_ROOT` 指向Eigen 3.3.7 对应的目录，使cmake 查找到合适eigen 库版本
![[ORB-SLAM3安装与运行-10.png]]

添加 `set(Eigen3_ROOT "/usr/include/eigen3")`，同时将此行添加到顶层 ` CMakeLists. txt ` 文件的开头：

```cmake
cmake_policy(SET CMP0074 NEW)
```


注意：

**ORB_SLAM 2 编译需要Eigen 3.2/3.1 版本，ORB_SLAM 3 编译需要Eigen 3.3 版本**


