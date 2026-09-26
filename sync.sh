#!/usr/bin/env bash
# Gitee <-> GitHub 双向同步
# 规则：
#   1. 两边的提交都会合并到一起，然后同时推回两边
#   2. 绝不删除任何一边已有的分支或提交
#   3. 真冲突（两边改了同一个文件的同一处）时停下来报告，不动任何东西
set -uo pipefail

GITEE_USER="pengge-student-c-language"
GH_USER="YNXC-ljw"
GITEE_TOKEN="${GITEE_TOKEN:?缺少 GITEE_TOKEN}"
GH_PAT="${PAT:?缺少 PAT}"

git config --global user.name "auto-sync"
git config --global user.email "auto-sync@users.noreply.github.com"
git config --global advice.detachedHead false
git config --global pull.rebase false

failed=""
total=0
ok=0

while IFS="|" read -r slug name; do
  slug="${slug%$'\r'}"
  name="${name%$'\r'}"
  [ -z "$slug" ] && continue
  total=$((total + 1))
  echo "::group::${slug} <-> ${name}"
  rm -rf workdir
  gurl="${GITEE_BASE:-https://${GITEE_USER}:${GITEE_TOKEN}@gitee.com/${GITEE_USER}}/${slug}.git"
  hurl="${GH_BASE:-https://x-access-token:${GH_PAT}@github.com/${GH_USER}}/${name}.git"
  repo_ok=1

  if ! git clone --quiet "$hurl" workdir; then
    echo "::error::无法克隆 GitHub 上的 ${name}"
    failed="${failed} ${slug}"
    echo "::endgroup::"
    continue
  fi
  cd workdir || exit 1
  git remote set-url origin "$hurl"
  git remote add gitee "$gurl" 2>/dev/null || git remote set-url gitee "$gurl"

  if ! git fetch --quiet gitee "+refs/heads/*:refs/remotes/gitee/*"; then
    echo "::error::无法从 Gitee 拉取 ${slug}"
    repo_ok=0
  fi

  if [ "$repo_ok" = "1" ]; then
    for b in $(git for-each-ref --format="%(refname:lstrip=3)" refs/remotes/gitee/); do
      echo "-- 分支 ${b}"
      if ! git rev-parse --verify -q "refs/remotes/origin/${b}" >/dev/null; then
        echo "   GitHub 还没有这个分支，直接推送"
        if ! git push --quiet origin "refs/remotes/gitee/${b}:refs/heads/${b}"; then
          echo "::error::${slug} 分支 ${b} 推送到 GitHub 失败"
          repo_ok=0
        fi
        continue
      fi
      if ! git checkout --quiet -B "$b" "refs/remotes/origin/${b}"; then
        echo "::error::${slug} 切换分支 ${b} 失败"
        repo_ok=0
        continue
      fi
      if git merge-base --is-ancestor "refs/remotes/gitee/${b}" HEAD; then
        echo "   GitHub 已包含 Gitee 的最新提交"
      elif git merge-base --is-ancestor HEAD "refs/remotes/gitee/${b}"; then
        echo "   Gitee 有新提交，快进"
        git merge --quiet --ff-only "refs/remotes/gitee/${b}" || repo_ok=0
      else
        echo "   两边都有新提交，自动合并"
        if ! git merge --quiet --no-edit -m "自动合并 Gitee 与 GitHub 的改动" "refs/remotes/gitee/${b}"; then
          git merge --abort 2>/dev/null
          echo "::error::${slug} 分支 ${b} 两边改了同一个文件，需要手动处理（本轮没有改动任何东西）"
          repo_ok=0
          continue
        fi
      fi
      if ! git push --quiet origin "HEAD:refs/heads/${b}"; then
        echo "::error::${slug} 分支 ${b} 推送到 GitHub 失败"
        repo_ok=0
        continue
      fi
      if ! git push --quiet gitee "HEAD:refs/heads/${b}"; then
        echo "::error::${slug} 分支 ${b} 推送到 Gitee 失败"
        repo_ok=0
        continue
      fi
      echo "   两边已一致"
    done
    git fetch --quiet --tags gitee 2>/dev/null
    git push --quiet --tags origin 2>/dev/null || true
  fi

  cd .. || exit 1
  rm -rf workdir
  if [ "$repo_ok" = "1" ]; then
    ok=$((ok + 1))
    echo "OK ${slug} 同步成功"
  else
    failed="${failed} ${slug}"
  fi
  echo "::endgroup::"
done < repos.txt

echo "共 ${total} 个仓库，完全成功 ${ok} 个。"
if [ -n "${failed}" ]; then
  echo "::error::这些仓库没有同步成功:${failed}"
  exit 1
fi
