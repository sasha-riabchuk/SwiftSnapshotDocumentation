/* Flow Explorer renderer. Reads window.FLOW_MANIFEST and window.FLOW_DATA. */
(function () {
  var cy = null;
  var currentDir = null;
  var state = { device: null, theme: null }; // selected device family + theme

  function familyOf(d) {
    return d.indexOf("iPad") >= 0 ? "iPad" : (d.indexOf("iPhone") >= 0 ? "iPhone" : d);
  }

  // Resolve a value to a node-usable image src: embedded data: URIs (and http) are used
  // directly; anything else is treated as a path relative to the feature directory.
  function nodeImg(t, dir) {
    t = t || "";
    return (t.indexOf("data:") === 0 || t.indexOf("http") === 0) ? t : (dir + "/" + t);
  }

  // Pick the thumbnail for a screen under the current device/theme selection, falling
  // back to the closest available variant so a node never goes blank.
  function thumbFor(sc) {
    var vs = sc.variants || [];
    function pick(test) { for (var i = 0; i < vs.length; i++) if (test(vs[i])) return vs[i]; return null; }
    var v = pick(function (x) { return familyOf(x.device) === state.device && x.theme === state.theme; })
         || pick(function (x) { return familyOf(x.device) === state.device; })
         || pick(function (x) { return x.theme === state.theme; })
         || vs[0];
    return v ? v.thumbnail : sc.thumbnail;
  }

  function loadFeature(entry) {
    var existing = window.FLOW_DATA && window.FLOW_DATA[entry.name];
    if (existing) return render(existing, entry.dir);
    var s = document.createElement("script");
    s.src = entry.dir + "/flows.js";
    s.onload = function () { render(window.FLOW_DATA[entry.name], entry.dir); };
    document.body.appendChild(s);
  }

  function render(feature, dir) {
    closePanel();
    currentDir = dir;
    buildToolbar(feature); // sets state defaults before nodes are built

    var elements = [];
    feature.screens.forEach(function (sc) {
      elements.push({ data: { id: sc.id, label: sc.title, img: nodeImg(thumbFor(sc), dir), screen: sc } });
    });
    feature.edges.forEach(function (e) {
      elements.push({ data: { source: e.from, target: e.to, label: e.label || "" } });
    });
    if (cy) cy.destroy();
    cy = cytoscape({
      container: document.getElementById("cy"),
      elements: elements,
      style: [
        { selector: "node", style: {
            "background-image": "data(img)", "background-fit": "contain", "background-opacity": 0,
            "shape": "round-rectangle", "width": 120, "height": 240, "border-width": 1,
            "border-color": "#ddd", "label": "data(label)", "text-valign": "bottom",
            "text-margin-y": 6, "font-size": 12 } },
        { selector: "edge", style: {
            "curve-style": "bezier", "target-arrow-shape": "triangle",
            "line-color": "#bbb", "target-arrow-color": "#bbb", "width": 2,
            "label": "data(label)", "font-size": 10, "color": "#666",
            "text-background-color": "#fff", "text-background-opacity": 1 } }
      ],
      layout: { name: "dagre", rankDir: "TB", nodeSep: 40, rankSep: 70 }
    });
    cy.on("tap", "node", function (evt) { openPanel(evt.target.data("screen"), dir); });
  }

  // Re-skin every node for the current state — Cytoscape re-renders the canvas because
  // the node style binds background-image to data(img).
  function reskin() {
    if (!cy) return;
    cy.nodes().forEach(function (n) { n.data("img", nodeImg(thumbFor(n.data("screen")), currentDir)); });
  }

  // MARK: toolbar

  function labelTheme(t) { return t === "light" ? "Light" : (t === "dark" ? "Dark" : t); }

  function segGroup(title, values, labelFn, current, onPick) {
    var g = document.createElement("div"); g.className = "group";
    var l = document.createElement("span"); l.className = "glabel"; l.textContent = title; g.appendChild(l);
    var seg = document.createElement("div"); seg.className = "seg";
    values.forEach(function (val) {
      var b = document.createElement("button");
      b.textContent = labelFn(val);
      if (val === current) b.className = "on";
      b.onclick = function () {
        Array.prototype.forEach.call(seg.children, function (c) { c.className = ""; });
        b.className = "on";
        onPick(val);
      };
      seg.appendChild(b);
    });
    g.appendChild(seg);
    return g;
  }

  function buildToolbar(feature) {
    var devSet = {}, themeSet = {};
    feature.screens.forEach(function (sc) {
      (sc.variants || []).forEach(function (v) { devSet[familyOf(v.device)] = 1; themeSet[v.theme] = 1; });
    });
    var families = Object.keys(devSet);
    var themes = Object.keys(themeSet).sort(function (a, b) {
      return (a === "light" ? 0 : 1) - (b === "light" ? 0 : 1); // Light before Dark
    });
    if (families.indexOf(state.device) < 0) state.device = families[0] || null;
    if (themes.indexOf(state.theme) < 0) state.theme = themes[0] || null;

    var tb = document.getElementById("toolbar");
    tb.innerHTML = "";
    if (families.length > 1) {
      tb.appendChild(segGroup("Device", families, function (f) { return f; }, state.device,
        function (val) { state.device = val; reskin(); }));
    }
    if (themes.length > 1) {
      tb.appendChild(segGroup("Appearance", themes, labelTheme, state.theme,
        function (val) { state.theme = val; reskin(); }));
    }
  }

  // MARK: variants panel

  function openPanel(screen, dir) {
    var body = document.getElementById("panel-body");
    var html = "<h2>" + escapeHtml(screen.title) + "</h2><p>" + escapeHtml(screen.description) + "</p>";
    (screen.callouts || []).forEach(function (c) {
      html += "<p><strong>" + escapeHtml(c.type) + ":</strong> " + escapeHtml(c.content) + "</p>";
    });
    screen.variants.forEach(function (v) {
      html += '<div class="variant-label">' + escapeHtml(v.device + " · " + v.theme) + "</div>";
      html += '<img src="' + dir + "/" + v.image + '" alt="" />';
    });
    body.innerHTML = html;
    document.getElementById("panel").classList.add("open");
  }

  window.closePanel = function () { document.getElementById("panel").classList.remove("open"); };

  function escapeHtml(s) {
    return String(s).replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  }

  function init() {
    var manifest = window.FLOW_MANIFEST || { features: [] };
    var list = document.getElementById("features");
    manifest.features.forEach(function (entry, i) {
      var li = document.createElement("li");
      li.textContent = entry.name;
      li.onclick = function () {
        Array.prototype.forEach.call(list.children, function (n) { n.classList.remove("active"); });
        li.classList.add("active");
        loadFeature(entry);
      };
      list.appendChild(li);
      if (i === 0) li.click();
    });
  }
  init();
})();
