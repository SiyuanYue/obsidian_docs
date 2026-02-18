#git #branch #pr

在 Git 中，你可以使用下面的命令在当前分支基础上创建并切换到一个新分支：

```bash
git checkout -b new-branch
```

其中，`new-branch` 是你新分支的名称。如果你只想创建分支而不立即切换，可以使用：

```bash
git branch new-branch
```

此外，从 Git 2.23 开始，还可以使用新的命令：

```bash
git switch -c new-branch
```

这些命令都会在当前分支的基础上创建一个新分支，并且新分支会继承当前分支的提交记录。

# 本地分支与远程分支建立联系
要将指定远程分支的代码拉取到本地分支，并建立两者之间的对应关系，你可以按以下步骤操作：

1. **新建本地分支并建立跟踪关系：**  
   如果本地还没有对应分支，可以直接基于远程分支创建本地分支，同时设置跟踪关系。例如，要将远程分支 `origin/feature` 拉取到本地，并命名为 `feature`，可以执行：  
   ```bash
   git checkout -b feature origin/feature
   ```  
   这条命令会新建一个名为 `feature` 的本地分支，并自动将它设置为跟踪远程的 `origin/feature` 分支。

2. **为已有本地分支设置远程跟踪分支：**  
   如果本地已经存在相应的分支，但没有建立跟踪关系，可以在该分支上执行：  
   ```bash
   git branch --set-upstream-to=origin/feature
   ```  
   这会将当前本地分支与远程的 `origin/feature` 建立对应关系。
3. `git branch -vv`   查看关联关系

4. **拉取远程更新：**  
   建立好跟踪关系后，直接在本地分支上使用：  
   ```bash
   git pull
   ```  
   即可从远程分支拉取最新代码并合并到本地分支中。

这种方法可以确保在执行 `git pull` 或 `git push` 时，Git 会自动知道对应的远程分支，从而简化操作。


# 基本操作
| 操作                        | 命令                                |
| ------------------------- | --------------------------------- |
| 查看冲突文件                    | `git status`                      |
| 回退                        | `git reset --hard <目标哈希>/HEAD~n ` |
| 清理掉 untracked,删除未跟踪的文件和目录 | `git clean -fd`                   |
# 打 PR
创建分支后想把一个 PR 的代码打下来阅读、运行。

要把一个 PR（Pull Request）的内容合并到本地分支上，有几种常见方法。下面介绍两种常用的方式：

---

### 方法一：通过 fetch 和 merge（推荐）

**Fetch PR 到本地临时分支**  
   假设 PR 编号为 `123`，你可以执行下面的命令，把 PR 内容 fetch 到一个临时分支（例如 `pr-123`）：  
   ```bash
   git fetch origin pull/123/head:pr-123
   ```
   这里的 `origin` 是远程仓库的名称，`pull/123/head` 是 GitHub 为 PR 提供的引用，`pr-123` 是你本地创建的分支名。

 **合并 PR 到当前分支**  
   在确保你当前处于需要合并 PR 内容的分支上后，执行：  
   ```bash
   git merge pr-123
   ```
   这会将 PR 的所有提交合并到当前分支上。

**清理临时分支（可选）**  
   如果合并无误后，不再需要临时分支，可以删除它：  
   ```bash
   git branch -d pr-123
   ```

---
### 方法二：pull 到当前分支

使用 `git pull` 命令将 PR 内容拉取并合并到当前分支：
```bash
git pull origin pull/[PR编号]/head --rebase
```
例如：
```bash
git pull origin pull/414/head --rebase
```
这会直接从远程仓库的 PR 对应分支拉取代码，并与本地当前分支自动合并

### 方法二：使用 patch 方式应用 PR

8. **获取 PR 的 patch 文件**  
   GitHub 为每个 PR 都提供一个 patch 文件，你可以通过下面的 URL 获取（同样以 PR 123 为例）：  
   ```
   https://github.com/your-username/your-repo/pull/123.patch
   ```
   请将 `your-username/your-repo` 替换为你的 GitHub 仓库路径。

