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

  var NODE_MAX = 240; // largest node dimension (px); the other axis scales by aspect

  // Pick the variant for a screen under the current device/theme selection, falling
  // back to the closest available so a node never goes blank.
  function variantFor(sc) {
    var vs = sc.variants || [];
    function pick(test) { for (var i = 0; i < vs.length; i++) if (test(vs[i])) return vs[i]; return null; }
    return pick(function (x) { return familyOf(x.device) === state.device && x.theme === state.theme; })
        || pick(function (x) { return familyOf(x.device) === state.device; })
        || pick(function (x) { return x.theme === state.theme; })
        || vs[0] || null;
  }

  // Node size that reflects the image's real aspect ratio, normalized so the larger
  // side is NODE_MAX (so a landscape iPad node is wide, a portrait iPhone node is tall).
  function sizeFor(v) {
    var w = (v && v.width) || 0, h = (v && v.height) || 0;
    if (!w || !h) return { w: 110, h: NODE_MAX };
    return h >= w
      ? { w: Math.round(NODE_MAX * w / h), h: NODE_MAX }
      : { w: NODE_MAX, h: Math.round(NODE_MAX * h / w) };
  }

  // Whether the screen actually has a variant for the selected device family (else the
  // node is a fallback and is dimmed to make that obvious).
  function hasFamily(sc) {
    return (sc.variants || []).some(function (x) { return familyOf(x.device) === state.device; });
  }

  function nodeDataFor(sc, dir) {
    var v = variantFor(sc);
    var size = sizeFor(v);
    return {
      img: nodeImg(v ? v.thumbnail : sc.thumbnail, dir),
      w: size.w, h: size.h,
      op: hasFamily(sc) ? 1 : 0.35
    };
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
      var nd = nodeDataFor(sc, dir);
      elements.push({ data: { id: sc.id, label: sc.title, img: nd.img, w: nd.w, h: nd.h, op: nd.op, screen: sc } });
    });
    feature.edges.forEach(function (e) {
      elements.push({ data: { source: e.from, target: e.to, label: e.label || "" } });
    });
    if (cy) cy.destroy();
    cy = cytoscape({
      container: document.getElementById("cy"),
      elements: elements,
      autoungrabify: true, boxSelectionEnabled: false, minZoom: 0.2, maxZoom: 3,
      style: [
        { selector: "node", style: {
            "background-image": "data(img)", "background-fit": "contain", "background-opacity": 0,
            "shape": "round-rectangle", "width": "data(w)", "height": "data(h)", "opacity": "data(op)",
            "border-width": 1, "border-color": "#e4e4e7",
            "label": "data(label)", "text-valign": "top", "text-halign": "center", "text-margin-y": -9,
            "font-size": 12, "font-weight": 600, "color": "#3f3f46" } },
        { selector: "node:selected", style: { "border-width": 2, "border-color": "#0d99ff", "color": "#0d99ff" } },
        { selector: "edge", style: {
            "curve-style": "bezier", "target-arrow-shape": "triangle", "arrow-scale": 1.1,
            "line-color": "#cfcfd6", "target-arrow-color": "#cfcfd6", "width": 1.5,
            "label": "data(label)", "font-size": 10, "font-weight": 500, "color": "#71717a",
            "text-background-color": "#ffffff", "text-background-opacity": 1,
            "text-background-padding": 4, "text-background-shape": "round-rectangle",
            "text-border-color": "#e6e6e9", "text-border-width": 1, "text-border-opacity": 1 } },
        { selector: "edge:selected", style: { "line-color": "#0d99ff", "target-arrow-color": "#0d99ff" } }
      ],
      layout: { name: "dagre", rankDir: "TB", nodeSep: 55, rankSep: 80 }
    });
    cy.on("tap", "node", function (evt) { openPanel(evt.target.data("screen"), dir); });
    cy.on("tap", function (evt) { if (evt.target === cy) { closePanel(); cy.elements().unselect(); } });
    buildZoombar();
  }

  // Re-skin every node for the current state and re-run the layout (node sizes change
  // with the device aspect ratio). Cytoscape re-renders the canvas from the new data.
  function reskin() {
    if (!cy) return;
    cy.nodes().forEach(function (n) {
      var nd = nodeDataFor(n.data("screen"), currentDir);
      n.data("img", nd.img); n.data("w", nd.w); n.data("h", nd.h); n.data("op", nd.op);
    });
    cy.layout({ name: "dagre", rankDir: "TB", nodeSep: 40, rankSep: 70 }).run();
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
    document.getElementById("ptitle").textContent = screen.title;
    document.getElementById("pdesc").textContent = screen.description || "";
    var html = "";
    (screen.callouts || []).forEach(function (c) {
      html += '<div class="callout"><strong>' + escapeHtml(c.type) + ":</strong> " + escapeHtml(c.content) + "</div>";
    });
    screen.variants.forEach(function (v) {
      html += '<div class="variant-label">' + escapeHtml(v.device + " · " + v.theme) + "</div>";
      html += '<img src="' + dir + "/" + v.image + '" alt="" />';
    });
    document.getElementById("panel-body").innerHTML = html;
    document.getElementById("panel").classList.add("open");
  }

  // Zoom control (bottom-left): − / % / + ; clicking the % fits to screen.
  function buildZoombar() {
    var z = document.getElementById("zoombar");
    z.innerHTML = "";
    function btn(txt, fn) { var b = document.createElement("button"); b.textContent = txt; b.onclick = fn; return b; }
    function zoomBy(f) {
      cy.zoom({ level: Math.min(cy.maxZoom(), Math.max(cy.minZoom(), cy.zoom() * f)),
                renderedPosition: { x: cy.width() / 2, y: cy.height() / 2 } });
    }
    var pct = document.createElement("span"); pct.id = "zoompct"; pct.title = "Fit to screen";
    pct.onclick = function () { cy.fit(undefined, 48); };
    z.appendChild(btn("−", function () { zoomBy(0.8); }));
    z.appendChild(pct);
    z.appendChild(btn("+", function () { zoomBy(1.25); }));
    function upd() { pct.textContent = Math.round(cy.zoom() * 100) + "%"; }
    cy.on("zoom", upd); upd();
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
