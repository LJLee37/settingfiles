// settingfiles profiles/plasma/panels.js: 화면마다 하단 패널(2026-11-18 LJGaming 의 두 화면 패널을 옮김).
// plasma.sh 가 맨 앞에 var MODE = "check"; 또는 var MODE = "apply"; 또는 var MODE = "old"; 를 붙여 plasmashell 의 evaluateScript 로 돌립니다.
// apply 는 하단 패널이 없는 화면에는 새로 만들고, 이미 있는 패널에는 빠진 위젯만 넣은 뒤 순서(AppletOrder)를 맞춥니다
// (2026-11-19, LJTF 의 기본 패널에 입력기 패널이 없었음). 사용자가 더 넣은 위젯은 지우지 않고 맨 뒤에 그대로 둡니다.
// 순서는 p.widgets() 가 아니라 위젯의 index 로 봅니다. p.widgets() 는 만든 순서(id 순)로 돌려줘서, 나중에 넣은 위젯은
// 제자리에 있어도 맨 뒤로 보입니다.
// 작업 표시줄은 아이콘과 창 제목을 보이는 작업 관리자(taskmanager)입니다(2026-11-20, LJGaming 사용자 요청). 아이콘 전용인지는
// 설정이 아니라 위젯 플러그인 이름으로 정해집니다(plasma-desktop 6.8.3 applets/taskmanager/qml/main.qml 의 iconsOnly). 그래서 옛
// 아이콘 전용 작업 표시줄(icontasks)은 같은 자리의 위젯으로 보고 따로 더 넣지 않습니다. MODE "old" 는 그 위젯들을
// "<패널 id> <위젯 id>" 줄로 찍고, plasma.sh 가 plasmashell 을 멈춘 뒤 plugin 키만 바꿉니다(고정 앱과 순서가 그대로 남음).
// 출력 한 줄마다 "ok: ", "did: ", "todo: " 로 시작합니다(MODE "old" 는 빼고).
var TASKS = "org.kde.plasma.taskmanager", ICONTASKS = "org.kde.plasma.icontasks";
var WIDGETS = [
  "org.kde.plasma.kickoff",           // 앱 메뉴
  "org.kde.plasma.pager",             // 가상 데스크톱
  TASKS,                              // 작업 표시줄(아이콘과 창 제목, 모든 화면의 창, 켠 앱은 고정 아이콘 자리에)
  "org.kde.plasma.marginsseparator",
  "org.kde.plasma.kimpanel",          // 입력기(IBus) 후보 창과 상태
  "org.kde.plasma.systemtray",
  "org.kde.plasma.digitalclock",
  "org.kde.plasma.showdesktop"
];
// 작업 표시줄 [General] 의 값: 키, 바라는 값, 값이 없을 때의 기본값(applets/taskmanager/main.xml), todo 문구, did 문구.
// separateLaunchers=false 는 수동 정렬(sortingStrategy 1)일 때만 듣고, 그러면 켠 앱이 첫 고정 아이콘 자리에 들어갑니다
// (libtaskmanager/tasksmodel.h, main.qml). 끌어 옮긴 순서는 고정 앱 목록(launchers)에 저장됩니다.
var TASK_SETTINGS = [
  ["showOnlyCurrentScreen", false, false, "현재 화면의 창만 보여 줌", "모든 화면의 창을 보여 줌"],
  ["sortingStrategy", 1, 1, "수동 정렬이 아님", "수동 정렬"],
  ["separateLaunchers", false, true, "고정 앱을 따로 모음", "켠 앱을 고정 아이콘 자리에 둠"]
];
var out = [];
function kind(w) { return w.type == ICONTASKS ? TASKS : w.type; }  // 옛 아이콘 전용은 작업 표시줄 자리로 셈
function bottomPanels(s) { return panels().filter(function (p) { return p.screen == s && p.location == "bottom"; }); }
function taskSettings(p, s) {
  p.widgets(TASKS).forEach(function (w) {
    w.currentConfigGroup = ["General"];
    var changed = false;
    TASK_SETTINGS.forEach(function (t) {
      if (String(w.readConfig(t[0], t[2])) == String(t[1])) return;
      if (MODE == "apply") {
        w.writeConfig(t[0], t[1]);
        changed = true;
        out.push("did: 화면 " + s + " 작업 표시줄이 " + t[4]);
      } else {
        out.push("todo: 화면 " + s + " 작업 표시줄이 " + t[3]);
      }
    });
    if (changed) w.reloadConfig();
  });
  if (p.widgets(ICONTASKS).length) {
    out.push("todo: 화면 " + s + " 작업 표시줄이 아이콘 전용(icontasks). plasma.sh 가 plasmashell 을 멈추고 작업 관리자로 바꿈");
  }
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
      if (kind(ws[i]) == t && !used[ws[i].id]) { used[ws[i].id] = true; ids.push(ws[i].id); return; }
    }
  });
  ws.forEach(function (w) { if (!used[w.id]) ids.push(w.id); });
  return ids;
}
if (MODE == "old") {
  for (var s = 0; s < screenCount; s++) {
    bottomPanels(s).forEach(function (p) {
      p.widgets(ICONTASKS).forEach(function (w) { out.push(p.id + " " + w.id); });
    });
  }
} else {
  for (var s = 0; s < screenCount; s++) {
    var mine = bottomPanels(s);
    if (mine.length == 0) {
      if (MODE == "apply") {
        var np = new Panel("org.kde.panel");
        np.screen = s;
        np.location = "bottom";
        WIDGETS.forEach(function (w) { np.addWidget(w); });
        taskSettings(np, s);
        out.push("did: 화면 " + s + " 하단 패널을 만듦");
      } else {
        out.push("todo: 화면 " + s + " 에 하단 패널이 없음");
      }
      continue;
    }
    var p = mine[0];
    var types = ordered(p).map(kind);
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
    taskSettings(p, s);
  }
}
print(out.join("\n"));