9. **将 patch 应用到当前分支**  
   在当前分支上，使用 `git am` 命令应用 patch：  
   ```bash
   curl https://github.com/your-username/your-repo/pull/123.patch | git am
   ```
   这样，PR 中的每个提交都会以补丁的形式依次应用到当前分支上。

---

这两种方法都能把 PR 中的修改“打”到你当前的分支上，选择哪一种取决于你的使用习惯和具体需求。  
如果你希望保留 PR 中的提交记录，建议使用方法一；如果你希望直接应用修改而不保留原有提交记录，可以考虑方法二。

# PR 重新 push 了
##  回退本地分支并重新拉取远程分支
求速度。这样可以更快捷地解决代码冲突或错误合并的问题
### 1. **回退本地分支**

使用 `git reset --hard` 命令将本地分支强制回退到指定提交状态，丢弃所有未提交的改动和错误的合并结果：
```bash
git reset --hard <目标提交哈希>
```
- **示例**：若要回退到前一次提交，可执行 `git reset --hard HEAD~1`

- **作用**：重置 HEAD 指针、暂存区和工作目录，确保本地分支完全与目标提交一致

### 2. **重新拉取远程分支**

回退后，通过 `git pull` 重新拉取远程最新代码：
```bash
git pull origin <远程分支名>
```
- **示例**：若远程分支为 `dev`，则执行 `git pull origin dev`
- **作用**：将远程分支的最新内容同步到本地，确保代码与团队版本一致

### 3. **解决冲突（如有必要）**

若重新拉取时出现冲突：
1. 手动解决冲突文件中的标记（如 `<<<<<<< HEAD`）。
2. 使用 `git add` 标记已解决的文件。
3. 完成合并提交：`git commit -m "Merge conflict resolved"`


---

### **注意事项**

13. **强制推送的风险**  
    如果回退前本地分支已推送到远程，需用 `git push --force` 强制覆盖远程分支。但此操作会重写历史，可能影响其他协作者，需谨慎使用
14. **恢复误操作**  
    若误删提交，可通过 `git reflog` 查看操作历史，找回被覆盖的提交哈希，再通过 `git reset --hard` 恢复
15. **替代方案推荐**
    - **仅撤销合并操作**：使用 `git merge --abort` 终止合并并回到合并前状态。
    - **保留本地修改**：通过 `git stash` 暂存当前改动，**拉取后再恢复**（`git stash pop`）

---

### **适用场景**

- **本地代码混乱**：实验性改动导致分支不可用，需快速回退到稳定版本

- **合并冲突复杂**：手动解决冲突耗时，回退后重新拉取可能更高效

- **同步团队代码**：确保本地分支与远程最新版本一致，避免后续协作问题

此方法适用于本地未推送的修改，若已推送且涉及多人协作，建议改用 `git revert` 生成反向提交，避免强制推送的风险




---

### ​**后续更新 PR 的方法**

当 PR 有新提交时，重复以下操作：
```bash
# 拉取最新代码
git fetch origin pull/3507/head

# 合并到当前分支
git merge FETCH_HEAD
# 或变基
git rebase FETCH_HEAD
```

---

### ​**为什么不能直接用 `git pull origin pr-3507`？**
- GitHub 的 PR 分支通过 `pull/<PR编号>/head` 引用，而不是直接以分支名存在。
- 本地分支 `pr-3507` 是你手动创建的，它并不直接关联远程分支，因此 `git pull` 需要明确指定 PR 的引用路径。


## 解决合并冲突

你在合并代码时遇到了 **多个文件冲突**，尤其是 `add/add` 冲突（两个分支都新增了同名文件但内容不同）。以下是分步解决方案：

### **1. 确认冲突文件列表**
运行 `git status`，查看所有冲突文件（标记为 `Unmerged paths`）：
```bash
git status
```
输出示例：
```
Unmerged paths:
  both added:      static_core/plugins/ets/stdlib/std/containers/ArrayBlockingQueue.sts
  both added:      static_core/plugins/ets/tests/ets_func_tests/std/containers/array_blocking_queue/ArrayBlockingQueue_AddTest.sts
  ...
```

