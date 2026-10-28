// okf site: the knowledge graph. A small canvas force layout with no dependencies and no
// network: the data is a script tag (assets/graph-data.js), so it works from file:// too.
//
// Nodes are documents, edges are the Markdown links between them. Two views share one engine:
//   - the global graph on graph.html (#graph), and
//   - a compact local graph beside each document (.localgraph).
// Everything here is progressive: if it fails, the pages and their text links still work.
(function () {
  "use strict";
  var DATA = window.OKF_GRAPH;
  var root = document.documentElement;
  var reduce = !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  var FALLBACK = ["#7fa05a", "#c9a66b", "#6fa3bd", "#b86a6a", "#9b82b8", "#58a898", "#c0b25a", "#c27fa0", "#8f9a8a", "#d08a52"];

  function css(name, fallback) {
    var value = getComputedStyle(root).getPropertyValue(name).trim();
    return value || fallback;
  }

  function readColors() {
    var palette = [];
    for (var i = 0; i < FALLBACK.length; i++) { palette.push(css("--g" + (i + 1), FALLBACK[i])); }
    return {
      palette: palette, paper: css("--paper", "#101410"), ink: css("--ink", "#e2e5d9"), soft: css("--soft", "#a2aa9b"),
      link: css("--graph-link", css("--rule", "#374333")), accent: css("--accent", "#a9bd78"),
      signal: css("--signal", "#c0504d"), mark: css("--human", "#a58a64"), mono: css("--mono", "monospace")
    };
  }

  // Build node objects and an undirected adjacency from {nodes, edges} (edges are index pairs).
  function build(data) {
    var nodes = data.nodes.map(function (raw, i) {
      var angle = i * 2.39996, radius = 10 * Math.sqrt(i + 1);
      return {
        i: i, raw: raw, url: raw.u, title: raw.t, type: raw.y, bundle: raw.b, tags: raw.g || [],
        x: radius * Math.cos(angle), y: radius * Math.sin(angle), vx: 0, vy: 0, fx: null, fy: null,
        nset: new Set(), r: 4, vis: true, ring: 0
      };
    });
    var seen = {}, links = [];
    data.edges.forEach(function (e) {
      var a = nodes[e[0]], b = nodes[e[1]];
      if (!a || !b || a === b) { return; }
      var key = Math.min(e[0], e[1]) + ":" + Math.max(e[0], e[1]);
      if (seen[key]) { return; }
      seen[key] = true;
      a.nset.add(b); b.nset.add(a);
      links.push({ a: a, b: b });
    });
    nodes.forEach(function (n) { n.deg = n.nset.size; n.r = 3.5 + Math.sqrt(n.deg) * 1.7; });
    return { nodes: nodes, links: links };
  }

  function themed(url) {
    var theme = root.getAttribute("data-theme");
    return url + (theme ? "?theme=" + encodeURIComponent(theme) : "");
  }

  function createGraph(canvas, model, opt) {
    var ctx = canvas.getContext("2d");
    if (!ctx) { throw new Error("canvas is not available"); }
    var nodes = model.nodes, links = model.links;
    var view = { x: 0, y: 0, k: 1 }, W = 0, H = 0, dpr = 1;
    var live = nodes.slice(), liveLinks = links, alpha = 0, frame = 0, ready = false;
    var hover = null, selected = null, matches = null, colors = readColors();
    var typeColor = {};
    var linkDist = opt.compact ? 36 : 54, repulsion = opt.compact ? 700 : 1500, cell = opt.compact ? 70 : 110;
    var hubDegree = 3;

    function assignColors() {
      var counts = {};
      nodes.forEach(function (n) { counts[n.type] = (counts[n.type] || 0) + 1; });
      var types = Object.keys(counts).sort(function (a, b) { return counts[b] - counts[a] || (a < b ? -1 : 1); });
      types.forEach(function (t, i) { typeColor[t] = i; });
      var degrees = nodes.map(function (n) { return n.deg; }).sort(function (a, b) { return b - a; });
      hubDegree = Math.max(3, degrees[Math.floor(nodes.length * 0.08)] || 3);
      return { types: types, counts: counts };
    }
    var typeInfo = assignColors();
    function colorOf(n) { return colors.palette[typeColor[n.type] % colors.palette.length]; }

    // layout ------------------------------------------------------------------
    function tick() {
      var i, j, a, b, dx, dy, d2, d, f, bucket, cx, cy, ox, oy;
      var grid = new Map();
      for (i = 0; i < live.length; i++) {
        a = live[i];
        var key = (Math.floor(a.x / cell) + 4096) * 8192 + (Math.floor(a.y / cell) + 4096);
        bucket = grid.get(key);
        if (bucket) { bucket.push(a); } else { grid.set(key, [a]); }
      }
      for (i = 0; i < live.length; i++) {
        a = live[i];
        cx = Math.floor(a.x / cell) + 4096; cy = Math.floor(a.y / cell) + 4096;
        for (ox = -1; ox <= 1; ox++) {
          for (oy = -1; oy <= 1; oy++) {
            bucket = grid.get((cx + ox) * 8192 + (cy + oy));
            if (!bucket) { continue; }
            for (j = 0; j < bucket.length; j++) {
              b = bucket[j];
              if (a === b) { continue; }
              dx = a.x - b.x; dy = a.y - b.y; d2 = dx * dx + dy * dy;
              if (d2 > cell * cell) { continue; }
              if (d2 < 1) { dx = (a.i - b.i) * 0.01 + 0.01; dy = 0.01; d2 = dx * dx + dy * dy; }
              d = Math.sqrt(d2);
              f = repulsion / (d2 + 100) * alpha;
              a.vx += dx / d * f; a.vy += dy / d * f;
            }
          }
        }
      }
      for (i = 0; i < liveLinks.length; i++) {
        a = liveLinks[i].a; b = liveLinks[i].b;
        dx = b.x - a.x; dy = b.y - a.y; d = Math.sqrt(dx * dx + dy * dy) || 1;
        f = (d - linkDist) / d * 0.09 * alpha;
        a.vx += dx * f; a.vy += dy * f; b.vx -= dx * f; b.vy -= dy * f;
      }
      for (i = 0; i < live.length; i++) {
        a = live[i];
        a.vx -= a.x * 0.012 * alpha; a.vy -= a.y * 0.012 * alpha;
        if (a.fx !== null) { a.x = a.fx; a.y = a.fy; a.vx = a.vy = 0; continue; }
        a.vx *= 0.55; a.vy *= 0.55; a.x += a.vx; a.y += a.vy;
      }
      alpha *= 0.985;
    }

    // Run the layout to rest in one go: fast, and what reduced-motion users get.
    function settle(ticks, level) {
      alpha = level || 1;
      for (var t = 0; t < ticks && alpha > 0.02; t++) { tick(); }
      alpha = 0;
    }
    function heat(level, ticks) {
      if (reduce) { settle(ticks, level); schedule(); return; }
      alpha = Math.max(alpha, level); schedule();
    }

    // drawing -----------------------------------------------------------------
    function active() {
      var focus = hover || selected;
      if (focus) { var s = new Set(focus.nset); s.add(focus); return s; }
      return matches;
    }
    function screenX(n) { return n.x * view.k + view.x; }
    function screenY(n) { return n.y * view.k + view.y; }

    function wantLabel(n, set) {
      if (n === hover || n === selected) { return true; }
      if (opt.center === n || opt.labelAll) { return true; }
      if (set && set.has(n)) { return set.size <= 40; }
      return view.k >= 1.6 || (n.deg >= hubDegree && view.k >= 0.7);
    }

    function draw() {
      var i, n, set = active(), focus = hover || selected;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, W, H);
      ctx.setTransform(dpr * view.k, 0, 0, dpr * view.k, dpr * view.x, dpr * view.y);
      ctx.lineCap = "round";
      ctx.lineWidth = 1 / view.k;
      ctx.strokeStyle = colors.link;
      ctx.globalAlpha = set ? 0.15 : 0.7;
      ctx.beginPath();
      for (i = 0; i < liveLinks.length; i++) {
        ctx.moveTo(liveLinks[i].a.x, liveLinks[i].a.y); ctx.lineTo(liveLinks[i].b.x, liveLinks[i].b.y);
      }
      ctx.stroke();
      if (focus) {
        ctx.globalAlpha = 1; ctx.strokeStyle = colors.accent; ctx.lineWidth = 1.7 / view.k;
        ctx.beginPath();
        for (i = 0; i < liveLinks.length; i++) {
          if (liveLinks[i].a === focus || liveLinks[i].b === focus) {
            ctx.moveTo(liveLinks[i].a.x, liveLinks[i].a.y); ctx.lineTo(liveLinks[i].b.x, liveLinks[i].b.y);
          }
        }
        ctx.stroke();
      }
      for (i = 0; i < live.length; i++) {
        n = live[i];
        ctx.globalAlpha = set && !set.has(n) ? 0.2 : (n.ring === 2 ? 0.65 : 1);
        ctx.beginPath(); ctx.arc(n.x, n.y, n.r, 0, 6.2832);
        ctx.fillStyle = colorOf(n); ctx.fill();
        if (n === selected || n === opt.center) {
          ctx.lineWidth = 2 / view.k; ctx.strokeStyle = colors.signal; ctx.globalAlpha = 1;
          ctx.beginPath(); ctx.arc(n.x, n.y, n.r + 2.5 / view.k, 0, 6.2832); ctx.stroke();
        } else if (matches && matches.has(n)) {
          ctx.lineWidth = 1.5 / view.k; ctx.strokeStyle = colors.mark; ctx.globalAlpha = 1;
          ctx.beginPath(); ctx.arc(n.x, n.y, n.r + 2 / view.k, 0, 6.2832); ctx.stroke();
        }
      }
      // Labels are drawn in screen pixels so they stay legible at any zoom.
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.globalAlpha = 1;
      ctx.font = (opt.compact ? 10 : 11) + "px " + colors.mono;
      ctx.textAlign = "center"; ctx.textBaseline = "top";
      ctx.lineJoin = "round"; ctx.lineWidth = 3; ctx.strokeStyle = colors.paper;
      for (i = 0; i < live.length; i++) {
        n = live[i];
        var sx = screenX(n), sy = screenY(n);
        if (sx < -50 || sy < -20 || sx > W + 50 || sy > H + 20 || !wantLabel(n, set)) { continue; }
        var text = n.title.length > 32 ? n.title.slice(0, 31) + "\u2026" : n.title;
        var ty = sy + n.r * view.k + 3;
        ctx.strokeText(text, sx, ty);
        ctx.fillStyle = set && !set.has(n) ? colors.soft : colors.ink;
        ctx.fillText(text, sx, ty);
      }
    }

    function step() {
      frame = 0;
      if (alpha > 0.02) { tick(); tick(); } else { alpha = 0; }
      draw();
      if (alpha > 0) { schedule(); }
    }
    function schedule() { if (!frame) { frame = requestAnimationFrame(step); } }

    // view --------------------------------------------------------------------
    function fit() {
      if (!live.length || !W) { return; }
      var minx = Infinity, miny = Infinity, maxx = -Infinity, maxy = -Infinity, i, n;
      for (i = 0; i < live.length; i++) {
        n = live[i];
        minx = Math.min(minx, n.x - n.r); maxx = Math.max(maxx, n.x + n.r);
        miny = Math.min(miny, n.y - n.r); maxy = Math.max(maxy, n.y + n.r);
      }
      var pad = opt.compact ? 34 : 48;
      var k = Math.min((W - 2 * pad) / Math.max(maxx - minx, 1), (H - 2 * pad) / Math.max(maxy - miny, 1));
      view.k = Math.max(0.1, Math.min(k, opt.compact ? 1.8 : 2.2));
      view.x = W / 2 - (minx + maxx) / 2 * view.k;
      view.y = H / 2 - (miny + maxy) / 2 * view.k;
      schedule();
    }
    function centerOn(n) {
      view.k = Math.max(view.k, 1.3);
      view.x = W / 2 - n.x * view.k; view.y = H / 2 - n.y * view.k;
      schedule();
    }
    function zoomAt(px, py, factor) {
      var k = Math.max(0.08, Math.min(view.k * factor, 8));
      view.x = px - (px - view.x) * (k / view.k); view.y = py - (py - view.y) * (k / view.k); view.k = k;
      schedule();
    }
    function resize() {
      var rect = canvas.getBoundingClientRect();
      dpr = window.devicePixelRatio || 1;
      var first = !ready && rect.width > 0;
      W = rect.width; H = rect.height;
      canvas.width = Math.max(1, Math.round(W * dpr)); canvas.height = Math.max(1, Math.round(H * dpr));
      if (first) { ready = true; fit(); if (opt.onReady) { setTimeout(opt.onReady, 0); } }
      schedule();
    }

    // pointer -----------------------------------------------------------------
    function local(e) { var r = canvas.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top }; }
    function nodeAt(p) {
      var best = null, bestD = Infinity, i, n, dx, dy, d, reach;
      for (i = 0; i < live.length; i++) {
        n = live[i]; dx = screenX(n) - p.x; dy = screenY(n) - p.y; d = Math.sqrt(dx * dx + dy * dy);
        reach = Math.max(n.r * view.k, 7) + 3;
        if (d <= reach && d < bestD) { best = n; bestD = d; }
      }
      return best;
    }
    function setHover(n, p) {
      if (hover === n) { if (n && p) { placeTip(p); } return; }
      hover = n;
      canvas.style.cursor = n ? "pointer" : "";
      if (opt.tip) {
        if (n) { fillTip(n); placeTip(p); } else { opt.tip.hidden = true; }
      }
      schedule();
    }
    function fillTip(n) {
      var tip = opt.tip;
      tip.textContent = "";
      var title = document.createElement("strong"); title.textContent = n.title;
      var meta = document.createElement("span");
      meta.textContent = n.type + " \u00b7 " + n.bundle + " \u00b7 " + n.deg + (n.deg === 1 ? " link" : " links");
      tip.appendChild(title); tip.appendChild(meta); tip.hidden = false;
    }
    function placeTip(p) {
      var tip = opt.tip, host = tip.offsetParent || canvas.parentNode;
      var left = p.x + 14, top = p.y + 14;
      var offset = canvas.offsetLeft, offsetTop = canvas.offsetTop;
      if (left + tip.offsetWidth > host.clientWidth) { left = Math.max(4, p.x - tip.offsetWidth - 10); }
      if (top + tip.offsetHeight > host.clientHeight) { top = Math.max(4, p.y - tip.offsetHeight - 10); }
      tip.style.left = (offset + left) + "px"; tip.style.top = (offsetTop + top) + "px";
    }

    var pointers = new Map(), moved = false, downNode = null, dragging = null, last = null, pinch = null;
    canvas.addEventListener("pointerdown", function (e) {
      if (e.pointerType === "mouse" && e.button !== 0) { return; }
      var p = local(e);
      try { canvas.setPointerCapture(e.pointerId); } catch (_) { /* not fatal */ }
      pointers.set(e.pointerId, p);
      if (pointers.size === 2) {
        var pts = Array.from(pointers.values());
        pinch = { d: Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y) || 1 };
        moved = true; dragging = null; return;
      }
      moved = false; last = p; downNode = nodeAt(p); dragging = downNode;
      if (dragging) { setHover(null); }
    });
    canvas.addEventListener("pointermove", function (e) {
      var p = local(e);
      if (!pointers.has(e.pointerId)) {
        if (e.pointerType === "mouse") { setHover(nodeAt(p), p); }
        return;
      }
      pointers.set(e.pointerId, p);
      if (pinch && pointers.size === 2) {
        var pts = Array.from(pointers.values()), d = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y) || 1;
        zoomAt((pts[0].x + pts[1].x) / 2, (pts[0].y + pts[1].y) / 2, d / pinch.d);
        pinch.d = d; return;
      }
      if (Math.hypot(p.x - last.x, p.y - last.y) > 4 || moved) {
        moved = true;
        if (dragging) {
          dragging.fx = dragging.x = (p.x - view.x) / view.k; dragging.fy = dragging.y = (p.y - view.y) / view.k;
          if (!reduce) { heat(0.3, 0); } else { schedule(); }
        } else {
          view.x += p.x - last.x; view.y += p.y - last.y; schedule();
        }
        last = p;
      }
    });
    function release(e) {
      if (!pointers.has(e.pointerId)) { return; }
      pointers.delete(e.pointerId);
      if (pointers.size < 2) { pinch = null; }
      if (pointers.size > 0) { return; }
      if (dragging) { dragging.fx = dragging.fy = null; if (moved) { heat(0.2, 60); } }
      if (!moved && e.type === "pointerup") {
        if (downNode) { opt.onActivate(downNode, e); } else if (opt.onBackground) { opt.onBackground(); }
      }
      dragging = null; downNode = null;
    }
    canvas.addEventListener("pointerup", release);
    canvas.addEventListener("pointercancel", release);
    canvas.addEventListener("pointerleave", function (e) { if (e.pointerType === "mouse" && !pointers.size) { setHover(null); } });
    if (!opt.compact) {
      canvas.addEventListener("wheel", function (e) {
        e.preventDefault();
        var p = local(e);
        zoomAt(p.x, p.y, Math.exp(-e.deltaY * (e.deltaMode ? 0.05 : 0.0015)));
      }, { passive: false });
    }
    canvas.addEventListener("keydown", function (e) {
      var step = 48, handled = true;
      if (e.key === "+" || e.key === "=") { zoomAt(W / 2, H / 2, 1.25); }
      else if (e.key === "-") { zoomAt(W / 2, H / 2, 0.8); }
      else if (e.key === "0") { fit(); }
      else if (e.key === "ArrowLeft") { view.x += step; schedule(); }
      else if (e.key === "ArrowRight") { view.x -= step; schedule(); }
      else if (e.key === "ArrowUp") { view.y += step; schedule(); }
      else if (e.key === "ArrowDown") { view.y -= step; schedule(); }
      else if (e.key === "Escape" && opt.onBackground) { opt.onBackground(); }
      else { handled = false; }
      if (handled) { e.preventDefault(); }
    });

    if (window.ResizeObserver) { new ResizeObserver(resize).observe(canvas); } else { window.addEventListener("resize", resize); }
    new MutationObserver(function () { colors = readColors(); schedule(); }).observe(root, { attributes: true, attributeFilter: ["data-theme"] });

    settle(nodes.length > 1500 ? 100 : 300);
    resize();

    return {
      nodes: nodes, types: typeInfo.types, typeCounts: typeInfo.counts,
      colorOf: colorOf, fit: fit, centerOn: centerOn, redraw: schedule,
      pos: function (n) { return { x: screenX(n), y: screenY(n) }; }, // canvas pixels; used by tests
      select: function (n) { selected = n; schedule(); },
      setMatches: function (set) { matches = set; schedule(); },
      setVisible: function (pred) {
        nodes.forEach(function (n) { n.vis = pred(n); });
        live = nodes.filter(function (n) { return n.vis; });
        liveLinks = links.filter(function (l) { return l.a.vis && l.b.vis; });
        if (hover && !hover.vis) { hover = null; }
        if (selected && !selected.vis) { selected = null; }
        settle(140, 0.6); fit(); // a filter change is instant, never animated
      },
      liveCount: function () { return live.length; },
      liveLinkCount: function () { return liveLinks.length; }
    };
  }

  function navigate(n) {
    var base = (document.querySelector(".localgraph") || document.getElementById("graph") || document.body).getAttribute("data-up") || "";
    location.href = base + themed(n.url);
  }

  function el(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) { node.className = cls; }
    if (text !== undefined) { node.textContent = text; }
    return node;
  }

  // Local graph: this document, its neighbours, and a few second-degree nodes. ---------
  function initLocal() {
    var box = document.querySelector(".localgraph");
    if (!box) { return; }
    var canvas = box.querySelector("canvas"), status = box.querySelector(".graph-status");
    try {
      var all = build(DATA), center = all.nodes[parseInt(box.getAttribute("data-node"), 10)];
      if (!center || center.nset.size === 0) { canvas.hidden = true; return; }
      var first = Array.from(center.nset).sort(function (a, b) { return a.i - b.i; });
      var inFirst = new Set(first), second = [], seen = new Set([center]);
      first.forEach(function (n) { seen.add(n); });
      first.forEach(function (n) {
        n.nset.forEach(function (m) { if (!seen.has(m)) { seen.add(m); second.push(m); } });
      });
      second.sort(function (a, b) { return b.deg - a.deg || a.i - b.i; });
      var picks = [center].concat(first, second.slice(0, 24));
      var index = new Map(); picks.forEach(function (n, i) { index.set(n, i); });
      var edges = [];
      all.links.forEach(function (l) { if (index.has(l.a) && index.has(l.b)) { edges.push([index.get(l.a), index.get(l.b)]); } });
      var model = build({ nodes: picks.map(function (n) { return n.raw; }), edges: edges });
      model.nodes.forEach(function (n, i) {
        n.ring = i === 0 ? 0 : (i <= first.length ? 1 : 2);
        var ring = n.ring, count = ring === 1 ? first.length : Math.min(second.length, 24), at = ring === 1 ? i - 1 : i - 1 - first.length;
        if (ring) { n.x = (ring * 38) * Math.cos(at / count * 6.2832); n.y = (ring * 38) * Math.sin(at / count * 6.2832); }
        else { n.x = n.y = 0; }
      });
      var tip = el("div", "graph-tip"); tip.hidden = true; box.appendChild(tip);
      createGraph(canvas, model, {
        // Only the current document is labelled; hover names the rest. Neighbours often share a title
        // (a module and its options page), so labelling them all would overprint in a panel this small.
        compact: true, center: model.nodes[0], tip: tip,
        onActivate: function (n) { if (n !== model.nodes[0]) { navigate(n); } }
      });
      status.textContent = first.length + " direct" + (second.length ? ", " + Math.min(second.length, 24) + " second-degree" : "") + ".";
    } catch (err) {
      canvas.hidden = true; status.textContent = "The graph could not start; the link lists below still work.";
      if (window.console) { console.error("local graph failed", err); }
    }
  }

  // Global graph. -------------------------------------------------------------------
  function initGlobal() {
    var canvas = document.getElementById("graph");
    if (!canvas) { return; }
    var status = document.getElementById("g-status"), stage = document.getElementById("graph-stage");
    try {
      var model = build(DATA), g, selectedNode = null, isolated = false, hidden = {};
      var search = document.getElementById("g-q"), bundleSel = document.getElementById("g-bundle"),
        tagSel = document.getElementById("g-tag"), orphans = document.getElementById("g-orphans"),
        legend = document.getElementById("g-legend"), card = document.getElementById("g-card"),
        tip = document.getElementById("g-tip");
      document.getElementById("graph-tools").setAttribute("data-ready", "true");

      function hood(n) {
        var set = new Set([n]);
        n.nset.forEach(function (m) { set.add(m); m.nset.forEach(function (o) { set.add(o); }); });
        return set;
      }
      function refresh() {
        var scope = isolated && selectedNode ? hood(selectedNode) : null;
        g.setVisible(function (n) {
          return !hidden[n.type] && (!bundleSel.value || n.bundle === bundleSel.value) &&
            (!tagSel.value || n.tags.indexOf(tagSel.value) >= 0) && (orphans.checked || n.deg > 0) && (!scope || scope.has(n));
        });
        status.textContent = g.liveCount() + " of " + model.nodes.length + " documents, " + g.liveLinkCount() + " links shown.";
      }
      function showCard(n) {
        card.textContent = "";
        if (!n) { card.hidden = true; return; }
        var head = el("a", "t", n.title); head.href = themed(n.url);
        card.appendChild(head);
        card.appendChild(el("p", "m", n.type + " \u00b7 " + n.bundle + " \u00b7 " + n.deg + (n.deg === 1 ? " link" : " links")));
        if (n.tags.length) { card.appendChild(el("p", "m", "tags: " + n.tags.join(", "))); }
        var near = Array.from(n.nset).sort(function (a, b) { return a.title < b.title ? -1 : 1; });
        if (near.length) {
          var list = el("ul");
          near.slice(0, 8).forEach(function (m) {
            var li = el("li"), a = el("a", "", m.title); a.href = themed(m.url); li.appendChild(a); list.appendChild(li);
          });
          if (near.length > 8) { list.appendChild(el("li", "m", "and " + (near.length - 8) + " more")); }
          card.appendChild(list);
          var label = el("label"), box = document.createElement("input");
          box.type = "checkbox"; box.checked = isolated;
          box.addEventListener("change", function () { isolated = box.checked; refresh(); g.centerOn(n); });
          label.appendChild(box); label.appendChild(document.createTextNode(" Show only this neighbourhood"));
          card.appendChild(label);
        }
        var close = el("button", "x", "Close"); close.type = "button";
        close.addEventListener("click", function () { choose(null); });
        card.appendChild(close);
        card.hidden = false;
      }
      function choose(n) {
        var wasIsolated = isolated;
        if (n !== selectedNode) { isolated = false; }
        selectedNode = n; g.select(n); showCard(n);
        if (wasIsolated && !isolated) { refresh(); } // leaving a neighbourhood restores the full view
      }

      g = createGraph(canvas, model, {
        tip: tip,
        onActivate: function (n, e) {
          // A mouse click opens the document. Touch (no hover) selects first, then a second tap opens it.
          if (e.shiftKey || (e.pointerType === "touch" && selectedNode !== n)) { choose(n); } else { navigate(n); }
        },
        onBackground: function () { choose(null); },
        onReady: function () {
          var focus = new URLSearchParams(location.search).get("focus");
          if (!focus) { return; }
          var match = model.nodes.filter(function (n) { return decodeURIComponent(n.url) === focus; })[0];
          if (match) { choose(match); g.centerOn(match); } else { status.textContent = "No graph node for " + focus + "."; }
        }
      });

      // Legend: one toggle per document type, coloured as in the graph.
      g.types.forEach(function (type) {
        var button = el("button", "legend-item"); button.type = "button"; button.setAttribute("aria-pressed", "true");
        var swatch = el("span", "swatch"); swatch.style.background = g.colorOf({ type: type });
        button.appendChild(swatch); button.appendChild(document.createTextNode(type + " (" + g.typeCounts[type] + ")"));
        button.addEventListener("click", function () {
          hidden[type] = !hidden[type]; button.setAttribute("aria-pressed", hidden[type] ? "false" : "true"); refresh();
        });
        legend.appendChild(button);
      });

      search.addEventListener("input", function () {
        var q = search.value.trim().toLowerCase();
        if (!q) { g.setMatches(null); return; }
        var set = new Set(model.nodes.filter(function (n) {
          return (n.title + " " + n.type + " " + n.tags.join(" ")).toLowerCase().indexOf(q) >= 0;
        }));
        g.setMatches(set.size ? set : null);
        status.textContent = set.size + " match" + (set.size === 1 ? "" : "es") + " for \u201c" + search.value.trim() + "\u201d. Press Enter to select the first.";
        search.setAttribute("data-matches", set.size);
      });
      search.addEventListener("keydown", function (e) {
        if (e.key !== "Enter") { return; }
        e.preventDefault();
        var q = search.value.trim().toLowerCase();
        var hit = q && model.nodes.filter(function (n) { return n.vis && (n.title + " " + n.type + " " + n.tags.join(" ")).toLowerCase().indexOf(q) >= 0; })[0];
        if (hit) { choose(hit); g.centerOn(hit); }
      });
      [bundleSel, tagSel, orphans].forEach(function (c) { c.addEventListener("change", refresh); });
      document.getElementById("g-reset").addEventListener("click", function () {
        search.value = ""; bundleSel.value = ""; tagSel.value = ""; orphans.checked = true; hidden = {}; isolated = false;
        legend.querySelectorAll("button").forEach(function (b) { b.setAttribute("aria-pressed", "true"); });
        g.setMatches(null); choose(null); refresh();
      });
      var full = document.getElementById("g-full");
      if (full && stage.requestFullscreen) {
        full.hidden = false;
        full.addEventListener("click", function () {
          if (document.fullscreenElement) { document.exitFullscreen(); } else { stage.requestFullscreen(); }
        });
      }
      status.textContent = g.liveCount() + " documents, " + g.liveLinkCount() + " links.";
      window.OKF_GRAPH_VIEW = g; // for tests and debugging
    } catch (err) {
      canvas.hidden = true;
      status.textContent = "The graph could not start; the document list below still works.";
      if (window.console) { console.error("graph failed", err); }
    }
  }

  function start() {
    if (!DATA) {
      var note = document.getElementById("g-status") || document.querySelector(".localgraph .graph-status");
      if (note) { note.textContent = "Graph data is unavailable; use the document list instead."; }
      return;
    }
    initLocal();
    initGlobal();
  }
  if (document.readyState === "loading") { document.addEventListener("DOMContentLoaded", start); } else { start(); }
})();
