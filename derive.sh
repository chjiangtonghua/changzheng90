#!/usr/bin/env bash
# 由 seed.txt 推导配色与栅格参数
LC_ALL=C
SEED=$(cat seed.txt)
D=$(printf '%s' "$SEED" | tr -dc '0-9')
nD=${#D}
nU=$(printf '%s' "$SEED" | tr -dc 'A-Z' | wc -c | tr -d ' ')
nL=$(printf '%s' "$SEED" | tr -dc 'a-z' | wc -c | tr -d ' ')
SUM=0; for ((i=0;i<${#D};i++)); do SUM=$(( SUM + ${D:i:1} )); done
# 强调色相：落在朱红-锈橙区
HUE=$(( (SUM * 7) % 34 + 354 )); [ $HUE -ge 360 ] && HUE=$((HUE-360))
# 琥珀色相：暖黄区，由 9 与 0 的出现次数（各2）与 4 的峰值（6）定位
HUE2=$(( 30 + (SUM % 12) ))
# 暗度：小写占比越高越暗
DARK=$(( nU %%  1 ))  # placeholder
DARK=$(awk -v u="$nU" -v l="$nL" 'BEGIN{printf "%d", 100 - (u*100/(u+l))}')
# 栅格：数字锚点间隔众数 7
echo "SEED_LEN   = $(printf '%s' "$SEED" | wc -c | tr -d ' ')"
echo "DIGITS     = $nD"
echo "UPPER      = $nU   LOWER = $nL   (delta = $((nU-nL)))"
echo "DIGIT_SUM  = $SUM"
echo "HUE_ACCENT = $HUE"
echo "HUE_WARM   = $HUE2"
echo
echo "---- CSS 变量（由种子推导）----"
cat <<CSS
:root{
  --ink:        #0A0C0B;              /* 墨底：$nU 大写 / $nL 小写 → 暗色主导 */
  --ink-2:      #111614;
  --steel:      #1C2320;
  --bone:       #E7E2D6;              /* 骨白：大小写近对半 → 中性亮 */
  --mono:       #6F7C75;
  --blood:      hsl($HUE 62% 44%);    /* 朱/锈：数字和 $SUM → 色相 $HUE */
  --ember:      hsl($HUE2 72% 52%);   /* 琥珀：9/0 稀有 → 极少量 */
  --rail:       #2A3330;
  --delta:      $((nU-nL));           /* 不对称偏移量 */
  --grid:       7;                    /* 锚点间隔众数 */
  --len:        300;                  /* 每300米一名牺牲 */
}
CSS
