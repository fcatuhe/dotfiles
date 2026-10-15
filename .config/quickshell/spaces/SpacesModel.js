.pragma library

var terminalClasses = ["foot", "Alacritty", "com.mitchellh.ghostty", "kitty"]
var browserPrefixes = ["brave", "chrome", "chromium", "msedge", "vivaldi", "opera", "helium"]
var launchTimeout = 30000

// INFO: fc 11oct26 Chromium names an --app window class browser-host__path-Profile, slashes as underscores, kept after navigation
function appKey(url) {
  var match = /^[a-z][a-z0-9+.-]*:\/\/(?:[^@\/?#]*@)?([^\/?#:]+)(?::\d*)?([^?#]*)/i.exec(String(url || "").trim())
  if (!match) return ""
  return (match[1].toLowerCase() + "_" + (match[2] || "/")).replace(/\//g, "_")
}

function webKey(windowClass) {
  var text = String(windowClass || "")
  var dash = text.indexOf("-")
  if (dash === -1 || browserPrefixes.indexOf(text.slice(0, dash)) === -1) return ""
  var match = /^(.+__.*)-[^-]+$/.exec(text.slice(dash + 1))
  return match ? match[1] : ""
}

function urlFromKey(key) {
  var separator = key.indexOf("__")
  if (separator <= 0) return ""
  return "https://" + key.slice(0, separator) + "/" + key.slice(separator + 2).replace(/_/g, "/")
}

function host(url) {
  var match = /^[a-z][a-z0-9+.-]*:\/\/(?:[^@\/?#]*@)?([^\/?#:]+)/i.exec(String(url || ""))
  return match ? match[1].toLowerCase() : ""
}

function normalizeUrl(input) {
  var text = String(input || "").trim()
  if (text === "") return ""
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(text)) return text
  if (/^localhost(:\d+)?(\/|$)/i.test(text)) return "http://" + text
  if (!/\s/.test(text) && /^[^\/]+\.[a-z]{2,}(:\d+)?(\/|$)/i.test(text)) return "https://" + text
  return "https://search.brave.com/search?q=" + encodeURIComponent(text)
}

function paneForInput(input, home) {
  var text = String(input || "").trim()
  if (text === "") return null
  if (text === "~" || text.startsWith("~/")) return { kind: "terminal", dir: home + text.slice(1), command: [] }
  if (text.startsWith("/")) return { kind: "terminal", dir: text, command: [] }
  return { kind: "web", url: normalizeUrl(text) }
}

function isStringList(value) {
  return Array.isArray(value) && value.every(function (item) { return typeof item === "string" })
}

function parsePane(pane) {
  if (!pane || typeof pane !== "object") return null
  if (pane.kind === "web" && appKey(pane.url) !== "") return { kind: "web", url: String(pane.url) }
  if (pane.kind === "terminal" && typeof pane.dir === "string" && pane.dir !== "") {
    return { kind: "terminal", dir: pane.dir, command: isStringList(pane.command) ? pane.command : [] }
  }
  if (pane.kind === "app" && isStringList(pane.command) && pane.command.length > 0) return { kind: "app", command: pane.command }
  return null
}

function parseConfig(text) {
  var config = JSON.parse(String(text || "").trim() || "{}")
  if (config === null || typeof config !== "object" || Array.isArray(config)) throw new Error("expected an object with a spaces list")
  var spaces = Array.isArray(config.spaces) ? config.spaces : []
  var ids = {}
  return {
    spaces: spaces
      .filter(function (space) { return space && Number.isInteger(space.workspace) && space.workspace >= 1 && space.workspace <= 10 })
      .map(function (space) {
        return {
          name: String(space.name || "Space " + space.workspace),
          workspace: space.workspace,
          on: space.on !== false,
          tabs: (Array.isArray(space.tabs) ? space.tabs : [])
            .filter(function (tab) { return tab && typeof tab === "object" })
            .map(function (tab, index) {
              var id = typeof tab.id === "string" && tab.id !== "" ? tab.id : "pin-" + space.workspace + "-" + (index + 1)
              return { id: id, name: String(tab.name || ""), panes: (Array.isArray(tab.panes) ? tab.panes : []).map(parsePane).filter(Boolean) }
            })
            .filter(function (tab) {
              var unique = !ids[tab.id]
              ids[tab.id] = true
              return unique
            })
        }
      })
      .sort(function (left, right) { return left.workspace - right.workspace })
  }
}

function serializeConfig(config) {
  return JSON.stringify(config, null, 2) + "\n"
}

function spaceFor(config, workspace) {
  return config.spaces.find(function (space) { return space.workspace === workspace }) || null
}

function activeSpace(config, workspace) {
  var space = spaceFor(config, workspace)
  return space && space.on ? space : null
}

function byStableId(left, right) {
  return parseInt(left.stableId, 16) - parseInt(right.stableId, 16)
}

function tiledOn(clients, workspace) {
  return clients
    .filter(function (client) { return client.workspace && client.workspace.id === workspace && !client.floating })
    .sort(byStableId)
}

function isPinned(space, id) {
  return space.tabs.some(function (tab) { return tab.id === id })
}

function adjacentOpen(tabs, id, step) {
  var index = tabs.findIndex(function (tab) { return tab.id === id })
  for (var offset = 1; offset < tabs.length; offset++) {
    var tab = tabs[(index + step * offset + tabs.length * offset) % tabs.length]
    if (tab.windows.length > 0) return tab.id
  }
  return null
}

function reconcile(config, runtime, clients, claims) {
  var next = {}
  config.spaces.filter(function (space) { return space.on }).forEach(function (space) {
    var previous = runtime[space.workspace] || { current: null, tabs: [] }
    var live = tiledOn(clients, space.workspace)
    var alive = {}
    live.forEach(function (client) { alive[client.address] = true })

    var tabs = previous.tabs.map(function (tab) {
      return { id: tab.id, windows: tab.windows.filter(function (address) { return alive[address] }) }
    })
    var current = previous.current
    var assigned = {}
    tabs.forEach(function (tab) { tab.windows.forEach(function (address) { assigned[address] = true }) })

    live.forEach(function (client) {
      if (assigned[client.address]) return
      var claim = claims[client.address]
      var id = claim && claim.workspace === space.workspace ? claim.tab : current
      if (!id) id = current = "tab-" + client.address
      var tab = tabs.find(function (candidate) { return candidate.id === id })
      if (!tab) tabs.push(tab = { id: id, windows: [] })
      var replaced = claim && claim.replaces ? tab.windows.indexOf(claim.replaces) : -1
      if (replaced === -1) tab.windows.push(client.address)
      else tab.windows.splice(replaced, 0, client.address)
    })

    var emptied = previous.tabs.some(function (tab) { return tab.id === current && tab.windows.length > 0 }) &&
      tabs.some(function (tab) { return tab.id === current && tab.windows.length === 0 })
    if (emptied) current = adjacentOpen(tabs, current, 1)
    if (!current) {
      var open = tabs.find(function (tab) { return tab.windows.length > 0 })
      current = open ? open.id : null
    }

    next[space.workspace] = {
      current: current,
      tabs: tabs.filter(function (tab) { return tab.windows.length > 0 || tab.id === current || isPinned(space, tab.id) })
    }
  })
  return next
}

function hiddenWindows(runtime) {
  var hidden = []
  Object.keys(runtime).forEach(function (workspace) {
    var space = runtime[workspace]
    space.tabs.forEach(function (tab) {
      if (tab.id !== space.current) hidden = hidden.concat(tab.windows)
    })
  })
  return hidden.sort()
}

function ranks(runtime) {
  var rank = {}
  Object.keys(runtime).forEach(function (workspace) {
    runtime[workspace].tabs.forEach(function (tab) {
      tab.windows.forEach(function (address, index) { rank[address] = index + 1 })
    })
  })
  return rank
}

function activeClient(clients, activeAddress) {
  return clients.find(function (client) { return client.address === activeAddress }) || null
}

function activeWebPane(clients, activeAddress, launches) {
  var client = activeClient(clients, activeAddress)
  var url = client ? windowUrl(client, launches) : ""
  return url !== "" ? { address: client.address, url: url } : null
}

function browserKeys(config, workspace, clients, activeAddress, launches) {
  if (!activeSpace(config, workspace)) return false
  var client = activeClient(clients, activeAddress)
  return !client || client.workspace.id !== workspace || client.floating || activeWebPane(clients, activeAddress, launches) !== null
}

function selectTab(runtime, workspace, id) {
  var next = Object.assign({}, runtime)
  var space = runtime[workspace] || { current: null, tabs: [] }
  var tabs = space.tabs.filter(function (tab) { return tab.windows.length > 0 || tab.id === id || tab.id !== space.current })
  if (!tabs.some(function (tab) { return tab.id === id })) tabs.push({ id: id, windows: [] })
  next[workspace] = { current: id, tabs: tabs }
  return next
}

function tabOfWindow(runtime, address) {
  var found = null
  Object.keys(runtime).forEach(function (workspace) {
    runtime[workspace].tabs.forEach(function (tab) {
      if (tab.windows.indexOf(address) !== -1) found = { workspace: Number(workspace), id: tab.id }
    })
  })
  return found
}

function paneLabel(pane) {
  if (pane.kind === "web") return host(pane.url)
  var name = pane.kind === "terminal" ? pane.dir.replace(/\/+$/, "").split("/").pop() || "/" : pane.command[0].split("/").pop()
  return pane.kind === "terminal" && pane.command.length > 0 ? name + " \u00b7 " + pane.command[0] : name
}

function windowUrl(client, launches) {
  return launches[client.address] || urlFromKey(webKey(client.class))
}

function tabs(space, runtime, clients, activeAddress, launches) {
  var state = runtime[space.workspace] || { current: null, tabs: [] }
  var byAddress = {}
  clients.forEach(function (client) { byAddress[client.address] = client })
  var livePanes = function (tab) {
    return tab.windows.filter(function (address) { return byAddress[address] }).map(function (address) {
      var client = byAddress[address]
      return { address: address, title: String(client.title || client.class || ""), url: windowUrl(client, launches), open: true, active: address === activeAddress }
    })
  }
  var runtimeTab = function (id) {
    return state.tabs.find(function (tab) { return tab.id === id }) || { id: id, windows: [] }
  }

  var pinned = space.tabs.map(function (pin) {
    var panes = livePanes(runtimeTab(pin.id))
    return {
      id: pin.id,
      pinned: true,
      name: pin.name || (pin.panes.length > 0 ? paneLabel(pin.panes[0]) : "Pinned"),
      open: panes.length > 0,
      active: pin.id === state.current,
      panes: panes.length > 0 ? panes : pin.panes.map(function (pane) {
        return { address: "", title: paneLabel(pane), url: pane.kind === "web" ? pane.url : "", open: false, active: false }
      })
    }
  })

  var unpinned = state.tabs
    .filter(function (tab) { return !isPinned(space, tab.id) })
    .map(function (tab) {
      var panes = livePanes(tab)
      return { id: tab.id, pinned: false, name: panes.length > 0 ? panes[0].title : "New Tab", open: panes.length > 0, active: tab.id === state.current, panes: panes }
    })

  return pinned.concat(unpinned)
}

function adjacentTab(tabList, step) {
  var reachable = tabList.filter(function (tab) { return tab.open || tab.active })
  if (reachable.length === 0) return null
  var index = reachable.findIndex(function (tab) { return tab.active })
  if (index === -1) return step > 0 ? reachable[0] : reachable[reachable.length - 1]
  return reachable[(index + step + reachable.length) % reachable.length]
}

function adjacentSpace(config, workspace, step) {
  var spaces = config.spaces.filter(function (space) { return space.on })
  if (spaces.length === 0) return null
  var index = spaces.findIndex(function (space) { return space.workspace === workspace })
  if (index !== -1) return spaces[(index + step + spaces.length) % spaces.length]
  var after = spaces.findIndex(function (space) { return space.workspace > workspace })
  if (step > 0) return after === -1 ? spaces[0] : spaces[after]
  return after <= 0 ? spaces[spaces.length - 1] : spaces[after - 1]
}

function withSpace(config, workspace, change) {
  return {
    spaces: config.spaces.map(function (space) {
      return space.workspace === workspace ? change(space) : space
    })
  }
}

function setSpace(config, workspace, changes) {
  if (spaceFor(config, workspace)) {
    return withSpace(config, workspace, function (space) { return Object.assign({}, space, changes) })
  }
  var created = Object.assign({ name: "Space " + workspace, workspace: workspace, on: true, tabs: [] }, changes)
  return parseConfig(serializeConfig({ spaces: config.spaces.concat([created]) }))
}

function pinTab(config, workspace, id, name, panes) {
  return withSpace(config, workspace, function (space) {
    return Object.assign({}, space, { tabs: space.tabs.filter(function (tab) { return tab.id !== id }).concat([{ id: id, name: name, panes: panes }]) })
  })
}

function unpinTab(config, workspace, id) {
  return withSpace(config, workspace, function (space) {
    return Object.assign({}, space, { tabs: space.tabs.filter(function (tab) { return tab.id !== id }) })
  })
}

function paneFromWindow(info, launches) {
  var terminal = terminalClasses.indexOf(info.class) !== -1
  if (launches[info.address]) return { kind: "web", url: launches[info.address] }
  var url = urlFromKey(webKey(info.class))
  if (url !== "") return { kind: "web", url: url }
  if (terminal && info.shellCwd) return { kind: "terminal", dir: info.shellCwd, command: isStringList(info.shellChild) ? info.shellChild : [] }
  if (isStringList(info.cmdline) && info.cmdline.length > 0) return { kind: "app", command: info.cmdline }
  return null
}

function capturePanes(windows, launches) {
  return windows.map(function (info) { return paneFromWindow(info, launches) }).filter(Boolean)
}

function launchCommand(pane) {
  if (pane.kind === "web") return ["omarchy-launch-webapp", pane.url]
  if (pane.kind === "terminal") return ["uwsm-app", "--", "xdg-terminal-exec", "--dir=" + pane.dir].concat(pane.command)
  return ["uwsm-app", "--"].concat(pane.command)
}

function newLaunch(pane, workspace, tab, clients, now, job, replaces) {
  var known = {}
  clients.forEach(function (client) { known[client.address] = true })
  return { pane: pane, workspace: workspace, tab: tab, replaces: replaces || "", key: pane.kind === "web" ? appKey(pane.url) : "", known: known, at: now, job: job }
}

function claimLaunches(pending, clients, launches, now) {
  var nextLaunches = Object.assign({}, launches)
  var taken = {}
  var claimed = []
  var ordered = clients.slice().sort(byStableId)
  var remaining = pending.filter(function (launch) {
    if (now - launch.at > launchTimeout) {
      claimed.push({ launch: launch, address: "", move: false })
      return false
    }
    var window = ordered.find(function (client) {
      return !taken[client.address] && !launch.known[client.address] && (launch.key === "" || webKey(client.class) === launch.key)
    })
    if (!window) return true
    taken[window.address] = true
    if (launch.pane.kind === "web") nextLaunches[window.address] = launch.pane.url
    claimed.push({ launch: launch, address: window.address, move: window.workspace.id !== launch.workspace })
    return false
  })
  return { pending: remaining, launches: nextLaunches, claimed: claimed }
}

function forgetClosed(launches, clients) {
  var next = {}
  clients.forEach(function (client) {
    if (launches[client.address]) next[client.address] = launches[client.address]
  })
  return next
}
