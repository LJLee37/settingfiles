// settingfiles profiles/plasma/panels.js: 화면마다 하단 패널(2026-11-18 LJGaming 의 두 화면 패널을 옮김).
// plasma.sh 가 맨 앞에 var MODE = "check"; 또는 var MODE = "apply"; 를 붙여 plasmashell 의 evaluateScript 로 돌립니다.
// apply 는 하단 패널이 없는 화면에는 새로 만들고, 이미 있는 패널에는 빠진 위젯만 넣은 뒤 순서(AppletOrder)를 맞춥니다
// (2026-11-19, LJTF 의 기본 패널에 입력기 패널이 없었음). 사용자가 더 넣은 위젯은 지우지 않고 맨 뒤에 그대로 둡니다.
// 순서는 p.widgets() 가 아니라 위젯의 index 로 봅니다. p.widgets() 는 만든 순서(id 순)로 돌려줘서, 나중에 넣은 위젯은
// 제자리에 있어도 맨 뒤로 보입니다.
// 출력 한 줄마다 "ok: ", "did: ", "todo: " 로 시작합니다.
var WIDGETS = [
  "org.kde.plasma.kickoff",           // 앱 메뉴
  "org.kde.plasma.pager",             // 가상 데스크톱
  "org.kde.plasma.icontasks",         // 작업 표시줄(모든 화면의 창)
  "org.kde.plasma.marginsseparator",
  "org.kde.plasma.kimpanel",          // 입력기(IBus) 후보 창과 상태
  "org.kde.plasma.systemtray",
  "org.kde.plasma.digitalclock",
  "org.kde.plasma.showdesktop"
];
var out = [];
function allScreenTasks(p, s) {  // 작업 표시줄이 그 화면 것만이 아니라 모든 화면의 창을 보여 줌
  p.widgets("org.kde.plasma.icontasks").forEach(function (w) {
    w.currentConfigGroup = ["General"];
    var v = w.readConfig("showOnlyCurrentScreen", false);
    if (v === false || v === "false") return;
    if (MODE == "apply") {
      w.writeConfig("showOnlyCurrentScreen", false);
      out.push("did: 화면 " + s + " 작업 표시줄이 모든 화면의 창을 보여 줌");
    } else {
      out.push("todo: 화면 " + s + " 작업 표시줄이 현재 화면의 창만 보여 줌");
    }
  });
}
function ordered(p) {  // 화면에 보이는 순서. index 가 아직 없는(-1) 위젯은 맨 뒤
  return p.widgets().slice().sort(function (a, b) {
    var x = a.index < 0 ? 1e9 : a.index, y = b.index < 0 ? 1e9 : b.index;
    return x - y || a.id - b.id;
  });
}
function wantOrder(ws) {  // WIDGETS 순서로 각 종류의 첫 위젯, 그 뒤에 나머지(더 넣은 위젯)를 지금 순서대로
  var used = {}, ids = [];
  WIDGETS.forEach(function (t) {
    for (var i = 0; i < ws.length; i++) {
      if (ws[i].type == t && !used[ws[i].id]) { used[ws[i].id] = true; ids.push(ws[i].id); return; }
    }
  });
  ws.forEach(function (w) { if (!used[w.id]) ids.push(w.id); });
  return ids;
}
for (var s = 0; s < screenCount; s++) {
  var mine = panels().filter(function (p) { return p.screen == s && p.location == "bottom"; });
  if (mine.length == 0) {
    if (MODE == "apply") {
      var np = new Panel("org.kde.panel");
      np.screen = s;
      np.location = "bottom";
      WIDGETS.forEach(function (w) { np.addWidget(w); });
      allScreenTasks(np, s);
      out.push("did: 화면 " + s + " 하단 패널을 만듦");
    } else {
      out.push("todo: 화면 " + s + " 에 하단 패널이 없음");
    }
    continue;
  }
  var p = mine[0];
  var types = ordered(p).map(function (w) { return w.type; });
  var missing = WIDGETS.filter(function (t) { return types.indexOf(t) < 0; });
  var extra = types.filter(function (t) { return WIDGETS.indexOf(t) < 0; });
  var known = types.filter(function (t) { return WIDGETS.indexOf(t) >= 0; });
  var inOrder = missing.length == 0 && known.join(",") == WIDGETS.join(",");
  if (inOrder) {
    out.push("ok: 화면 " + s + " 하단 패널" + (extra.length ? "(더 넣은 위젯 그대로: " + extra.join(",") + ")" : ""));
  } else if (MODE == "apply") {
    missing.forEach(function (t) { p.addWidget(t); });
    var ids = wantOrder(ordered(p));
    p.currentConfigGroup = ["General"];
    p.writeConfig("AppletOrder", ids.join(";"));
    p.reloadConfig();
    out.push("did: 화면 " + s + " 패널 위젯" + (missing.length ? "을 넣고(" + missing.join(",") + ") " : "의 ") + "순서를 맞춤");
  } else {
    out.push("todo: 화면 " + s + " 패널 위젯이 다름" + (missing.length ? "(빠짐: " + missing.join(",") + ")" : "(순서: " + types.join(",") + ")"));
  }
  allScreenTasks(p, s);
}
print(out.join("\n"));
