#!/usr/bin/env bash
# =============================================================================
#  三百 · 通过 GitHub Git Data API 部署到 Pages
#
#  为什么需要这个脚本：
#      部分网络会按 SNI 阻断 github.com:443，导致 git push（HTTPS 与 SSH）都不通，
#      但 api.github.com:443 通常仍然可达。
#      本脚本因此完全不使用 git push，改为通过 REST API 直接写入仓库：
#          blobs  →  tree  →  commit  →  ref
#      幂等：每次运行都在远端当前 HEAD 之上新建提交，可反复运行来更新站点。
#
#  用法：
#      bash deploy-api.sh
#      GH_TOKEN=<PAT> bash deploy-api.sh
#      EXCLUDE="shots/" bash deploy-api.sh     # 排除大文件
#
#  两个 Windows 环境的坑，已在下面规避：
#      1) Git Bash 会把命令行参数里的非 ASCII 按 ANSI 代码页转码
#         -> 所有 JSON 请求体经文件传递（--data-binary @file）
#      2) node 是 Windows 二进制，不认识 /tmp 这类 MSYS 路径
#         -> 临时目录用相对路径
# =============================================================================
set -uo pipefail

API="https://api.github.com"
REPO_NAME="${REPO_NAME:-changzheng90}"
EXCLUDE="${EXCLUDE:-}"

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()   { printf '    [ok] %s\n' "$*"; }
warn() { printf '    [!] %s\n' "$*"; }
die()  { printf '\n\033[31m[×] %s\033[0m\n' "$*"; exit 1; }

command -v node >/dev/null 2>&1 || die "需要 node 来构造 JSON 请求体"

# 临时工作目录：必须用相对路径，node（Windows 版）才认
W=".dtmp-deploy"
rm -rf "$W"; mkdir -p "$W"
trap 'rm -rf "$W"' EXIT INT TERM

# ---- 凭据 ----
TOKEN="${GH_TOKEN:-${1:-}}"
if [ -z "$TOKEN" ]; then
  TOKEN=$(printf 'protocol=https\nhost=github.com\n\n' \
          | GIT_TERMINAL_PROMPT=0 git credential fill 2>/dev/null \
          | sed -n 's/^password=//p')
fi
[ -n "$TOKEN" ] || die "未取到凭据。请先 gh auth login，或提供 GH_TOKEN。"

HD=(-H "Authorization: Bearer $TOKEN"
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2022-11-28")

jget() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);const v=process.argv[1].split(".").reduce((a,k)=>a&&a[k],o);process.stdout.write(v==null?"":String(v))}catch(e){process.stdout.write("")}})' "$1"; }
jmsg() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(JSON.parse(s).message||"")}catch(e){process.stdout.write("")}})'; }

send() { # method path bodyfile
  local m="$1" p="$2" f="$3"
  curl -sS -X "$m" "${HD[@]}" -H "Content-Type: application/json; charset=utf-8" \
       --data-binary "@$f" "$API$p"
}

# =============================================================================
say "1/6  校验账号"
ME=$(curl -sS "${HD[@]}" "$API/user")
LOGIN=$(printf '%s' "$ME" | jget login)
[ -n "$LOGIN" ] || die "凭据无效：$(printf '%s' "$ME" | jmsg)"
UID_=$(printf '%s' "$ME" | jget id)
N=$(printf '%s' "$ME" | jget name); [ -z "$N" ] && N="$LOGIN"
E=$(printf '%s' "$ME" | jget email)
[ -z "$E" ] && E="${UID_}+${LOGIN}@users.noreply.github.com"
ok "账号 $LOGIN（$N）"

# =============================================================================
say "2/6  确认仓库"
R=$(curl -sS "${HD[@]}" "$API/repos/$LOGIN/$REPO_NAME")
if [ -n "$(printf '%s' "$R" | jget full_name)" ]; then
  ok "仓库已存在"
