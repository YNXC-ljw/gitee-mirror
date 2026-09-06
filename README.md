# Gitee 自动同步到 GitHub

这个仓库里的 GitHub Actions 会定时把 Gitee 账号 pengge-student-c-language 下的仓库镜像到 YNXC-ljw。

- 每 6 小时自动运行一次(北京时间约 02:00 / 08:00 / 14:00 / 20:00)
- 也可以在 Actions 页面手动点 Run workflow 立即同步
- 仓库对照关系见 repos.txt(每行: Gitee路径|GitHub仓库名)

## 首次使用前

1. 在 GitHub 生成访问令牌: Settings -> Developer settings -> Personal access tokens -> Tokens (classic) -> Generate new token, 勾选 repo
2. 本仓库 Settings -> Secrets and variables -> Actions -> New repository secret
3. Name 填 GITEE_SYNC_PAT, Value 粘贴令牌, 点 Add secret

之后自动任务就有权限把代码写入你的各个仓库了。
