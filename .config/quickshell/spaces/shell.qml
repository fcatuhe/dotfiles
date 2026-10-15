import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "SpacesModel.js" as Model

ShellRoot {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/spaces"
  readonly property string stateDir: home + "/.local/state/spaces"
  readonly property string captureScript: localPath("capture-windows")
  readonly property var refreshEvents: ["openwindow", "closewindow", "movewindowv2", "windowtitlev2", "activewindowv2", "workspacev2", "focusedmon", "changefloatingmode"]
  readonly property var globalBindings: [["CTRL + ALT + LEFT", "previous-space"], ["CTRL + ALT + RIGHT", "next-space"], ["SUPER + L", "toggle-layout"]]
  readonly property var tabBindings: [["ALT + UP", "previous-tab"], ["ALT + DOWN", "next-tab"]]
  readonly property var browserBindings: [["CTRL + T", "new-tab"], ["CTRL + L", "edit-url"]]

  property var config: ({ spaces: [] })
  property string configError: ""
  property var runtime: ({})
  property bool runtimeLoaded: false
  property var clients: []
  property bool clientsLoaded: false
  property string activeAddress: ""
  property string activeLayout: ""
  property var launches: ({})
  property var pending: []
  property var claims: ({})
  property var jobs: ({})
  property int nextJob: 1
  property int nextTabId: 1
  property string pushedHidden: "unset"
  property real lastClosedAt: 0
  property bool refreshQueued: false

  readonly property int focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property var focusedSpace: Model.activeSpace(config, focusedWorkspace)
  readonly property bool inSpace: focusedSpace !== null
  readonly property bool browserKeys: Model.browserKeys(config, focusedWorkspace, clients, activeAddress, launches)

  onInSpaceChanged: applyTabBindings()
  onBrowserKeysChanged: applyTabBindings()
  onFocusedWorkspaceChanged: if (Model.activeSpace(config, focusedWorkspace)) pushHidden(true)

  function localPath(name) {
    return decodeURIComponent(Qt.resolvedUrl(name).toString().replace(/^file:\/\//, ""))
  }

  function spaceFor(workspace) {
    return Model.activeSpace(config, workspace)
  }

  function tabsFor(space) {
    return space ? Model.tabs(space, runtime, clients, activeAddress, launches) : []
  }

  function openTab(space, tab) {
    selectTab(space.workspace, tab.id, "")
    var pin = space.tabs.find(function (candidate) { return candidate.id === tab.id })
    if (!tab.open && pin && pin.panes.length > 0) startJob(pin.panes, space.workspace, tab.id)
  }

  function newTab(input) {
    var pane = Model.paneForInput(input, home)
    if (!pane || !focusedSpace) return
    var id = "tab-" + Date.now().toString(36) + "-" + nextTabId++
    selectTab(focusedSpace.workspace, id, "")
    startJob([pane], focusedSpace.workspace, id)
  }

  function openPrompt(mode) {
    if (!focusedSpace) return
    var pane = mode === "edit-url" ? Model.activeWebPane(clients, activeAddress, launches) : null
    prompt.screen = Quickshell.screens.find(function (screen) { return Hyprland.focusedMonitor && screen.name === Hyprland.focusedMonitor.name }) || prompt.screen
    prompt.open(mode, pane ? pane.url : "", pane ? pane.address : "")
  }

  function submitPrompt(mode, input, target) {
    if (mode === "new-tab") newTab(input)
    else if (target !== "") replacePane(target, input)
    else openInCurrentTab(input)
  }

  function replacePane(address, input) {
    var pane = Model.paneForInput(input, home)
    var owner = Model.tabOfWindow(runtime, address)
    if (!pane || !owner) return
    startJob([pane], owner.workspace, owner.id, address)
  }

  function openInCurrentTab(input) {
    var pane = Model.paneForInput(input, home)
    if (!pane || !focusedSpace) return
    var current = (runtime[focusedSpace.workspace] || {}).current
    if (current) startJob([pane], focusedSpace.workspace, current)
    else newTab(input)
  }

  function closeTab(tab) {
    tab.panes.forEach(function (pane) { if (pane.open) closeWindow(pane.address) })
  }

  function togglePin(space, tab) {
    if (tab.pinned) saveConfig(Model.unpinTab(config, space.workspace, tab.id))
    else if (tab.open) capture(space.workspace, tab)
  }

  function capture(workspace, tab) {
    captureProc.request = { workspace: workspace, tab: tab }
    captureProc.command = [captureScript].concat(tab.panes.map(function (pane) { return pane.address }))
    captureProc.running = true
  }

  function stepTab(step) {
    if (!focusedSpace) return
    var tab = Model.adjacentTab(tabsFor(focusedSpace), step)
    if (tab) openTab(focusedSpace, tab)
  }

  function stepSpace(step) {
    var space = Model.adjacentSpace(config, focusedWorkspace, step)
    if (space) focusWorkspace(space.workspace)
  }

  function toggleLayout() {
    if (focusedSpace) {
      saveConfig(Model.setSpace(config, focusedWorkspace, { on: false }))
      Quickshell.execDetached(["omarchy-hyprland-workspace-layout-toggle"])
    } else if (activeLayout === "scrolling" && focusedWorkspace >= 1 && focusedWorkspace <= 10) {
      saveConfig(Model.setSpace(config, focusedWorkspace, { on: true }))
      Quickshell.execDetached(["omarchy-notification-send", "-g", "\udb84\udcac", "Workspace layout set to spaces"])
    } else {
      Quickshell.execDetached(["omarchy-hyprland-workspace-layout-toggle"])
    }
  }

  function selectTab(workspace, id, address) {
    runtime = Model.selectTab(runtime, workspace, id)
    var lua = [hiddenLua(), "hl.dispatch(hl.dsp.focus({ workspace = \"" + workspace + "\" }))", "hl.dispatch(hl.dsp.layout(\"refresh\"))"]
    var target = address || bestWindow(workspace, id)
    if (target) lua.push("hl.dispatch(" + focusDispatcher(target) + ")")
    evalLua(lua)
  }

  function bestWindow(workspace, id) {
    var tab = (runtime[workspace] || { tabs: [] }).tabs.find(function (candidate) { return candidate.id === id })
    if (!tab) return ""
    var windows = clients.filter(function (client) { return tab.windows.indexOf(client.address) !== -1 })
    windows.sort(function (left, right) { return left.focusHistoryID - right.focusHistoryID })
    return windows.length > 0 ? windows[0].address : ""
  }

  function startJob(panes, workspace, tab, replaces) {
    var job = nextJob++
    var next = Object.assign({}, jobs)
    next[job] = { panes: panes.slice(1), workspace: workspace, tab: tab }
    jobs = next
    launch(panes[0], workspace, tab, job, replaces)
  }

  function launch(pane, workspace, tab, job, replaces) {
    pending = pending.concat([Model.newLaunch(pane, workspace, tab, clients, Date.now(), job, replaces)])
    Quickshell.execDetached(Model.launchCommand(pane))
  }

  function continueJob(job) {
    var current = jobs[job]
    var next = Object.assign({}, jobs)
    delete next[job]
    if (current && current.panes.length > 0) next[job] = { panes: current.panes.slice(1), workspace: current.workspace, tab: current.tab }
    jobs = next
    if (current && current.panes.length > 0) launch(current.panes[0], current.workspace, current.tab, job)
  }

  function focusWorkspace(workspace) {
    dispatch("hl.dsp.focus({ workspace = \"" + Number(workspace) + "\" })")
  }

  function focusWindow(address) {
    dispatch(focusDispatcher(address))
  }

  function closeWindow(address) {
    dispatch("hl.dsp.window.close({ window = \"address:" + windowAddress(address) + "\" })")
  }

  function focusDispatcher(address) {
    return "hl.dsp.focus({ window = \"address:" + windowAddress(address) + "\" })"
  }

  function windowAddress(address) {
    if (!/^0x[0-9a-f]+$/.test(address)) throw new Error("not a window address: " + address)
    return address
  }

  function hiddenLua() {
    var hidden = Model.hiddenWindows(runtime)
    var rank = Model.ranks(runtime)
    pushedHidden = layoutState()
    return "spaces_hidden = { " + hidden.map(function (address) { return "[\"" + windowAddress(address) + "\"] = true" }).join(", ") + " }\n" +
      "spaces_rank = { " + Object.keys(rank).map(function (address) { return "[\"" + windowAddress(address) + "\"] = " + Number(rank[address]) }).join(", ") + " }"
  }

  function layoutState() {
    return JSON.stringify([Model.hiddenWindows(runtime), Model.ranks(runtime)])
  }

  function pushHidden(force) {
    if (!force && layoutState() === pushedHidden) return
    var lua = [hiddenLua()]
    if (Model.activeSpace(config, focusedWorkspace)) lua.push("hl.dispatch(hl.dsp.layout(\"refresh\"))")
    evalLua(lua)
  }

  function dispatch(request) {
    Hyprland.dispatch(request)
  }

  function evalLua(lua) {
    Quickshell.execDetached(["hyprctl", "eval", lua.join("\n")])
  }

  function saveConfig(next) {
    if (configError !== "") throw new Error("spaces.json is not valid, fix it before changing spaces: " + configError)
    config = next
    configFile.setText(Model.serializeConfig(next))
    applyRules()
    reconcile()
  }

  function loadConfig(text) {
    try {
      config = Model.parseConfig(text)
      configError = ""
    } catch (e) {
      configError = String(e)
      console.warn("spaces: " + configFile.path + ": " + configError)
    }
    applyRules()
    reconcile()
  }

  function applyRules() {
    if (!layoutFile.loaded) return
    var lua = [layoutFile.text()]
    config.spaces.filter(function (space) { return space.on }).forEach(function (space) {
      lua.push("hl.workspace_rule({ workspace = \"" + space.workspace + "\", layout = \"lua:spaces\" })")
    })
    lua = lua.concat(bindLua(globalBindings, true))
    lua.push(hiddenLua())
    evalLua(lua)
  }

  // INFO: fc 11oct26 Alt+Up/Down bind only in a space and Ctrl+T/L only over a web app or empty tab, terminals and editors use them
  function applyTabBindings() {
    evalLua(bindLua(tabBindings, inSpace).concat(bindLua(browserBindings, browserKeys)))
  }

  function bindLua(bindingList, bound) {
    var lua = []
    bindingList.forEach(function (binding) {
      lua.push("hl.unbind(\"" + binding[0] + "\")")
      if (bound) lua.push("hl.bind(\"" + binding[0] + "\", hl.dsp.event(\"spaces:" + binding[1] + "\"))")
    })
    return lua
  }

  function refresh() {
    if (refreshProc.running) refreshQueued = true
    else refreshProc.running = true
  }

  function receive(clientsJson, activeJson, workspaceJson) {
    clients = JSON.parse(clientsJson)
    activeAddress = JSON.parse(activeJson).address || ""
    activeLayout = JSON.parse(workspaceJson).tiledLayout || ""
    clientsLoaded = true

    var result = Model.claimLaunches(pending, clients, Model.forgetClosed(launches, clients), Date.now())
    pending = result.pending
    launches = result.launches
    var nextClaims = Object.assign({}, claims)
    result.claimed.forEach(function (claim) {
      if (claim.address !== "") {
        nextClaims[claim.address] = { workspace: claim.launch.workspace, tab: claim.launch.tab, replaces: claim.launch.replaces }
        if (claim.move) dispatch("hl.dsp.window.move({ workspace = \"" + claim.launch.workspace + "\", follow = false, window = \"address:" + windowAddress(claim.address) + "\" })")
      }
      continueJob(claim.launch.job)
    })
    claims = nextClaims
    reconcile()
  }

  function reconcile() {
    if (!clientsLoaded || !runtimeLoaded) return
    var next = Model.reconcile(config, runtime, clients, claims)
    var remaining = {}
    Object.keys(claims).forEach(function (address) {
      if (!Model.tabOfWindow(next, address) && clients.some(function (client) { return client.address === address })) remaining[address] = claims[address]
    })
    Object.keys(claims).forEach(function (address) {
      var replaces = claims[address].replaces
      if (!remaining[address] && replaces && clients.some(function (client) { return client.address === replaces })) closeWindow(replaces)
    })
    claims = remaining
    if (JSON.stringify(next) !== JSON.stringify(runtime)) {
      runtime = next
      runtimeFile.setText(JSON.stringify(next) + "\n")
    }
    followFocus()
    pushHidden(false)
  }

  // INFO: fc 11oct26 a hidden window that takes focus brings its tab, unless Hyprland just picked it after a close
  function followFocus() {
    if (Model.hiddenWindows(runtime).indexOf(activeAddress) === -1) return
    var owner = Model.tabOfWindow(runtime, activeAddress)
    var current = runtime[owner.workspace].current
    var fallback = current ? bestWindow(owner.workspace, current) : ""
    if (Date.now() - lastClosedAt < 1000 && fallback !== "") focusWindow(fallback)
    else selectTab(owner.workspace, owner.id, activeAddress)
  }

  function handleCommand(command) {
    if (command === "next-tab") stepTab(1)
    else if (command === "previous-tab") stepTab(-1)
    else if (command === "next-space") stepSpace(1)
    else if (command === "previous-space") stepSpace(-1)
    else if (command === "toggle-layout") toggleLayout()
    else if (command === "new-tab") openPrompt("new-tab")
    else if (command === "edit-url") openPrompt("edit-url")
  }

  IpcHandler {
    target: "spaces"

    function rename(name: string): void {
      if (!root.focusedSpace) throw new Error("workspace " + root.focusedWorkspace + " is not a space")
      root.saveConfig(Model.setSpace(root.config, root.focusedWorkspace, { name: name.trim() || "Space " + root.focusedWorkspace }))
    }

    function toggleLayout(): void {
      root.toggleLayout()
    }

    function newTab(input: string): void {
      root.newTab(input)
    }

    function snapshot(): string {
      return JSON.stringify({
        error: root.configError,
        focusedWorkspace: root.focusedWorkspace,
        hidden: Model.hiddenWindows(root.runtime),
        spaces: root.config.spaces.map(function (space) {
          return { name: space.name, workspace: space.workspace, on: space.on, tabs: root.tabsFor(space) }
        })
      })
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "closewindow") root.lastClosedAt = Date.now()
      if (root.refreshEvents.includes(event.name)) refreshTimer.restart()
      else if (event.name === "configreloaded") {
        root.pushedHidden = "unset"
        root.applyRules()
        root.applyTabBindings()
      } else if (event.name === "custom" && event.data.startsWith("spaces:")) root.handleCommand(event.data.slice(7))
    }
  }

  Timer {
    id: refreshTimer
    interval: 30
    onTriggered: root.refresh()
  }

  Process {
    id: refreshProc
    command: ["hyprctl", "--batch", "-j", "clients; activewindow; activeworkspace"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parts = text.split("\n\n\n")
        root.receive(parts[0], parts[1], parts[2])
      }
    }
    onExited: function (exitCode) {
      if (exitCode !== 0) console.warn("spaces: hyprctl exited with " + exitCode)
      if (root.refreshQueued) {
        root.refreshQueued = false
        root.refresh()
      }
    }
  }

  Process {
    id: captureProc
    property var request: null
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var request = captureProc.request
        var panes = Model.capturePanes(JSON.parse(text), root.launches)
        root.saveConfig(Model.pinTab(root.config, request.workspace, request.tab.id, request.tab.name, panes))
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("spaces: capture-windows: " + text.trim())
    }
  }

  FileView {
    id: layoutFile
    path: root.localPath("layout.lua")
    onLoaded: root.applyRules()
  }

  Process {
    running: true
    command: ["mkdir", "-p", root.configDir, root.stateDir]
    onExited: function (exitCode) {
      if (exitCode !== 0) {
        root.configError = "cannot create " + root.configDir + " or " + root.stateDir
        return
      }
      configFile.path = root.configDir + "/spaces.json"
      runtimeFile.path = root.stateDir + "/runtime.json"
    }
  }

  // INFO: fc 11oct26 FileView only watches a file that exists, so a missing one is written empty first
  FileView {
    id: configFile
    watchChanges: true
    printErrors: false
    onLoaded: root.loadConfig(text())
    onFileChanged: reload()
    onLoadFailed: function (error) {
      if (error === FileViewError.FileNotFound) root.saveConfig({ spaces: [] })
      else root.configError = FileViewError.toString(error)
    }
  }

  FileView {
    id: runtimeFile
    printErrors: false
    onLoaded: {
      try {
        root.runtime = JSON.parse(text())
      } catch (e) {
        console.warn("spaces: ignoring unreadable " + path + ": " + e)
      }
      root.runtimeLoaded = true
      root.reconcile()
    }
    onLoadFailed: function (error) {
      if (error !== FileViewError.FileNotFound) console.warn("spaces: " + path + ": " + FileViewError.toString(error))
      root.runtimeLoaded = true
      root.reconcile()
    }
  }

  Component.onCompleted: {
    refresh()
    applyTabBindings()
  }

  Prompt {
    id: prompt
    spaces: root
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      Sidebar {
        required property var modelData

        screen: modelData
        spaces: root
      }
    }
  }
}
