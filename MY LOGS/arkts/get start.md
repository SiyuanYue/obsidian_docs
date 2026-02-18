## 1. 拉代码
```sh
mkdir arkcompiler; cd arkcompiler
仓库：
git clone https://gitee.com/openharmony/arkcompiler_runtime_core.git runtime_core

git clone https://gitee.com/openharmony/arkcompiler_ets_frontend.git ets_frontend 

# 目前2.0最新代码不在master分支，将两个仓全部切换到OpenHarmony_feature_20241108分支
cd runtime_core
git checkout -b OpenHarmony_feature_20250328 origin/OpenHarmony_feature_20250328
cd ../ets_frontend
git checkout -b OpenHarmony_feature_20250328 origin/OpenHarmony_feature_20250328

cd ../runtime_core/static_core/tools

ln -s ../../../ets_frontend/ets2panda es2panda
cd ..

sudo ./scripts/install-deps-ubuntu -i=dev -i=test -i=coverage-tools (x86 host)
sudo ./scripts/install-deps-ubuntu -i=arm-dev  -i=test -i=coverage-tools (mac Aarch64)

pip3 install tqdm
pip3 install python-dotenv
./scripts/install-third-party --force-clone
```

## 2.编译
```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=./cmake/toolchain/host_clang_default.cmake -DCMAKE_MAKE_PROGRAM=ninja -GNinja .

cmake --build build -j8
```
## 3. Run
```sh
vim test.sts

function main(){
console.log("hello")
}
```
```sh
#编译sts生成abc
./build/bin/es2panda test.sts --output test.abc

# ark运行abc文件
./build/bin/ark --boot-panda-files=./build/plugins/ets/etsstdlib.abc --load-runtimes=ets test.abc test.ETSGLOBAL::main


./build/bin/ark --boot-panda-files=./build/plugins/ets/etsstdlib.abc --load-runtimes=ets test.abc <module-name>.ETSGLOBAL::main
// <module-name> 没有显式声明模块名的话，默认为当前文件名
```
##  4. Run Testcase

```sh
cd <runtime_core_PATH>/static_core/build
ninja tests
```

```sh
# parser/runtime/CTS test/astchecker/srcdumper

# 下载安装一些依赖
pip3 install jinja2
pip3 install PyPDF2
pip3 install pytz

cd <runtime_core_PATH>/static_core
sudo rm -r /tmp/ets
tests/tests-u-runner/runner.sh --ets-cts --show-progress --build-dir build --processes=all
tests/tests-u-runner/runner.sh --ets-func-tests --show-progress --build-dir build --processes=all
tests/tests-u-runner/runner.sh --parser --no-js --show-progress --build-dir build --processes=all
tests/tests-u-runner/runner.sh --ets-runtime --show-progress --build-dir build --processes=all
tests/tests-u-runner/runner.sh --astchecker --no-js --show-progress --build-dir build --processes=all
tests/tests-u-runner/runner.sh --srcdumper --build-dir build --processes=all --es2panda-timeout=120 --compare-files-iterations=2 --work-dir /tmp/ets
```


例子： `tests/tests-u-runner/runner. sh --ets-func-tests --chapter std-containers-dir --build-dir $BUILD --show-progress --processes=all`就会跑static_core/plugins/ets/tests/ets_func_tests/std/containers这里面的测试用例

## 5. 修改完代码做一键执行clang tidy + clang format
参考wiki:[https://gitee.com/JianfeiLee/arkcompiler_runtime_core/wikis/code_format.sh](https://gitee.com/JianfeiLee/arkcompiler_runtime_core/wikis/code_format.sh)  
文件夹结构约束：  
ets_frontend和runtime_core都需要在同一个目录下面，即对应的脚本里的base_path.

如何使用：  
**!!需要将当前的修改commit!!**  
可以根据git status中获取修改的文件

修改 base_path和out_path的路径，在To change注释下面  
需要对哪个仓的提交代码进行检查，就修改test_path的路径  
将此脚本放在base_path的目录下面  
接着给脚本赋予权限：chmod a+x code_format.sh  
执行bash code_format.sh

## 6. 提交代码相关指令

[gitee代码提交相关指令](https://gitee.com/JianfeiLee/arkcompiler_runtime_core/wikis/gitee%E4%BB%A3%E7%A0%81%E6%8F%90%E4%BA%A4%E7%9B%B8%E5%85%B3%E6%8C%87%E4%BB%A4?sort_id=13427779)
**追加修改** 到当前commit：  
    `git add .`  
    `git commit --amend`  
    `git push lijfMaster HEAD:br1108 -f`

## 7. 多文件编译并链接
```
//arktsconfig.json
{
	"compilerOptions": {
		"baseUrl" : "/path/to/baseurl",
		"paths": {
			"std": ["path/to/runtime_core/static_core/plugins/ets/stdlib/std"],
			"escompat": ["path/to/runtime_core/static_core/plugins/ets/stdlib/escompat"],
		}
	}
}
```

```
cd /path/tobaseurl
./bin/es2panda --arktsconfig=./arktsconfig.json
./bin/arklink --output=out.abc -- 1.abc 2.abc ......
// find out.abc at /path/tobaseurl
```

ets_func_tests:
The helper file should be marked:
```ts
/*---
	tags:[not-a-test]
---*/
```

Main file should import the required entities and specify the dependencies in the following way:
```ts
/*---
	files:[relative/path/to/dependency/file1.ets,relative/path/to/file2.ets]
---*/
```
