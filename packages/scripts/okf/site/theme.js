// Theme selection is deliberately tiny and local. The selected theme travels on
// every internal link too: this is reliable for file://, where localStorage can
// be unavailable or isolated by browser profile.
(function () {
  "use strict";
  var root = document.documentElement;
  var themes = (root.getAttribute("data-themes") || "").split(" ");
  var query = new URLSearchParams(location.search).get("theme");
  var saved;
  try { saved = localStorage.getItem("okf-theme"); } catch (_) { /* file:// may forbid storage */ }
  var selected = themes.indexOf(query) >= 0 ? query : (themes.indexOf(saved) >= 0 ? saved : root.getAttribute("data-theme"));
  function isInternal(href) {
    return href && !/^\s*(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(href);
  }

  function withTheme(href, theme) {
    var hash = href.indexOf("#"), fragment = hash >= 0 ? href.slice(hash) : "";
    var path = hash >= 0 ? href.slice(0, hash) : href;
    var question = path.indexOf("?"), base = question >= 0 ? path.slice(0, question) : path;
    var params = new URLSearchParams(question >= 0 ? path.slice(question + 1) : "");
    params.set("theme", theme);
    return base + "?" + params.toString() + fragment;
  }

  function carryTheme(theme) {
    document.querySelectorAll("a[href]").forEach(function (link) {
      var href = link.getAttribute("href");
      if (isInternal(href)) { link.setAttribute("href", withTheme(href, theme)); }
    });
    document.querySelectorAll("form[action]").forEach(function (form) {
      var action = form.getAttribute("action");
      if (!isInternal(action)) { return; }
      var input = form.querySelector('input[name="theme"]');
      if (!input) {
        input = document.createElement("input");
        input.type = "hidden";
        input.name = "theme";
        form.appendChild(input);
      }
      input.value = theme;
    });
  }

  function setTheme(theme, remember) {
    root.setAttribute("data-theme", theme);
    carryTheme(theme);
    var current = new URL(location.href);
    current.searchParams.set("theme", theme);
    try { history.replaceState(null, "", current.href); } catch (_) { /* file:// may restrict history */ }
    if (remember) {
      try { localStorage.setItem("okf-theme", theme); } catch (_) { /* URL still preserves it */ }
    }
  }

  // The header button flips between a pair of themes (dark and light) when the current theme has one.
  var pairs = { "navy-mk2": "navy-mk2-light", "navy-mk2-light": "navy-mk2" };

  document.addEventListener("DOMContentLoaded", function () {
    setTheme(selected, false);
    var picker = document.getElementById("theme");
    var mode = document.getElementById("modetoggle");
    function syncMode() { if (mode) { mode.hidden = !pairs[root.getAttribute("data-theme")]; } }
    if (mode) {
      mode.addEventListener("click", function () {
        var next = pairs[root.getAttribute("data-theme")];
        if (!next) { return; }
        setTheme(next, true);
        if (picker) { picker.value = next; }
        syncMode();
      });
    }
    syncMode();
    if (!picker) { return; }
    picker.parentElement.hidden = false;
    picker.value = selected;
    picker.addEventListener("change", function () {
      setTheme(picker.value, true);
      syncMode();
    });
  });
})();
