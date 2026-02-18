## git查看远程链接
`git remote -v`

## git重置远程链接

#### 方法一：直接修改 URL（推荐）
```sh
git remote set-url origin <新仓库URL>
git remote set-url origin https://github.com/newuser/newrepo.git
```

#### 方法二：先删除后添加（适合多远程仓库）

```
git remote remove origin            # 删除旧远程仓库
git remote add origin <新仓库URL>   # 添加新远程仓库
```

####  验证是否修改成功**
```sh
git remote -v  # 检查 URL 是否更新
```

#### 推送代码
`git push -u origin main  # 首次推送需用 -u 关联分支`

> 若遇到错误 `error: src refspec main does not match any`，请将 `main` 替换为你的分支名（如 `master`）。
