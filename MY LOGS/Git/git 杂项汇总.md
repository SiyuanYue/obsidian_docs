
#git 

# HEAD指针

#HEAD

在 Git 中，`HEAD` 是一个特殊的指针，它指向当前分支的最新提交（也称为“尖端”）。当你进行某些操作时，`HEAD` 可以用来引用当前分支的最新状态。

`HEAD^` 是一个特定的语法，用于引用当前分支的前一个提交。具体来说：

- `HEAD` 指向当前分支的最新提交。
- `HEAD^` 指向 `HEAD` 的父提交，即当前分支的前一个提交。

如果当前分支的最新提交是一个合并提交（即有两个父提交），那么 `HEAD^` 默认指向第一个父提交。你可以使用 `HEAD^1` 明确指定第一个父提交，`HEAD^2` 指定第二个父提交。

### 示例

假设你有一个简单的提交历史如下：

浅色版本

```
A -- B -- C (main)
```

- `HEAD` 指向 `C`。
- `HEAD^` 指向 `B`。

再假设你有一个合并提交的历史如下：

浅色版本

```
A -- B -- D (main)
     \    /
      C -- E
```

- `HEAD` 指向 `D`。
- `HEAD^` 或 `HEAD^1` 指向 `B`。
- `HEAD^2` 指向 `E`。

### 使用场景

1. **回退到前一个提交**：

```sh
git checkout HEAD^
```

这条命令会将工作目录切换到当前分支的前一个提交。

2. **撤销前一个提交**：

```sh
git reset HEAD^
 ```

这条命令会将当前分支的最新提交撤销，但保留工作目录中的更改。

3. **比较当前提交和前一个提交**：

```sh
git diff HEAD^
```

这条命令会显示当前提交和前一个提交之间的差异。


# 打patch和应用patch

#patch

在 Git 中，`patch` 文件是一种文本文件，记录了两个版本之间的差异。你可以使用 `patch` 文件来生成补丁并应用于其他仓库或分支。下面是如何在 Git 中创建和应用 `patch` 文件的步骤。
### 创建 Patch 文件

**生成单个提交的 Patch**： 如果你只想生成某个特定提交的 `patch` 文件，可以使用以下命令：

```sh
git format-patch -1 <commit-hash>
```

其中 `<commit-hash>` 是你想要生成 `patch` 的提交的哈希值。`-1` 表示只生成一个提交的 `patch`。

**生成某commit以来的修改patch（不包含该commit**

`git format-patch HEAD^` 生成最近的1次commit的patch

`git format-patch HEAD^^`生成最近的2次commit的patch

**生成两个commit间的修改的patch**

`git format-patch <r1>..<r2>`      （包含两个commit. <\r1>和<\r2>都是具体的commit号)

### 应用patch

`git apply --stat ****.diff`

查看patch的情况

`git apply --check ****.diff`

检查patch是否能够打上，如果没有任何输出，则说明无冲突，可以打上

**应用patch**

`git am`与`git apply

>git apply是另外一种打patch的命令，其与git am的区别是，git apply并不会将commit message等打上去，打完patch后需要重新git add和git commit，而git am会直接将patch的所有信息打上去，而且不用重新git add和git commit,author也是patch的author而不是打patch的人

`git am ****.diff`


# 合并多个commit: `git rebase`

#rebase #合并commit

**使用 `git rebase -i`（交互式 rebase）**:

1. **切换到需要合并提交的分支**
```sh
git checkout <branch-name>
```
2. **启动交互式 rebase**

```sh
git rebase -i HEAD~n
```
其中 `n` 是你想要合并的最近的提交数量。例如，如果你想合并最近的 3 个提交，可以使用 `git rebase -i HEAD~3`。

3. **编辑 rebase 脚本**
	会打开一个文本编辑器，列出从 `HEAD~n` 开始的 `n` 个提交。你可以选择以下操作：
	- `pick`：保留提交
	- `squash`：将当前提交与前一个提交合并，并保留提交信息
	- `fixup`：将当前提交与前一个提交合并，但不保留当前提交的提交信息
	例如，假设你有以下提交历史：
	```sh
	pick abc1234 Commit 1
	pick def4567 Commit 2
	pick ghi7890 Commit 3
	```
	
	你可以修改为：

	```sh
	pick abc1234 Commit 1
	squash def4567 Commit 2
	squash ghi7890 Commit 3
	```

4. **保存并退出编辑器**： Git 会将选定的提交合并成一个提交，并提示你编辑合并后的提交信息。

5. **完成 rebase**： 如果没有冲突，rebase 会自动完成。如果有冲突，解决冲突后继续 rebase：
```sh
git add <conflicted-file>
git rebase --continue
```

# ERROR: commit message doesn't match standard format, please check!

```
git commit --no-verify -m "xxxxxx"
```



---

Ref:
[如何用git命令生成Patch和打Patch - 青山牧云人 - 博客园](https://www.cnblogs.com/ArsenalfanInECNU/p/8931377.html)
QianWen