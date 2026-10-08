#!/usr/bin/env bash
# =============================================================================
#  三百 · 部署到 GitHub Pages
#
#  三种用法，任选其一：
#      bash deploy.sh                    # 已 gh auth login 过，直接复用登录态
#      GH_TOKEN=<PAT> bash deploy.sh     # 用 Personal Access Token
#      bash deploy.sh <PAT>
#
#  脚本会自动挑选可用的推送通道：
#      github.com:443 可达     -> HTTPS
#      被阻断（SNI 阻断）      -> SSH 经 ssh.github.com:443
# =============================================================================
set -uo pipefail

API="https://api.github.com"
REPO_NAME="${REPO_NAME:-changzheng90}"
KEY_TITLE="${KEY_TITLE:-changzheng90-pages}"
KEY_FILE="${KEY_FILE:-$HOME/.ssh/id_ed25519_github}"

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()   { printf '    [ok] %s\n' "$*"; }
warn() { printf '    [!] %s\n' "$*"; }
die()  { printf '\n\033[31m[×] %s\033[0m\n' "$*"; exit 1; }

# ---- 定位 gh（winget 装完后当前 shell 可能还没刷新 PATH）----
GH=""
for c in gh \
         "$LOCALAPPDATA/Microsoft/WinGet/Links/gh.exe" \
         "/c/Program Files/GitHub CLI/gh.exe"; do
  if command -v "$c" >/dev/null 2>&1; then GH="$c"; break; fi
done

# ---- JSON 解析（用 node，免装 jq）----
jget() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);const v=process.argv[1].split(".").reduce((a,k)=>a&&a[k],o);process.stdout.write(v==null?"":String(v))}catch(e){process.stdout.write("")}})' "$1"; }
jmsg() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(JSON.parse(s).message||"")}catch(e){process.stdout.write("")}})'; }
have_node() { command -v node >/dev/null 2>&1; }
have_node || die "需要 node 来解析 JSON，但未找到 node。请先安装 Node.js。"

# ---- 探测推送通道 ----
probe_https() { timeout 8 bash -c 'exec 3<>/dev/tcp/github.com/443' 2>/dev/null; }

# =============================================================================
say "1/7  获取凭据"
TOKEN="${GH_TOKEN:-${1:-}}"
USING_GH=0
USING_STORED=0
SRC=""
if [ -n "$TOKEN" ]; then
  SRC="命令行参数"
elif [ -n "$GH" ] && "$GH" auth status >/dev/null 2>&1; then
  TOKEN=$("$GH" auth token 2>/dev/null)
  [ -n "$TOKEN" ] || die "gh 已登录但无法取到 token"
  USING_GH=1; SRC="gh CLI 登录态"
else
  # 复用 Git Credential Manager 里已保存的 GitHub 凭据：
  # 这也是 gh-pages / npm run deploy 等既存流程一直在用的凭据
  TOKEN=$(printf 'protocol=https\nhost=github.com\n\n' \
          | GIT_TERMINAL_PROMPT=0 git credential fill 2>/dev/null \
          | sed -n 's/^password=//p')
  if [ -n "$TOKEN" ]; then USING_STORED=1; SRC="系统凭据管理器（Git Credential Manager）"; fi
fi
if [ -z "$TOKEN" ]; then
  cat <<'USAGE'

[!] 没有可用凭据。以下任选其一即可，都不需要创建 PAT：

    A) 直接用浏览器登录一次（之后自动记住）：
         gh auth login
       选 GitHub.com → HTTPS → Login with a web browser
       完成后重新运行：  bash deploy.sh

    B) 先手动 push 一次任意仓库，让 Git Credential Manager 记住凭据：
         git push https://github.com/<你的账号>/<任意仓库>.git
       之后本脚本会自动复用该凭据。

    C) 或者显式提供 Token：
         GH_TOKEN=<你的token> bash deploy.sh

USAGE
  exit 1
fi
ok "凭据来源：$SRC"
ok "token 前缀 ${TOKEN:0:4}****（长度 ${#TOKEN}），不会写入任何文件"

