/* Flow Explorer renderer. Reads window.FLOW_MANIFEST and window.FLOW_DATA. */
(function () {
  var cy = null;

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
    var elements = [];
    feature.screens.forEach(function (sc) {
      elements.push({ data: { id: sc.id, label: sc.title, img: dir + "/" + sc.thumbnail, screen: sc, dir: dir } });
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
