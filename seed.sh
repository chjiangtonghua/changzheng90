#!/usr/bin/env bash
# ------------------------------------------------------------------
#  长征胜利 90 周年 · 网页设计种子
#  用 shell 生成一条长随机字母数字串，并挖掘其中的"隐藏模式"
#  字符串即设计语言：色彩 / 布局 / 字体 / 节奏 全部由它推导
# ------------------------------------------------------------------
LC_ALL=C

SEED=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 300)
printf '%s\n' "$SEED" > changzheng90/seed.txt

hr() { printf '%s\n' "-------------------------------------------------------"; }

echo "===== 设计种子 SEED ====="; echo "$SEED"; echo

echo "===== 体量统计 ====="
printf '全长        : %s\n' "$(printf '%s' "$SEED" | wc -c)"
printf '数字        : %s\n' "$(printf '%s' "$SEED" | tr -dc '0-9' | wc -c)"
printf '字母        : %s\n' "$(printf '%s' "$SEED" | tr -dc 'A-Za-z' | wc -c)"
printf '大写        : %s\n' "$(printf '%s' "$SEED" | tr -dc 'A-Z' | wc -c)"
printf '小写        : %s\n' "$(printf '%s' "$SEED" | tr -dc 'a-z' | wc -c)"
hr

echo "===== 数字频次（色彩层级 / 明度步长） ====="
printf '%s' "$SEED" | tr -dc '0-9' | fold -w1 | sort | uniq -c | sort -k2,2n

echo "===== 字母频次 TOP 12（字体权重分配） ====="
printf '%s' "$SEED" | tr -dc 'A-Za-z' | fold -w1 | sort | uniq -c | sort -rn | head -12

echo "===== 连续数字（隐藏数字） ====="
printf '%s' "$SEED" | grep -o '[0-9]\{2,\}' | sort | uniq -c | sort -rn

echo "===== 关键子串命中（与长征史实对照） ====="
for p in 90 25 1934 1935 1936 70 22 10 18 24 14 11 37 380; do
  n=$(printf '%s' "$SEED" | grep -o "$p" | wc -l)
  printf '  %-6s -> %s\n' "$p" "$n"
done

echo "===== 大小写/数字 边界节奏（布局分栏依据） ====="
printf '%s' "$SEED" | fold -w1 | awk '
  {c=$0; t=(c ~ /[0-9]/)?"D":((c ~ /[A-Z]/)?"U":"L");
   if (t!=p) { printf "%s", (p==""?"":"|"); printf "%s", t } p=t }
  END { print "" }'

echo "===== 数字锚点位置（节拍 / 栅格落点） ====="
printf '%s' "$SEED" | fold -w1 | awk '{ if ($0 ~ /[0-9]/) printf "%d:%s ", NR, $0 } END { print "" }'

echo "===== 字符集覆盖 ====="
printf '缺数字: '; for d in 0 1 2 3 4 5 6 7 8 9; do
  printf '%s' "$SEED" | grep -q "$d" || printf '%s ' "$d"; done; echo
printf '缺大写: '; for c in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z; do
  printf '%s' "$SEED" | grep -q "$c" || printf '%s ' "$c"; done; echo
printf '缺小写: '; for c in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
  printf '%s' "$SEED" | grep -q "$c" || printf '%s ' "$c"; done; echo
hr
echo "种子已写入 changzheng90/seed.txt"