else
  node -e 'process.stdout.write(JSON.stringify({name:process.argv[1],private:false,description:"三百 · 纪念中国工农红军长征胜利九十周年 — 设计语言由随机字符串推导",has_issues:true,has_wiki:false,has_projects:false,auto_init:false}))' \
    "$REPO_NAME" > "$W/repo.json"
  R=$(send POST /user/repos "$W/repo.json")
  [ -n "$(printf '%s' "$R" | jget full_name)" ] || die "创建仓库失败：$(printf '%s' "$R" | jmsg)"
  ok "已创建 https://github.com/$LOGIN/$REPO_NAME"
fi

# =============================================================================
say "3/6  上传文件为 blob"
PARENT=$(curl -sS "${HD[@]}" "$API/repos/$LOGIN/$REPO_NAME/git/ref/heads/main" | jget object.sha)

# GitHub 不允许在"完全没有提交"的仓库上调用 Git Data API（会返回 409
# Git Repository is empty）。所以空仓库时要先用 Contents API 落到一个初始提交。
if [ -z "$PARENT" ]; then
  ok "远端为空仓库 -> 先用 Contents API 建立初始提交"
  BOOT=".gitattributes"
  if [ ! -f "$BOOT" ]; then printf '* text=auto\n' > "$BOOT"; fi
  node -e '
    const fs=require("fs");
    const b64=fs.readFileSync(process.argv[1]).toString("base64");
    fs.writeFileSync(process.argv[2], JSON.stringify({
      message:"chore: 初始化仓库", content:b64, branch:"main"
    }));
  ' "$BOOT" "$W/init.json"
  IRES=$(send PUT "/repos/$LOGIN/$REPO_NAME/contents/$BOOT" "$W/init.json")
  PARENT=$(printf '%s' "$IRES" | jget commit.sha)
  [ -n "$PARENT" ] || die "初始化提交失败：$(printf '%s' "$IRES" | jmsg)"
  ok "初始提交 ${PARENT:0:10}"
else
  ok "远端 HEAD ${PARENT:0:10}"
fi

# 待上传清单
: > "$W/list.txt"
for f in $(git ls-files); do
  skip=0
  for x in $EXCLUDE; do case "$f" in "$x"*) skip=1 ;; esac; done
  [ "$skip" = "1" ] && continue
  printf '%s\n' "$f" >> "$W/list.txt"
done
COUNT=$(grep -c . "$W/list.txt" || true)
printf '    共 %s 个文件\n' "$COUNT"
[ "$COUNT" -gt 0 ] || die "没有可上传的文件（本地是否已有提交？）"

: > "$W/tree.json"
i=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  i=$((i+1))
  git show "HEAD:$f" > "$W/blob.bin"
  node -e '
    const fs=require("fs");
    const b64=fs.readFileSync(process.argv[1]).toString("base64");
    fs.writeFileSync(process.argv[2], JSON.stringify({content:b64,encoding:"base64"}));
  ' "$W/blob.bin" "$W/blob.json"
  SHA=$(send POST "/repos/$LOGIN/$REPO_NAME/git/blobs" "$W/blob.json" | jget sha)
  [ -n "$SHA" ] || { printf '\n'; die "blob 上传失败：$f"; }
  node -e '
    const fs=require("fs");
    fs.appendFileSync(process.argv[1], JSON.stringify({
      path:process.argv[2], mode:"100644", type:"blob", sha:process.argv[3]
    })+"\n");
  ' "$W/tree.json" "$f" "$SHA"
  printf '\r    上传中 %d/%s  %-44.44s' "$i" "$COUNT" "$f"
done < "$W/list.txt"
printf '\n'
ok "全部 blob 已上传"

# =============================================================================
say "4/6  创建 tree 与 commit"
node -e '
  const fs=require("fs");
  const entries=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").filter(Boolean).map(JSON.parse);
  fs.writeFileSync(process.argv[2], JSON.stringify({tree:entries}));
