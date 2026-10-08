/* ==========================================================================
   《三百》— 交互脚本
   字符串即设计语言：所有视觉效果都能追溯到 seed 的某个特征
   ========================================================================== */
(function () {
  'use strict';

  /* —— 设计种子：由 seed.sh 生成，共 300 字符 ——
     300 恰好对应"长征途中平均每 300 米就有一名红军牺牲" */
  var SEED =
    'POGuRg3nhYBgf4aCoeWyxQbkHqszVODNHfwKOtgB690HDLIdE2taHggVYsIRyxCcw6Amqt8bTX1h4yJQGlP3JY3EOrlsgtMfqDVuz59bdJuHgiTSCOZXCrYRp4LXOfrdaKxfKohbK57pwpAMFsyh6f4qtVAcTiCeJUVOrRPuyJONvAPwCNFpoESIsCVHSSyyG22f8NiHTwsL4CGTCXbg1Z5GfG5fNNXIv8IwJj4IdqkMmQ3J7d1dwPMw8DIYZjqDby8jDDX7opAkGcXyxelXauicNAtj0yJcTbnhbJYoMCx2';

  /* 种子里藏着的两处关键：
     「690」第 41 位起 —— 全串唯一出现的 "90"，也就是九十周年本身
     「22」 第 194 位起 —— 1936 年 10 月 22 日，将台堡会师 */
  var I690 = SEED.indexOf('690');   // 40（0 基）→ '9' 在 41、'0' 在 42
  var I22  = SEED.indexOf('22');    // 193（0 基）

  function kind(ch) {
    if (ch >= '0' && ch <= '9') return 'dg';
    if (ch >= 'A' && ch <= 'Z') return 'up';
    return 'lo';
  }

  /* ---------------------------------------------------------------
     1. 字符流渲染：把种子铺成 span，数字染锈红，大写显骨白
     --------------------------------------------------------------- */
  function renderStreams() {
    document.querySelectorAll('[data-seed-stream]').forEach(function (host) {
      var frag = document.createDocumentFragment();
      for (var i = 0; i < SEED.length; i++) {
        var s = document.createElement('span');
        s.className = 'c ' + kind(SEED[i]);
        s.textContent = SEED[i];
        s.dataset.i = i;
        if (i === I690 + 1 || i === I690 + 2) s.classList.add('glow');   // 9 0
        if (i === I22 || i === I22 + 1) s.classList.add('hit');          // 2 2
        frag.appendChild(s);
      }
      host.appendChild(frag);
    });

    document.querySelectorAll('[data-rail-strip]').forEach(function (host) {
      var times = parseInt(host.dataset.railStrip, 10) || 1;
      var frag = document.createDocumentFragment();
      for (var t = 0; t < times; t++) {
        for (var i = 0; i < SEED.length; i++) {
          var s = document.createElement('span');
          s.className = 'c ' + kind(SEED[i]);
          s.textContent = SEED[i];
          frag.appendChild(s);
        }
      }
      host.appendChild(frag);
    });
  }

  /* ---------------------------------------------------------------
     2. 三百格刻度尺：种子长度 = 300，一格即一米
     --------------------------------------------------------------- */
  function renderTickRail() {
    document.querySelectorAll('[data-tick-rail]').forEach(function (host) {
      var frag = document.createDocumentFragment();
      for (var i = 0; i < SEED.length; i++) {
        var t = document.createElement('i');
        if (kind(SEED[i]) === 'dg') t.className = 'dg';
        frag.appendChild(t);
      }
      host.appendChild(frag);
    });
  }

  /* ---------------------------------------------------------------
     3. 字符表：0-9 A-Z a-z 全在这串里，一个都不少
     --------------------------------------------------------------- */
  function renderCharset() {
    document.querySelectorAll('[data-charset]').forEach(function (host) {
      var pool = '0123456789'.split('')
        .concat('ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''))
        .concat('abcdefghijklmnopqrstuvwxyz'.split(''));
      var frag = document.createDocumentFragment();
      pool.forEach(function (c, n) {
        var s = document.createElement('span');
        s.textContent = c;
        if (SEED.indexOf(c) !== -1) s.classList.add('lit');
        s.style.transitionDelay = (n * 12) + 'ms';
        frag.appendChild(s);
      });
      host.appendChild(frag);
    });
  }

  /* ---------------------------------------------------------------
     4. 滚动显现
        用位置扫描而非 IntersectionObserver：直接跳转滚动时
        （锚点、Home/End、拖动滚动条）也不会漏掉中间的元素
     --------------------------------------------------------------- */
  function reveal() {
    var items = Array.prototype.slice.call(document.querySelectorAll('.rv,.tl-item'));

    function sweep() {
      var vh = window.innerHeight || 800;
      for (var i = items.length - 1; i >= 0; i--) {
        var el = items[i];
        // 只要已进入或已越过视口（top 在视口下沿之上），就显现——
        // 这样跳转滚动、快速拖动也不会留下永不出现的空白
        if (el.getBoundingClientRect().top < vh * 0.96) {
          el.classList.add('in');
          items.splice(i, 1);
        }
      }
    }

    var ticking = false;
    function onScroll() {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(function () { sweep(); ticking = false; });
    }
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    sweep();
    // 字体/图片载入后布局会变，补扫两次
    setTimeout(sweep, 300);
    window.addEventListener('load', sweep);

    // "90" 显影：进入视口后点亮
    var nine = document.querySelector('.ninety');
    if (nine) {
      var nio = new IntersectionObserver(function (es) {
        es.forEach(function (e) { if (e.isIntersecting) nine.classList.add('lit'); });
      }, { threshold: 0.35 });
      nio.observe(nine);
    }

    // 字符流：进入视口后数字开始呼吸
    document.querySelectorAll('.seed-stream').forEach(function (st) {
      var sio = new IntersectionObserver(function (es) {
        es.forEach(function (e) { if (e.isIntersecting) e.target.classList.add('seen'); });
      }, { threshold: 0.15 });
      sio.observe(st);
    });
  }

  /* ---------------------------------------------------------------
     5. 行军进度：滚动 = 推进，二万五千里
     --------------------------------------------------------------- */
  function march() {
    var bar = document.querySelector('.march-bar');
    var ro = document.querySelector('.march-readout');
    var LI = 25000;
    function upd() {
      var h = document.documentElement.scrollHeight - window.innerHeight;
      var p = h > 0 ? Math.min(1, Math.max(0, window.scrollY / h)) : 0;
      if (bar) bar.style.transform = 'scaleX(' + p + ')';
      if (ro) {
        var li = Math.round(LI * p).toLocaleString('en-US');
        ro.innerHTML = '行程 <b>' + li + '</b> 里 / 25,000 里<br>种子 <b>' +
          String(Math.round(300 * p)).padStart(3, '0') + '</b> / 300';
      }
    }
    window.addEventListener('scroll', upd, { passive: true });
    window.addEventListener('resize', upd);
    upd();
  }

  /* ---------------------------------------------------------------
     6. 导航：移动端展开 / 当前页高亮 / 下滚收起
     --------------------------------------------------------------- */
  function nav() {
    var tb = document.querySelector('.topbar');
    var tg = document.querySelector('.nav-toggle');
    var nv = document.querySelector('.nav');
    if (tg && nv) {
      tg.addEventListener('click', function () { nv.classList.toggle('open'); });
      nv.addEventListener('click', function (e) {
        if (e.target.tagName === 'A') nv.classList.remove('open');
      });
    }
    var here = (location.pathname.split('/').pop() || 'index.html').toLowerCase();
    document.querySelectorAll('.nav a').forEach(function (a) {
      var href = (a.getAttribute('href') || '').toLowerCase();
      if (href === here || (here === '' && href === 'index.html')) a.classList.add('on');
    });
    if (!tb) return;
    var last = 0;
    window.addEventListener('scroll', function () {
      var y = window.scrollY;
      if (y > 260 && y > last) tb.classList.add('hide');
      else tb.classList.remove('hide');
      last = y;
    }, { passive: true });
  }

  /* ---------------------------------------------------------------
     7. 悬停字符 → 显示它在种子中的坐标（每一步都是一米）
     --------------------------------------------------------------- */
  var FACTS = {
    '0': '出发点：江西瑞金、于都',
    '1': '1935 年 1 月遵义会议，伟大转折',
    '2': '二万五千里，红一方面军长征里程',
    '3': '中央红军自 1934 年 10 月出发，历时 368 天',
    '4': '营以上干部牺牲 430 余人，平均年龄不到 30 岁',
    '5': '1935 年 5 月，巧渡金沙江、飞夺泸定桥',
    '6': '长征途中发生 600 余次重要战役战斗',
    '7': '到达陕北时仅剩约 7000 人',
    '8': '中央红军出发时 8.6 万余人',
    '9': '1936 年 10 月，三大主力会师，长征胜利'
  };

  function coordHint() {
    var tip = document.createElement('div');
    tip.className = 'coord-tip';
    document.body.appendChild(tip);
    var cur = null;

    document.addEventListener('mouseover', function (e) {
      var c = e.target.closest ? e.target.closest('.seed-stream .c') : null;
      if (!c) return;
      cur = c;
      var i = Number(c.dataset.i) + 1;
      var txt = '#' + String(i).padStart(3, '0') + ' · 第 ' + i + ' 米';
      if (c.classList.contains('dg')) txt += '\n' + (FACTS[c.textContent] || '长征路上的一个数字');
      tip.textContent = txt;
      tip.style.maxWidth = '270px';
      tip.classList.add('on');
    });
    document.addEventListener('mousemove', function (e) {
      if (!tip.classList.contains('on')) return;
      tip.style.left = Math.min(e.clientX + 14, window.innerWidth - 290) + 'px';
      tip.style.top = (e.clientY - 34) + 'px';
    });
    document.addEventListener('mouseout', function (e) {
      if (cur && e.target === cur) { tip.classList.remove('on'); cur = null; }
    });
  }

  /* ---------------------------------------------------------------
     8. 九十周年天数
     --------------------------------------------------------------- */
  function anniversary() {
    var hosts = document.querySelectorAll('[data-anniv]');
    if (!hosts.length) return;
    var target = new Date('2026-10-22T00:00:00');
    var now = new Date();
    var days = Math.round((now - new Date('1936-10-22T00:00:00')) / 86400000);
    var toGo = Math.ceil((target - now) / 86400000);
    hosts.forEach(function (h) {
      var d = h.querySelector('[data-anniv-days]');
      if (d) d.textContent = days.toLocaleString('en-US');
      var g = h.querySelector('[data-anniv-togo]');
      if (g) g.textContent = toGo > 0 ? (toGo + ' 天后迎来九十周年纪念日 · 2026.10.22') : '纪念日已至 · 2026.10.22';
    });
  }

  function boot() {
    renderStreams();
    renderTickRail();
    renderCharset();
    reveal();
    march();
    nav();
    coordHint();
    anniversary();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
