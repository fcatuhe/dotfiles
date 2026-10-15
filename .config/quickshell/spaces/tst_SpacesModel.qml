import QtQuick
import QtTest
import "SpacesModel.js" as Model

TestCase {
  name: "SpacesModel"

  function win(address, workspace, klass, stableId, title, floating) {
    return { address, workspace: { id: workspace }, class: klass, stableId, title: title || klass, floating: !!floating }
  }

  function config(tabs, on) {
    return { spaces: [{ name: "Work", workspace: 3, on: on !== false, tabs: tabs || [] }] }
  }

  function thrown(fn) {
    try { fn() } catch (e) { return true }
    return false
  }

  // Each class is one Brave Origin gave a web app window, read back from hyprctl clients
  function test_a_web_app_window_is_recognised_by_its_class() {
    compare(Model.appKey("https://example.com/"), "example.com__")
    compare(Model.appKey("https://app.hey.com"), "app.hey.com__")
    compare(Model.appKey("https://www.iana.org/help/example-domains/"), "www.iana.org__help_example-domains_")
    compare(Model.appKey("http://localhost:3000/x?y=1"), "localhost__x")
    compare(Model.webKey("brave-example.com__-Default"), "example.com__")
    compare(Model.webKey("brave-www.iana.org__help_example-domains_-Default"), "www.iana.org__help_example-domains_")
    compare(Model.webKey("chrome-x.com__-Default"), "x.com__")
    compare(Model.webKey("brave-origin"), "")
    compare(Model.webKey("foot"), "")
    compare(Model.urlFromKey("www.iana.org__help_example-domains_"), "https://www.iana.org/help/example-domains/")
    compare(Model.urlFromKey("example.com__"), "https://example.com/")
  }

  function test_input_opens_a_terminal_for_a_path_and_a_web_app_otherwise() {
    compare(Model.paneForInput("~/fcode/crooz", "/home/f"), { kind: "terminal", dir: "/home/f/fcode/crooz", command: [] })
    compare(Model.paneForInput("/tmp", "/home/f"), { kind: "terminal", dir: "/tmp", command: [] })
    compare(Model.paneForInput("app.hey.com", "/home/f"), { kind: "web", url: "https://app.hey.com" })
    compare(Model.paneForInput("localhost:3000/up", "/home/f"), { kind: "web", url: "http://localhost:3000/up" })
    compare(Model.paneForInput("rails guides", "/home/f"), { kind: "web", url: "https://search.brave.com/search?q=rails%20guides" })
    compare(Model.paneForInput("  ", "/home/f"), null)
  }

  function test_parse_config_keeps_valid_spaces_and_gives_old_pins_an_id() {
    const parsed = Model.parseConfig(JSON.stringify({ spaces: [
      { name: "Home", workspace: 5, on: false, tabs: [{ name: "Mail", slot: 2, panes: [{ kind: "web", url: "https://app.hey.com" }, { kind: "web", url: "nope" }] }] },
      { workspace: 2, tabs: [{ id: "a", name: "A" }, { id: "a", name: "Dup" }] },
      { name: "Eleven", workspace: 11 },
      { name: "Broken" }
    ] }))

    compare(parsed.spaces.map(s => [s.workspace, s.name, s.on]), [[2, "Space 2", true], [5, "Home", false]])
    compare(parsed.spaces[0].tabs, [{ id: "a", name: "A", panes: [] }])
    compare(parsed.spaces[1].tabs, [{ id: "pin-5-1", name: "Mail", panes: [{ kind: "web", url: "https://app.hey.com" }] }])
  }

  function test_parse_config_throws_rather_than_reading_a_broken_file_as_empty() {
    verify(thrown(() => Model.parseConfig("{ spaces: ")))
    for (const text of ["\"8\"", "[]", "null"]) verify(thrown(() => Model.parseConfig(text)), text)
  }

  function test_new_windows_join_the_current_tab_and_a_first_window_starts_one() {
    let runtime = Model.reconcile(config(), {}, [win("0xa", 3, "foot", "1")], {})
    compare(runtime, { "3": { current: "tab-0xa", tabs: [{ id: "tab-0xa", windows: ["0xa"] }] } })

    runtime = Model.reconcile(config(), runtime, [win("0xa", 3, "foot", "1"), win("0xb", 3, "brave-x.com__-Default", "2")], {})
    compare(runtime["3"].tabs, [{ id: "tab-0xa", windows: ["0xa", "0xb"] }])
  }

  function test_a_claimed_window_joins_the_tab_it_was_launched_for() {
    const runtime = { "3": { current: "t1", tabs: [{ id: "t1", windows: ["0xa"] }] } }
    const next = Model.reconcile(config(), runtime, [win("0xa", 3, "foot", "1"), win("0xb", 3, "foot", "2")], { "0xb": { workspace: 3, tab: "t2" } })

    compare(next["3"], { current: "t1", tabs: [{ id: "t1", windows: ["0xa"] }, { id: "t2", windows: ["0xb"] }] })
  }

  function test_a_window_replacing_a_pane_takes_its_place_in_the_tab() {
    const runtime = { "3": { current: "t1", tabs: [{ id: "t1", windows: ["0xa", "0xb", "0xc"] }] } }
    const clients = [win("0xa", 3, "foot", "1"), win("0xb", 3, "brave-x.com__-Default", "2"), win("0xc", 3, "foot", "3"), win("0xd", 3, "brave-y.com__-Default", "4")]
    const next = Model.reconcile(config(), runtime, clients, { "0xd": { workspace: 3, tab: "t1", replaces: "0xb" } })

    compare(next["3"].tabs[0].windows, ["0xa", "0xd", "0xb", "0xc"])
    compare(Model.ranks(next), { "0xa": 1, "0xd": 2, "0xb": 3, "0xc": 4 })
  }

  function test_browser_keys_apply_to_a_web_app_or_an_empty_tab_in_a_space_never_a_terminal() {
    const spaces = config()
    const clients = [win("0xw", 3, "brave-x.com__-Default", "1"), win("0xt", 3, "foot", "2"), win("0xo", 4, "brave-x.com__-Default", "3")]

    verify(Model.browserKeys(spaces, 3, clients, "0xw", {}))
    verify(Model.browserKeys(spaces, 3, clients, "", {}))
    verify(!Model.browserKeys(spaces, 3, clients, "0xt", {}))
    verify(!Model.browserKeys(spaces, 4, clients, "0xo", {}))
    compare(Model.activeWebPane(clients, "0xw", { "0xw": "https://x.com/home" }), { address: "0xw", url: "https://x.com/home" })
    compare(Model.activeWebPane(clients, "0xt", {}), null)
  }

  function test_floating_windows_and_other_workspaces_stay_out_of_tabs() {
    const next = Model.reconcile(config(), {}, [win("0xa", 3, "foot", "1", "", true), win("0xb", 4, "foot", "2")], {})

    compare(next, { "3": { current: null, tabs: [] } })
  }

  function test_closing_the_current_tab_moves_to_the_next_open_one_and_keeps_pins() {
    const runtime = { "3": { current: "t2", tabs: [{ id: "pin", windows: ["0xa"] }, { id: "t2", windows: ["0xb"] }, { id: "t3", windows: ["0xc"] }] } }
    const clients = [win("0xa", 3, "foot", "1"), win("0xc", 3, "foot", "3")]
    let next = Model.reconcile(config([{ id: "pin", name: "P", panes: [] }]), runtime, clients, {})

    compare(next["3"], { current: "t3", tabs: [{ id: "pin", windows: ["0xa"] }, { id: "t3", windows: ["0xc"] }] })

    next = Model.reconcile(config([{ id: "pin", name: "P", panes: [] }]), next, [], {})
    compare(next["3"], { current: null, tabs: [{ id: "pin", windows: [] }] })
  }

  function test_a_space_switched_off_drops_its_tabs() {
    compare(Model.reconcile(config([], false), { "3": { current: "t", tabs: [{ id: "t", windows: ["0xa"] }] } }, [win("0xa", 3, "foot", "1")], {}), {})
  }

  function test_every_tab_but_the_current_one_is_hidden() {
    const runtime = {
      "3": { current: "t1", tabs: [{ id: "t1", windows: ["0xa"] }, { id: "t2", windows: ["0xc", "0xb"] }] },
      "5": { current: "t9", tabs: [{ id: "t9", windows: ["0xd"] }] }
    }

    compare(Model.hiddenWindows(runtime), ["0xb", "0xc"])
  }

  function test_selecting_a_tab_drops_an_abandoned_empty_new_tab() {
    const runtime = { "3": { current: "new", tabs: [{ id: "t1", windows: ["0xa"] }, { id: "new", windows: [] }] } }

    compare(Model.selectTab(runtime, 3, "t1")["3"], { current: "t1", tabs: [{ id: "t1", windows: ["0xa"] }] })
    compare(Model.selectTab(runtime, 3, "pin")["3"].tabs.map(t => t.id), ["t1", "pin"])
  }

  function test_tab_of_window_finds_its_space_and_tab() {
    const runtime = { "3": { current: "t1", tabs: [{ id: "t1", windows: ["0xa"] }] } }

    compare(Model.tabOfWindow(runtime, "0xa"), { workspace: 3, id: "t1" })
    compare(Model.tabOfWindow(runtime, "0xz"), null)
  }

  function test_tabs_list_pins_with_live_or_saved_panes_then_open_tabs() {
    const space = config([
      { id: "mail", name: "Mail", panes: [] },
      { id: "dev", name: "", panes: [{ kind: "terminal", dir: "/home/f/fcode/crooz", command: ["herdr"] }, { kind: "web", url: "https://app.hey.com" }] }
    ]).spaces[0]
    const runtime = { "3": { current: "mail", tabs: [{ id: "mail", windows: ["0xa", "0xb"] }, { id: "t5", windows: ["0xc"] }] } }
    const clients = [win("0xa", 3, "brave-app.hey.com__-Default", "1", "HEY"), win("0xb", 3, "foot", "2", "herdr"), win("0xc", 3, "brave-x.com__-Default", "3", "Home / X")]
    const tabs = Model.tabs(space, runtime, clients, "0xb", { "0xc": "https://x.com/home" })

    compare(tabs.map(t => [t.id, t.name, t.pinned, t.open, t.active]), [
      ["mail", "Mail", true, true, true],
      ["dev", "crooz \u00b7 herdr", true, false, false],
      ["t5", "Home / X", false, true, false]
    ])
    compare(tabs[0].panes.map(p => [p.title, p.url, p.active]), [["HEY", "https://app.hey.com/", false], ["herdr", "", true]])
    compare(tabs[1].panes.map(p => [p.title, p.open]), [["crooz \u00b7 herdr", false], ["app.hey.com", false]])
    compare(tabs[2].panes[0].url, "https://x.com/home")
  }

  function test_adjacent_tab_cycles_through_open_tabs_and_the_current_one() {
    const tabs = [{ id: "a", open: true, active: false }, { id: "b", open: false, active: false }, { id: "c", open: false, active: true }, { id: "d", open: true, active: false }]

    compare(Model.adjacentTab(tabs, 1).id, "d")
    compare(Model.adjacentTab(tabs, -1).id, "a")
    compare(Model.adjacentTab([], 1), null)
  }

  function test_adjacent_space_skips_spaces_switched_off_and_enters_from_outside() {
    const spaces = { spaces: [{ workspace: 2, on: true }, { workspace: 4, on: false }, { workspace: 6, on: true }] }

    compare(Model.adjacentSpace(spaces, 2, 1).workspace, 6)
    compare(Model.adjacentSpace(spaces, 6, 1).workspace, 2)
    compare(Model.adjacentSpace(spaces, 4, 1).workspace, 6)
    compare(Model.adjacentSpace(spaces, 4, -1).workspace, 2)
    compare(Model.adjacentSpace(spaces, 1, -1).workspace, 6)
  }

  function test_set_space_creates_a_space_or_changes_one_keeping_its_pins() {
    let spaces = Model.setSpace({ spaces: [] }, 6, { on: true })
    spaces = Model.setSpace(spaces, 6, { name: "Home" })
    spaces = Model.pinTab(spaces, 6, "p", "Mail", [])
    spaces = Model.setSpace(spaces, 6, { on: false })

    compare(spaces.spaces, [{ name: "Home", workspace: 6, on: false, tabs: [{ id: "p", name: "Mail", panes: [] }] }])
  }

  function test_pin_tab_replaces_a_pin_with_the_same_id_and_unpin_removes_it() {
    let spaces = config()
    spaces = Model.pinTab(spaces, 3, "p", "Mail", [{ kind: "web", url: "https://app.hey.com" }])
    spaces = Model.pinTab(spaces, 3, "p", "Mail", [])
    spaces = Model.pinTab(spaces, 3, "q", "X", [])
    spaces = Model.unpinTab(spaces, 3, "q")

    compare(spaces.spaces[0].tabs, [{ id: "p", name: "Mail", panes: [] }])
  }

  function test_capture_turns_windows_into_web_terminal_and_app_panes() {
    const windows = [
      { address: "0xa", class: "brave-app.hey.com__-Default", cmdline: ["/opt/brave"] },
      { address: "0xb", class: "brave-x.com__-Default", cmdline: ["/opt/brave"] },
      { address: "0xc", class: "foot", shellCwd: "/home/f/fcode/crooz", shellChild: ["herdr"], cmdline: ["foot"] },
      { address: "0xd", class: "foot", shellCwd: "", shellChild: [], cmdline: ["foot", "-e", "herdr"] },
      { address: "0xe", class: "codium", cmdline: ["/opt/vscodium-bin/codium", "/home/f/fcode/crooz"] },
      { address: "0xf", class: "ghost", cmdline: [] }
    ]

    compare(Model.capturePanes(windows, { "0xb": "https://x.com/home?tab=1" }), [
      { kind: "web", url: "https://app.hey.com/" },
      { kind: "web", url: "https://x.com/home?tab=1" },
      { kind: "terminal", dir: "/home/f/fcode/crooz", command: ["herdr"] },
      { kind: "app", command: ["foot", "-e", "herdr"] },
      { kind: "app", command: ["/opt/vscodium-bin/codium", "/home/f/fcode/crooz"] }
    ])
  }

  function test_launch_command_is_an_argument_list_never_a_shell_string() {
    compare(Model.launchCommand({ kind: "web", url: "https://a.com/?q=$(x)" }), ["omarchy-launch-webapp", "https://a.com/?q=$(x)"])
    compare(Model.launchCommand({ kind: "terminal", dir: "/tmp/a b", command: ["herdr"] }), ["uwsm-app", "--", "xdg-terminal-exec", "--dir=/tmp/a b", "herdr"])
    compare(Model.launchCommand({ kind: "app", command: ["codium", "/tmp"] }), ["uwsm-app", "--", "codium", "/tmp"])
  }

  function test_a_web_launch_claims_the_first_new_window_of_its_url_whatever_its_title() {
    const before = [win("0xold", 3, "brave-app.hey.com__-Default", "1")]
    const pending = [Model.newLaunch({ kind: "web", url: "https://app.hey.com" }, 3, "t2", before, 1000, 7)]
    const clients = before.concat([win("0xother", 1, "brave-x.com__-Default", "2"), win("0xnew", 1, "brave-app.hey.com__-Default", "3", "HEY")])
    const result = Model.claimLaunches(pending, clients, {}, 2000)

    compare(result.pending, [])
    compare(result.launches, { "0xnew": "https://app.hey.com" })
    compare(result.claimed.map(c => [c.address, c.move, c.launch.tab, c.launch.job]), [["0xnew", true, "t2", 7]])
  }

  function test_a_terminal_launch_claims_any_new_window() {
    const pending = [Model.newLaunch({ kind: "terminal", dir: "/tmp", command: [] }, 3, "t1", [], 1000, 1)]
    const result = Model.claimLaunches(pending, [win("0xt", 3, "foot", "5")], {}, 2000)

    compare(result.claimed.map(c => [c.address, c.move]), [["0xt", false]])
    compare(result.launches, {})
  }

  function test_a_launch_waits_for_its_window_then_gives_up_after_thirty_seconds() {
    const pending = [Model.newLaunch({ kind: "web", url: "https://app.hey.com" }, 3, "t1", [], 1000, 1)]

    compare(Model.claimLaunches(pending, [], {}, 2000).pending.length, 1)
    const expired = Model.claimLaunches(pending, [], {}, 31001)
    compare(expired.pending.length, 0)
    compare(expired.claimed.map(c => c.address), [""])
  }

  function test_forget_closed_drops_launch_urls_of_windows_gone() {
    compare(Model.forgetClosed({ "0xa": "https://a.com", "0xb": "https://b.com" }, [win("0xb", 3, "foot", "1")]), { "0xb": "https://b.com" })
  }
}