' "$W/tree.json" "$W/treebody.json"
TREE=$(send POST "/repos/$LOGIN/$REPO_NAME/git/trees" "$W/treebody.json" | jget sha)
[ -n "$TREE" ] || die "创建 tree 失败"
ok "tree ${TREE:0:10}（${COUNT} 个条目）"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
node -e '
  const fs=require("fs");
  const msg=[
    "三百 · 纪念中国工农红军长征胜利九十周年","",
    "设计语言由 shell 生成的 300 位随机字母数字串推导：",
    "- 长度 300 ↔ 长征途中平均每 300 米一名红军牺牲",
    "- 唯一的 90 藏在第 41 位起的 690 中",
    "- 22 落在第 193 位 ↔ 1936.10.22 将台堡会师",
    "- 62/62 全字符集覆盖，一个都不少",
    "- 大写 134 : 小写 130 → 主栅格比例；数字和 164 → 色相 20°"
  ].join("\n");
  const body={message:msg, tree:process.argv[1],
    author:{name:process.argv[2],email:process.argv[3],date:process.argv[4]},
    committer:{name:process.argv[2],email:process.argv[3],date:process.argv[4]}};
  if (process.argv[5]) body.parents=[process.argv[5]];
  fs.writeFileSync(process.argv[6], JSON.stringify(body));
' "$TREE" "$N" "$E" "$NOW" "${PARENT:-}" "$W/commit.json"
COMMIT=$(send POST "/repos/$LOGIN/$REPO_NAME/git/commits" "$W/commit.json" | jget sha)
[ -n "$COMMIT" ] || die "创建 commit 失败"
ok "commit ${COMMIT:0:10}"

# =============================================================================
say "5/6  更新 main 分支引用"
if [ -n "$PARENT" ]; then
  node -e 'process.stdout.write(JSON.stringify({sha:process.argv[1],force:false}))' "$COMMIT" > "$W/ref.json"
  RES=$(send PATCH "/repos/$LOGIN/$REPO_NAME/git/refs/heads/main" "$W/ref.json")
else
  node -e 'process.stdout.write(JSON.stringify({ref:"refs/heads/main",sha:process.argv[1]}))' "$COMMIT" > "$W/ref.json"
  RES=$(send POST "/repos/$LOGIN/$REPO_NAME/git/refs" "$W/ref.json")
fi
if [ -n "$(printf '%s' "$RES" | jget object.sha)" ] || [ -n "$(printf '%s' "$RES" | jget ref)" ]; then
  ok "main -> ${COMMIT:0:10}"
else
  die "更新引用失败：$(printf '%s' "$RES" | jmsg)"
fi
# 记下远端 HEAD，便于你日后与本地仓库对齐
printf '%s\n' "$COMMIT" > .deploy-remote-head

# =============================================================================
say "6/6  开启 GitHub Pages"
node -e 'process.stdout.write(JSON.stringify({source:{branch:"main",path:"/"}}))' > "$W/pages.json"
PRES=$(send POST "/repos/$LOGIN/$REPO_NAME/pages" "$W/pages.json")
if [ -n "$(printf '%s' "$PRES" | jget html_url)" ]; then ok "Pages 已开启"
else
  case "$(printf '%s' "$PRES" | jmsg)" in
    *"already enabled"*|*"already exists"*) ok "Pages 已处于开启状态" ;;
    *) warn "开启失败：$(printf '%s' "$PRES" | jmsg)"
       warn "可在仓库 Settings → Pages 手动选 branch: main / (root)" ;;
  esac
fi

URL="https://$LOGIN.github.io/$REPO_NAME/"
printf '\n\033[1m    仓库   https://github.com/%s/%s\033[0m\n' "$LOGIN" "$REPO_NAME"
printf '\033[1m    站点   %s\033[0m\n\n' "$URL"
printf '    等待构建上线（首次约 1–3 分钟）'
for _ in $(seq 1 36); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 12 "$URL" 2>/dev/null || echo 000)
  [ "$code" = "200" ] && { printf '\n    [ok] 已上线：%s\n\n' "$URL"; exit 0; }
  printf '.'
  sleep 10
done
printf '\n    尚未返回 200（可能仍在构建）。稍后访问：%s\n\n' "$URL"