---

### **2. 解决 `add/add` 冲突**
`add/add` 冲突表示 **两个分支都添加了同名文件**，需手动选择保留哪一版或合并内容。

#### **方法一：保留当前分支的版本（你的本地修改）**
```bash
git checkout --ours <file-path>
```
示例：
```bash
git checkout --ours static_core/plugins/ets/stdlib/std/containers/ArrayBlockingQueue.sts
```

#### **方法二：保留合并分支的版本（PR 的修改）**
```bash
git checkout --theirs <file-path>
```
示例：
```bash
git checkout --theirs static_core/plugins/ets/tests/ets_func_tests/std/containers/array_blocking_queue/ArrayBlockingQueue_AddTest.sts
```

#### **方法三：手动合并内容**
16. 打开冲突文件，Git 会标记冲突部分：
   ```
   <<<<<<< HEAD
   这是你的本地内容
   =======
   这是 PR 的内容
   >>>>>>> FETCH_HEAD
   ```
17. 编辑文件，保留需要的代码，删除 `<<<<<<<`、`=======` 和 `>>>>>>>` 标记。
18. 保存文件。

---

### **3. 标记冲突已解决**
对每个解决后的文件执行：
```bash
git add <file-path>
```
示例：
```bash
git add static_core/plugins/ets/stdlib/std/containers/ArrayBlockingQueue.sts
```

---

### **4. 完成合并**
所有冲突解决并 `git add` 后，提交合并结果：
```bash
git commit -m "Merge PR-3507: Resolve conflicts in containers and tests"
```

---

### **5. 批量处理冲突的建议**
由于冲突文件较多，可结合脚本或工具简化操作：

#### **使用图形化工具（如 VS Code）**
```bash
code .
```
- VS Code 的 Git 插件会高亮冲突文件，支持一键选择保留 `--ours` 或 `--theirs`。

#### **批量保留某一版本**
保留所有 `add/add` 冲突的 PR 版本：
```bash
git checkout --theirs -- $(git diff --name-only --diff-filter=AU)
```

---

### **后续建议**
**优先使用 `rebase` 替代 `merge`**  
   若频繁遇到冲突，可改用变基保持提交历史线性：
```bash
git fetch origin pull/3507/head
git rebase FETCH_HEAD
```
   冲突解决步骤与 `merge` 类似，但需依次处理每个提交的冲突。
**配置合并策略**  
   若多个文件需统一保留某一版本，可配置合并策略：
 
```bash
git merge -Xours FETCH_HEAD   # 自动保留本地版本
# 或
git merge -Xtheirs FETCH_HEAD # 自动保留 PR 版本
```

---

### **关键命令总结**
| 操作         | 命令                                                                  |
| ---------- | ------------------------------------------------------------------- |
| 查看冲突文件     | `git status`                                                        |
| 保留本地版本     | `git checkout --ours <file>`                                        |
| 保留 PR 版本   | `git checkout --theirs <file>`                                      |
| 标记解决       | `git add <file>`                                                    |
| 提交合并       | `git commit -m "Merge message"`                                     |
| 批量保留 PR 版本 | `git checkout --theirs -- $(git diff --name-only --diff-filter=AU)` |

通过以上步骤，可高效解决大量 `add/add` 冲突。若仍有疑问，可提供具体文件内容进一步分析。

# 原始仓库更新，需要同步到本地，搭建环境验证，避免冲突
```sh
# 添加上游
git remote add upstream https://gitee.com/openharmony/arkcompiler_runtime_core.git

# fetch upstream
git fetch upstream

# rebase 将当前提交rebase的upstream之后
git rebase upstream/OpenHarmony_feature_20250328
```

注意对应关系
origin -> 远程仓库（fork的私仓）
upstream -> 上游仓库 （被fork的源仓库）


