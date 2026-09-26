# Gitee <-> GitHub 双向同步

这个仓库里放着一个自动任务：每 6 小时把 Gitee 账号 `pengge-student-c-language` 和 GitHub 账号 `YNXC-ljw` 的仓库**双向合并**。

## 怎么用

- 在 Gitee 上用（比如小乌龟）提交代码 → 会自动同步到 GitHub
- 在 GitHub 网页上写 README、文档 → 会自动同步回 Gitee
- 两边最终内容完全一致；**不会删除任何一边已有的提交或分支**

## 运行时间与手动方式

- 自动：每 6 小时一次（北京时间约 02:00 / 08:00 / 14:00 / 20:00）
- 手动：上方 `Actions` -> 左边 `Gitee <-> GitHub 双向同步` -> `Run workflow`
- 每次结果都在 `Actions` 里，哪个仓库成功一目了然；出问题会给你发邮件

## 重要：两边同时改了同一个地方会停下来

如果同一个文件的同一处被两边都改了，机器没法判断谁是对的，这一轮会**停下并给你发邮件**，两边的代码都不会被动。
解决办法：去仓库里把冲突的地方改成你想要的样子，然后手动点一次 `Run workflow`。

## 用本地 Git / 小乌龟推代码之前，先拉取

因为同步会在 Gitee 上生成合并提交，你本地仓库可能稍微落后。推送前先点一次「拉取」，再推送即可。

## 令牌

两个密文（Settings -> Secrets and variables -> Actions）：

| 名称 | 用途 | 有效期 |
|---|---|---|
| `GITEE_SYNC_PAT` | 往 GitHub 推 | 2026-10-13 到期 |
| `GITEE_TOKEN` | 往 Gitee 推 | Gitee 私人令牌，默认不过期 |

任一令牌失效都会导致同步失败并给你发邮件，换新令牌后到密文里 `Update` 即可。

## 仓库对照表

见 [`repos.txt`](repos.txt)，一行一个仓库，格式 `Gitee路径|GitHub仓库名`。在 Gitee 新建了仓库就在这里加一行，同时在 GitHub 建一个同名仓库。
