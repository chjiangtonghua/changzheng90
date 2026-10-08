# 三百 · 纪念中国工农红军长征胜利九十周年

一个 Web 端纪念专题。它的配色、布局、字体与节奏，**全部由一条随机生成的字母数字串推导而来**。

## 起因

设计种子由 shell 生成：

```bash
tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 300
```

输出 300 个字符：

```
POGuRg3nhYBgf4aCoeWyxQbkHqszVODNHfwKOtgB690HDLIdE2taHggVYsIRyxCcw6Amqt8bTX1h4yJQGlP3JY3EOrlsgtMfqDVuz59bdJuHgiTSCOZXCrYRp4LXOfrdaKxfKohbK57pwpAMFsyh6f4qtVAcTiCeJUVOrRPuyJONvAPwCNFpoESIsCVHSSyyG22f8NiHTwsL4CGTCXbg1Z5GfG5fNNXIv8IwJj4IdqkMmQ3J7d1dwPMw8DIYZjqDby8jDDX7opAkGcXyxelXauicNAtj0yJcTbnhbJYoMCx2
```

它长 **300**。而 2016 年 10 月 21 日，习近平总书记在纪念红军长征胜利 80 周年大会上说：

> 在红一方面军二万五千里的征途上，平均每 **300 米**就有一名红军牺牲。

这个数字不是设计者选的，是 `/dev/urandom` 给的。整个站点建立在这个巧合上。

## 从字符串推导出的设计语言

分析脚本见 [`seed.sh`](seed.sh)（模式挖掘）与 [`derive.sh`](derive.sh)（配色推导）。

| 种子里的事实 | 对应的设计决定 |
| --- | --- |
| 长度 = **300** | 全站叙事框架；左缘 300 格刻度尺，一格一米；滚动进度换算为"二万五千里" |
| 「90」全串只出现一次，藏在第 41 位起的 `690` 里 | 九十周年不做视觉呐喊——90 是**被找到的**，不是被喊出来的 |
| 第 193 位起出现 `22` | 1936 年 10 月 22 日将台堡会师，做成字符流里唯一的实底高亮 |
| 0–9、A–Z、a–z **62 个符号一个不缺** | 首页专设一节把 62 个符号全部点亮，与"8.6 万人出发、7000 人到达"构成对照 |
| 大写 134 : 小写 130，差 **4** | 主栅格写成 `grid-template-columns:134fr 130fr`；`--delta: 4` 用于留白与行距 |
| 36 位数字之和 = **164** | 色相 `(164×7) mod 34 + 354` = **20°** → 全站唯一的"红" `#B6592B`（锈血） |
| 数字锚点间隔众数 = **7** | 栅格步长取 7 的倍数 |
| 大写/小写的强弱交替节奏 | 重衬线（强拍）配等宽体（弱拍）的排版节拍 |

**配色拒绝正红加金的常规解**：真实的红会氧化成锈，九十年前的现场留下的是铁与血锈掉之后的颜色。底部另有一层 SVG 颗粒噪点（`feTurbulence`）提供档案质感。

## 站点结构

首页含 8 个导航栏：

| 序号 | 页面 | 内容 |
| --- | --- | --- |
| 01 | [`index.html`](index.html) | 首页 · 缘起、一个都不少、关键数字、行程、战役、人物、精神、九十 |
| 02 | [`march.html`](march.html) | 行程 · 从于都河到将台堡的完整时间线 |
| 03 | [`numbers.html`](numbers.html) | 数据 · 关键数字与 300 米尺度的可视化 |
| 04 | [`battles.html`](battles.html) | 战役 · 湘江、四渡赤水、泸定桥、腊子口 |
| 05 | [`figures.html`](figures.html) | 人物 · 决策者、战将，与没有留下名字的人 |
| 06 | [`spirit.html`](spirit.html) | 精神 · 《七律·长征》与当代理解 |
| 07 | [`ninety.html`](ninety.html) | 九十 · 会师地标与纪念日倒计时 |
| 08 | [`seed.html`](seed.html) | 种子 · 设计语言的完整推导过程（命令、分析、色板、栅格、节律） |

关键史实：二万五千里、368 天、600 余次重要战役战斗（中央红军 380 余次）、翻越 18 座大山、跨过 24 条大河、途经 11 省、出发 8.6 万余人、到达陕北约 7000 人、营以上干部牺牲 430 余人（平均年龄不到 30 岁）。

## 技术说明

- 纯静态：8 个 HTML + 1 个 CSS + 1 个 JS，**无构建步骤，无依赖，无外部图片**
- 视觉全部由 CSS 与内联 SVG 构成（山脊、路线图、颗粒噪点、色板）
- 中文字体走 Google Fonts（Noto Serif SC / Noto Sans SC），等宽用 JetBrains Mono，均配置了系统字体回退
- 交互：字符流逐字悬停显示里程与史实、`90` 滚动显影、行军进度条与里数读数
- 响应式：390 / 768 / 1440 / 1920 四档已验证，无横向溢出；移动端有汉堡菜单
- 遵循 `prefers-reduced-motion`

## 本地预览

```bash
python -m http.server 8788
# 打开 http://127.0.0.1:8788/index.html
```

## 在线访问

**https://chjiangtonghua.github.io/changzheng90/**

仓库：https://github.com/chjiangtonghua/changzheng90

## 部署到 GitHub Pages

本仓库提供两个部署脚本，按网络情况选用。

### 首选：`deploy-api.sh`（只依赖 api.github.com）

```bash
bash deploy-api.sh
```

完全不使用 `git push`，改为通过 GitHub REST API 直接写仓库（`blobs → tree → commit → ref`）。
适用于**按 SNI 阻断了 `github.com:443`** 的网络——这类网络下 `git push` 无论走 HTTPS 还是 SSH 都会失败，
但 `api.github.com:443` 通常仍然可达。

**幂等**：每次运行都在远端当前 HEAD 之上新建一个提交，可反复运行来更新站点。

可选排除大文件：`EXCLUDE="shots/" bash deploy-api.sh`

### 备选：`deploy.sh`（走 git push）

```bash
bash deploy.sh
```

自动挑选可用通道：`github.com:443` 可达则用 HTTPS，被阻断则改用 SSH 经 `ssh.github.com:443`。
凭据来源依次为：命令行参数 → `GH_TOKEN` → `gh auth login` 登录态 → 系统凭据管理器（Git Credential Manager）。

### 更新流程

改完源码后：

```bash
git add -A && git commit -m "更新说明"
bash deploy-api.sh
```

> 说明：`deploy-api.sh` 是在远端已有历史之上追加提交，因此**远端历史与本地 git 历史是各自独立的**。
> 这不影响站点内容（远端文件与本地完全一致）。若日后网络可稳定访问 `github.com`，想恢复常规
> `git push` 工作流，重新 clone 一份即可。

## 截图

`shots/` 目录下为本机渲染存档：首页首屏、整页长图、种子实验室、数据页、九十周年专题、移动端、战役页。

## 声明

本站为非商业纪念性设计作品。史实数据取自公开党史与主流媒体报道口径，若有疏漏欢迎指正。
