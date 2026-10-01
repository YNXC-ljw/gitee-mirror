#!/usr/bin/env bash
# Gitee <-> GitHub 双向同步
# 规则：
#   1. 两边分支完全一致时直接跳过，不下载任何东西
#   2. 两边都有新提交时自动合并，然后同时推回两边
#   3. 绝不删除任何一边已有的分支或提交
#   4. 真冲突（两边改了同一个文件的同一处）时停下来报告，不动任何东西
set -uo pipefail

GITEE_USER="pengge-student-c-language"
GH_USER="YNXC-ljw"
GITEE_TOKEN="${GITEE_TOKEN:?缺少 GITEE_TOKEN}"
GH_PAT="${PAT:?缺少 PAT}"

export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/true
export GCM_INTERACTIVE=never

git config --global user.name "auto-sync"
git config --global user.email "auto-sync@users.noreply.github.com"
git config --global advice.detachedHead false
git config --global pull.rebase false
git config --global http.version HTTP/1.1
# 传输速度低于 1KB/s 持续 30 秒就判定卡死并中断，避免整个任务无限挂起
git config --global http.lowSpeedLimit 1000
git config --global http.lowSpeedTime 30

NET_TIMEOUT=${NET_TIMEOUT:-240}
RETRY=${RETRY:-3}
MAX_SECONDS=${MAX_SECONDS:-2400}
DEADLINE=$(( $(date +%s) + MAX_SECONDS ))

# 网络操作统一走这里：单次超时 + 自动重试
net() {
  local what="$1"; shift
  local i
  for i in $(seq 1 "$RETRY"); do
    if timeout "$NET_TIMEOUT" "$@"; then
      return 0
    fi
    echo "   ${what}：第 ${i} 次没成功，等 5 秒再试"
    sleep 5
  done
  return 1
}

# 读取远端分支列表（最轻量，用来判断两边是不是本来就一致）
remote_heads() {
  local url="$1"
  local out=""
  local i
  for i in $(seq 1 "$RETRY"); do
    if out=$(timeout 120 git ls-remote --heads "$url" 2>/dev/null); then
      printf '%s' "$out" | sort
      return 0
    fi
    sleep 5
  done
  return 1
}

failed=""
total=0
ok=0
skipped=0
timedout=""

while IFS="|" read -r slug name; do
  slug="${slug%$'\r'}"
  name="${name%$'\r'}"
  [ -z "$slug" ] && continue
  total=$((total + 1))
  echo "::group::${slug} <-> ${name}"

  if [ "$(date +%s)" -gt "$DEADLINE" ]; then
    echo "::warning::整体已经跑太久，${slug} 本轮先跳过"
    failed="${failed} ${slug}"
    timedout="${timedout} ${slug}"
    echo "::endgroup::"
    continue
  fi

  gurl="${GITEE_BASE:-https://${GITEE_USER}:${GITEE_TOKEN}@gitee.com/${GITEE_USER}}/${slug}.git"
  hurl="${GH_BASE:-https://x-access-token:${GH_PAT}@github.com/${GH_USER}}/${name}.git"
  repo_ok=1

  # 先用最轻量的方式比对两边的分支，完全一致就不下载了（大仓库能省很多时间）
  if ! gh_heads=$(remote_heads "$hurl"); then
    echo "::error::${slug}：读不到 GitHub 的分支列表（网络问题）"
    failed="${failed} ${slug}"
    echo "::endgroup::"
    continue
  fi
  if ! gt_heads=$(remote_heads "$gurl"); then
    echo "::error::${slug}：读不到 Gitee 的分支列表（Gitee 连不上或令牌失效）"
    failed="${failed} ${slug}"
    echo "::endgroup::"
    continue
  fi
  if [ "$gh_heads" = "$gt_heads" ]; then
    echo "两边分支完全一致，跳过（不下载）"
    skipped=$((skipped + 1))
    ok=$((ok + 1))
    echo "::endgroup::"
    continue
  fi

  clone_ok=0
  for i in 1 2 3; do
    rm -rf workdir
    if timeout "$NET_TIMEOUT" git clone --quiet "$hurl" workdir; then
      clone_ok=1
      break
    fi
    echo "   下载 GitHub 仓库没成功，第 ${i} 次，等 5 秒再试"
    sleep 5
  done
  if [ "$clone_ok" != "1" ]; then
    echo "::error::${slug}：无法下载 GitHub 仓库（网络问题或超时）"
    failed="${failed} ${slug}"
    echo "::endgroup::"
    continue
  fi

  cd workdir || exit 1
  git remote set-url origin "$hurl"
  git remote add gitee "$gurl" 2>/dev/null || git remote set-url gitee "$gurl"

  if ! net "从 Gitee 拉取 ${slug}" git fetch --quiet gitee "+refs/heads/*:refs/remotes/gitee/*"; then
    echo "::error::${slug}：从 Gitee 拉取失败（Gitee 网络不通或令牌失效）"
    repo_ok=0
  fi

  if [ "$repo_ok" = "1" ]; then
    for b in $(git for-each-ref --format="%(refname:lstrip=3)" refs/remotes/gitee/); do
      echo "-- 分支 ${b}"
      if ! git rev-parse --verify -q "refs/remotes/origin/${b}" >/dev/null; then
        echo "   GitHub 还没有这个分支，直接推送"
        if ! net "${slug} 分支 ${b} 推送到 GitHub" git push --quiet origin "refs/remotes/gitee/${b}:refs/heads/${b}"; then
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
      if ! net "${slug} 分支 ${b} 推送到 GitHub" git push --quiet origin "HEAD:refs/heads/${b}"; then
        echo "::error::${slug} 分支 ${b} 推送到 GitHub 失败"
        repo_ok=0
        continue
      fi
      if ! net "${slug} 分支 ${b} 推送到 Gitee" git push --quiet gitee "HEAD:refs/heads/${b}"; then
        echo "::error::${slug} 分支 ${b} 推送到 Gitee 失败"
        repo_ok=0
        continue
      fi
      echo "   两边已一致"
    done

    # 只存在于 GitHub 的分支，顺手补到 Gitee
    for b in $(git for-each-ref --format="%(refname:lstrip=3)" refs/remotes/origin/); do
      [ "$b" = "HEAD" ] && continue
      if ! git rev-parse --verify -q "refs/remotes/gitee/${b}" >/dev/null; then
        echo "-- 分支 ${b} 只存在于 GitHub，补到 Gitee"
        if ! net "${slug} 分支 ${b} 推送到 Gitee" git push --quiet gitee "refs/remotes/origin/${b}:refs/heads/${b}"; then
          echo "::error::${slug} 分支 ${b} 推送到 Gitee 失败"
          repo_ok=0
        fi
      fi
    done

    net "同步标签" git fetch --quiet --tags gitee || true
    timeout "$NET_TIMEOUT" git push --quiet --tags origin 2>/dev/null || true
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

echo "共 ${total} 个仓库：成功 ${ok} 个（其中 ${skipped} 个本来就一致，直接跳过没下载）"
if [ -n "${timedout}" ]; then
  echo "::warning::这些仓库因为整体超时被跳过:${timedout}"
fi
if [ -n "${failed}" ]; then
  echo "::error::这些仓库没有同步成功:${failed}"
  exit 1
fi