HD=(-H "Authorization: Bearer $TOKEN"
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2022-11-28")
API_BODY=$(mktemp)
trap 'rm -f "$API_BODY"' EXIT
api() { local m="$1" p="$2" b="${3:-}"
  if [ -n "$b" ]; then
    # 关键：请求体经文件传递。Git Bash/MSYS2 会把命令行参数里的非 ASCII
    # 字符按 Windows ANSI 代码页转码，直接 -d "$b" 会让中文变乱码，
    # GitHub 于是返回 400 Problems parsing JSON。
    printf '%s' "$b" > "$API_BODY"
    curl -sS -X "$m" "${HD[@]}" -H "Content-Type: application/json; charset=utf-8" \
         --data-binary "@$API_BODY" "$API$p"
  else
    curl -sS -X "$m" "${HD[@]}" "$API$p"
  fi
}

# =============================================================================
say "2/7  校验账号"
ME=$(api GET /user)
LOGIN=$(printf '%s' "$ME" | jget login)
[ -n "$LOGIN" ] || die "Token 无效或权限不足：$(printf '%s' "$ME" | jmsg)"
UID_=$(printf '%s' "$ME" | jget id)
N=$(printf '%s' "$ME" | jget name); [ -z "$N" ] && N="$LOGIN"
E=$(printf '%s' "$ME" | jget email)
# 没有公开邮箱时用 GitHub 的 noreply 地址（现代格式 <id>+<login>），保证归属正确又不泄露邮箱
if [ -z "$E" ]; then
  if [ -n "$UID_" ]; then E="${UID_}+${LOGIN}@users.noreply.github.com"
  else E="${LOGIN}@users.noreply.github.com"; fi
fi
ok "账号 $LOGIN（$N）"
ok "提交身份 $N <$E>"

# =============================================================================
say "3/7  创建仓库 $LOGIN/$REPO_NAME"
BODY=$(node -e 'process.stdout.write(JSON.stringify({name:process.argv[1],private:false,description:"三百 · 纪念中国工农红军长征胜利九十周年 — 设计语言由随机字符串推导",has_issues:true,has_wiki:false,has_projects:false,auto_init:false}))' "$REPO_NAME")
RES=$(api POST /user/repos "$BODY")
if [ -n "$(printf '%s' "$RES" | jget html_url)" ]; then
  ok "已创建 $(printf '%s' "$RES" | jget html_url)"
else
  case "$(printf '%s' "$RES" | jmsg)" in
    *"already exists"*) ok "仓库已存在，继续" ;;
    *) die "创建失败：$(printf '%s' "$RES" | jmsg)" ;;
  esac
fi

# =============================================================================
say "4/7  选择推送通道"
if probe_https; then
  TRANSPORT=https
  REMOTE="https://github.com/$LOGIN/$REPO_NAME.git"
  ok "github.com:443 可达 -> 使用 HTTPS"
  if [ "$USING_GH" = "1" ] && [ -n "$GH" ]; then
    "$GH" auth setup-git >/dev/null 2>&1 && ok "已让 gh 配置 git 凭据助手"
  fi
else
  TRANSPORT=ssh
  REMOTE="git@github.com:$LOGIN/$REPO_NAME.git"
  warn "github.com:443 被阻断 -> 改用 SSH 经 ssh.github.com:443"
  if [ ! -f "$KEY_FILE.pub" ]; then
    ssh-keygen -t ed25519 -C "$KEY_TITLE" -f "$KEY_FILE" -N "" -q && ok "已生成 SSH 密钥"
  fi
  PUB=$(cat "$KEY_FILE.pub")
  KBODY=$(node -e 'process.stdout.write(JSON.stringify({title:process.argv[1],key:process.argv[2]}))' "$KEY_TITLE" "$PUB")
  KRES=$(api POST /user/keys "$KBODY")
  if printf '%s' "$KRES" | jget id | grep -qE '^[0-9]+$'; then ok "公钥已登记"
  else
    case "$(printf '%s' "$KRES" | jmsg)" in
      *"already in use"*|*"already exists"*) ok "公钥已在账号中" ;;
      *) warn "登记公钥失败：$(printf '%s' "$KRES" | jmsg)" ;;
    esac
  fi
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  if ! grep -q "Host github.com" ~/.ssh/config 2>/dev/null; then
    cat >> ~/.ssh/config <<EOF

