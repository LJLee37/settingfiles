// settingfiles profiles/plasma/panels.js: 화면마다 하단 패널(2026-11-18 LJGaming 의 두 화면 패널을 옮김).
// plasma.sh 가 맨 앞에 var MODE = "check"; 또는 var MODE = "apply"; 를 붙여 plasmashell 의 evaluateScript 로 돌립니다.
// apply 는 하단 패널이 없는 화면에만 새로 만들고, 이미 있는 패널의 위젯은 바꾸지 않습니다(다르면 알리기만 함).
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
  var have = p.widgets().map(function (w) { return w.type; }).join(",");
  if (have == WIDGETS.join(",")) {
    out.push("ok: 화면 " + s + " 하단 패널");
  } else {
    out.push("todo: 화면 " + s + " 패널 위젯이 다름(" + have + ")");
  }
  allScreenTasks(p, s);
}
print(out.join("\n"));
