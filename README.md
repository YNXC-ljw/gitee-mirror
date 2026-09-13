# Gitee 自动同步到 GitHub

这个仓库里放着一个自动任务：每 6 小时把 Gitee 账号 `pengge-student-c-language` 下的仓库，原样镜像到 GitHub 账号 `YNXC-ljw`。

- 自动运行时间：北京时间大约 02:00 / 08:00 / 14:00 / 20:00
- 手动立即同步：上方 `Actions` -> 左边 `Gitee 同步到 GitHub` -> `Run workflow` -> 绿色按钮
- 仓库对照表：[`repos.txt`](repos.txt)，一行一个仓库，格式是 `Gitee路径|GitHub仓库名`
- 每次运行的详细结果都在 `Actions` 里，哪个仓库成功、哪个失败一目了然；失败会给你发邮件

## 令牌过期了怎么办

GitHub 的令牌有有效期，过期后同步会失败并给你发邮件。换新令牌：

1. 打开 https://github.com/settings/tokens 生成一个新令牌，勾选 `repo`
2. 打开本仓库的 `Settings` -> `Secrets and variables` -> `Actions`
3. 点 `GITEE_SYNC_PAT` 右边的 `Update`，粘贴新令牌后保存

## 在 Gitee 新建了仓库怎么办

在 `repos.txt` 里加一行，例如 `新仓库路径|NewRepo`，同时到 GitHub 上建一个同名仓库，下一轮就会自动同步过去。

## 说明

- 同步方向是单向的：Gitee -> GitHub。请不要直接改 GitHub 上的代码，会被下一轮同步覆盖回去。
- 分支和标签也会一起同步，Gitee 上删掉的分支在 GitHub 上也会消失。
- 这个任务只做镜像搬运，不会改动 Gitee 上的任何东西。
