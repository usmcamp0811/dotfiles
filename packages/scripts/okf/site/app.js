// okf site: search and stale banners. No network, no fetch: the index is a
// script tag (assets/search-index.js), so everything works from file://.
(function () {
  "use strict";

  // "/" focuses the search box, like most documentation sites.
  document.addEventListener("keydown", function (event) {
    var tag = (event.target && event.target.tagName) || "";
    if (event.key === "/" && !/^(INPUT|TEXTAREA|SELECT)$/.test(tag) && !event.metaKey && !event.ctrlKey) {
      var box = document.querySelector("input[type=search]");
      if (box) { event.preventDefault(); box.focus(); box.select(); }
    }
  });

  // The left sidebar can be folded away on a wide screen; the choice is remembered.
  // On a narrow screen the tree already collapses (below), so the button stays hidden.
  var toggle = document.getElementById("navtoggle"), docnav = document.getElementById("docnav");
  if (toggle && docnav && docnav.firstElementChild) {
    var folded = false;
    try { folded = localStorage.getItem("okf-nav") === "hidden"; } catch (_) { /* file:// may forbid storage */ }
    var apply = function () {
      document.documentElement.classList.toggle("nav-hidden", folded);
      toggle.setAttribute("aria-expanded", folded ? "false" : "true");
    };
    toggle.hidden = false;
    apply();
    toggle.addEventListener("click", function () {
      folded = !folded; apply();
      try { localStorage.setItem("okf-nav", folded ? "hidden" : "shown"); } catch (_) { /* optional */ }
    });
  }

  // On a narrow screen the document tree starts closed so the page comes first.
  // Without JavaScript it simply stays open.
  var tree = document.querySelector(".navwrap");
  if (tree && window.matchMedia && window.matchMedia("(max-width: 62rem)").matches) {
    tree.removeAttribute("open");
  }

  // A page past its stale_after instant says so.
  var article = document.querySelector("[data-stale-after]");
  if (article) {
    var when = Date.parse(article.getAttribute("data-stale-after"));
    if (!isNaN(when) && when <= Date.now()) {
      var banner = document.createElement("p");
      banner.className = "stale";
      banner.textContent = "This page was marked stale after " + article.getAttribute("data-stale-after") +
        ". Check it before relying on it.";
      var heading = article.querySelector("h1");
      article.insertBefore(banner, heading ? heading.nextSibling : article.firstChild);
    }
  }

  // Mermaid is bundled by Nix when a site opts in. Render fences locally: no
  // CDN, fetch, or server is involved.
  if (window.mermaid) {
    var diagrams = document.querySelectorAll("pre > code.language-mermaid");
    if (diagrams.length) {
      window.mermaid.initialize({ startOnLoad: false, securityLevel: "strict", theme: "base" });
      diagrams.forEach(function (code, index) {
        var node = document.createElement("div");
        node.className = "mermaid";
        node.textContent = code.textContent;
        code.parentElement.replaceWith(node);
        window.mermaid.render("mermaid-" + index, node.textContent).then(function (result) {
          node.innerHTML = result.svg;
        }).catch(function (error) {
          node.classList.add("mermaid-error");
          node.textContent = "Mermaid could not render this diagram: " + (error && error.message ? error.message : error);
          console.error("Mermaid render failed", error);
        });
      });
    }
  }

  // Search -------------------------------------------------------------------
  var results = document.getElementById("results");
  if (!results || !window.OKF_INDEX) { return; }

  var field = document.getElementById("q");
  var params = new URLSearchParams(location.search);
  var query = params.get("q") || "";
  field.value = query;

  // type:Guide  tag:vault  bundle:modules  trust:unverified  "quoted phrase"  word
  function parse(text) {
    var filters = [], words = [];
    var pattern = /(\w+):"([^"]+)"|(\w+):(\S+)|"([^"]+)"|(\S+)/g, match;
    while ((match = pattern.exec(text)) !== null) {
      var key = match[1] || match[3], value = match[2] || match[4];
      if (key && /^(type|tag|bundle|trust)$/.test(key)) {
        filters.push([key, value.toLowerCase()]);
      } else {
        words.push((match[5] || match[6] || match[0]).toLowerCase());
      }
    }
    return { filters: filters, words: words };
  }

  function passes(doc, filters) {
    return filters.every(function (f) {
      var key = f[0], value = f[1];
      if (key === "type") { return doc.y.toLowerCase() === value; }
      if (key === "tag") { return doc.g.some(function (t) { return t.toLowerCase() === value; }); }
      if (key === "bundle") { return doc.b.toLowerCase() === value; }
      return doc.r === value;
    });
  }

  function score(doc, words) {
    var total = 0;
    for (var i = 0; i < words.length; i++) {
      var w = words[i], s = 0;
      if (doc.t.toLowerCase().indexOf(w) >= 0) { s += 10; }
      if (doc.g.join(" ").toLowerCase().indexOf(w) >= 0) { s += 6; }
      if (doc.d.toLowerCase().indexOf(w) >= 0) { s += 4; }
      if (doc.y.toLowerCase().indexOf(w) >= 0) { s += 3; }
      var text = doc.x.toLowerCase(), at = text.indexOf(w), hits = 0;
      while (at >= 0 && hits < 5) { hits++; at = text.indexOf(w, at + w.length); }
      s += hits;
      if (s === 0) { return 0; }
      total += s;
    }
    return total || 1;
  }

  function mark(parent, text, words) {
    var lower = text.toLowerCase(), at = 0;
    while (at < text.length) {
      var best = -1, bestWord = "";
      for (var i = 0; i < words.length; i++) {
        var found = lower.indexOf(words[i], at);
        if (found >= 0 && (best < 0 || found < best)) { best = found; bestWord = words[i]; }
      }
      if (best < 0) { parent.appendChild(document.createTextNode(text.slice(at))); return; }
      parent.appendChild(document.createTextNode(text.slice(at, best)));
      var m = document.createElement("mark");
      m.textContent = text.slice(best, best + bestWord.length);
      parent.appendChild(m);
      at = best + bestWord.length;
    }
  }

  function snippet(doc, words) {
    if (!words.length) { return ""; }
    var lower = doc.x.toLowerCase(), at = -1;
    for (var i = 0; i < words.length && at < 0; i++) { at = lower.indexOf(words[i]); }
    if (at < 0) { return ""; }
    var from = Math.max(0, at - 70), to = Math.min(doc.x.length, at + 130);
    return (from > 0 ? "\u2026" : "") + doc.x.slice(from, to) + (to < doc.x.length ? "\u2026" : "");
  }

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) { node.className = className; }
    if (text) { node.textContent = text; }
    return node;
  }

  var parsed = parse(query);
  if (!parsed.filters.length && !parsed.words.length) {
    results.appendChild(el("li", "empty", "Type a word or a filter such as type:Guide."));
    return;
  }

  var hits = [];
  window.OKF_INDEX.forEach(function (doc) {
    if (!passes(doc, parsed.filters)) { return; }
    var s = parsed.words.length ? score(doc, parsed.words) : 1;
    if (s > 0) { hits.push({ doc: doc, score: s }); }
  });
  hits.sort(function (a, b) { return b.score - a.score || a.doc.t.localeCompare(b.doc.t); });

  if (!hits.length) {
    results.appendChild(el("li", "empty", "Nothing matches \u201c" + query + "\u201d."));
    return;
  }
  hits.slice(0, 60).forEach(function (hit) {
    var doc = hit.doc, item = el("li");
    var link = el("a", "t");
    link.href = doc.u;
    mark(link, doc.t, parsed.words);
    item.appendChild(link);
    var trust = doc.r ? doc.r.replace("-", " ") : "";
    item.appendChild(el("div", "m", doc.y + " in " + doc.b + (trust ? ", " + trust : "")));
    if (doc.d) { var d = el("p", "d"); mark(d, doc.d, parsed.words); item.appendChild(d); }
    var snip = snippet(doc, parsed.words);
    if (snip) { var p = el("p", "snip"); mark(p, snip, parsed.words); item.appendChild(p); }
    results.appendChild(item);
  });
  if (hits.length > 60) {
    results.appendChild(el("li", "empty", hits.length - 60 + " more. Narrow the search with a filter."));
  }
})();