Host github.com
  HostName ssh.github.com
  Port 443
  User git
  IdentityFile $KEY_FILE
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
EOF
    chmod 600 ~/.ssh/config; ok "已写入 ~/.ssh/config"
  else
    ok "~/.ssh/config 已存在 github.com 配置"
  fi
fi

# =============================================================================
say "5/7  提交并推送"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || git init -b main -q
git symbolic-ref -q HEAD >/dev/null 2>&1 || git checkout -b main -q
git config user.name "$N"; git config user.email "$E"
git add -A
if git diff --cached --quiet; then ok "无新变更"
else
  git commit -q -F - <<'MSG'
三百 · 纪念中国工农红军长征胜利九十周年

设计语言由 shell 生成的 300 位随机字母数字串推导：
- 长度 300 ↔ 长征途中平均每 300 米一名红军牺牲
- 唯一的 90 藏在第 41 位起的 690 中
- 22 落在第 193 位 ↔ 1936.10.22 将台堡会师
- 62/62 全字符集覆盖，一个都不少
- 大写 134 : 小写 130 → 主栅格比例；数字和 164 → 色相 20°
MSG
  ok "已提交"
fi

if git remote get-url origin >/dev/null 2>&1; then git remote set-url origin "$REMOTE"
else git remote add origin "$REMOTE"; fi
ok "remote = $REMOTE"

printf '    推送中...\n'
if [ "$TRANSPORT" = "ssh" ]; then
  export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=25"
  git push -u origin main || die "推送失败（SSH）"
else
  if [ "$USING_STORED" = "1" ]; then
    # 凭据本来就在 GCM 里，直接 push 即可，无需再把 token 传给 git
    git push -u origin main || die "推送失败（HTTPS，凭据来自系统凭据管理器）"
  elif [ "$USING_GH" = "1" ]; then
    git push -u origin main || die "推送失败（HTTPS + gh 凭据助手）"
  else
    # 用行内凭据助手，不写入 .git/config，避免 token 落盘
    git -c credential.helper='!f() { echo "username=x-access-token"; echo "password=$TOKEN"; }; f' \
        push -u origin main || die "推送失败（HTTPS）"
  fi
fi
ok "推送完成"

# =============================================================================
say "6/7  开启 GitHub Pages"
PRES=$(api POST "/repos/$LOGIN/$REPO_NAME/pages" '{"source":{"branch":"main","path":"/"}}')
if [ -n "$(printf '%s' "$PRES" | jget html_url)" ]; then ok "Pages 已开启"
else
  case "$(printf '%s' "$PRES" | jmsg)" in
    *"already enabled"*|*"already exists"*) ok "Pages 已处于开启状态" ;;
    *) warn "开启失败：$(printf '%s' "$PRES" | jmsg)"
       warn "可在仓库 Settings → Pages 手动选择 branch: main / (root)" ;;
  esac
fi

# =============================================================================
URL="https://$LOGIN.github.io/$REPO_NAME/"
say "7/7  完成"
printf '\n    仓库   https://github.com/%s/%s\n    站点   %s\n' "$LOGIN" "$REPO_NAME" "$URL"
printf '\n    首次部署需 1–3 分钟构建。\n\n'
printf '    等待站点上线'
for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 12 "$URL" 2>/dev/null || echo 000)
  [ "$code" = "200" ] && { printf '\n    [ok] 站点已上线：%s\n\n' "$URL"; exit 0; }
  printf '.'
  sleep 10
done
printf '\n    尚未就绪（可能仍在构建）。稍后访问：%s\n\n' "$URL"
