const { test } = require("node:test")
const assert = require("node:assert")
const { follow, states } = require("./KeyboardLayoutModel.js")

const keyboard = (name, active_layout_index = 0, numLock = false) => ({ name, active_layout_index, numLock })
const seat = (laptop, external) => [keyboard("sof-hda-dsp-headphone"), laptop, keyboard("thinkpad-extra-buttons"), external, keyboard("hl-virtual-keyboard-fcitx5", 1, true)].filter(Boolean)

test("follows the keyboard whose digit lock flipped, not the first one listed", () => {
  const before = seat(keyboard("at-translated-set-2-keyboard"))
  const after = seat(keyboard("at-translated-set-2-keyboard", 0, true))

  assert.equal(follow(after, states(before), "sof-hda-dsp-headphone").name, "at-translated-set-2-keyboard")
})

test("keeps the current keyboard when a seat-wide change moves every device", () => {
  const before = seat(keyboard("at-translated-set-2-keyboard", 0, true))
  const after = seat(keyboard("at-translated-set-2-keyboard", 1, true)).map(k => ({ ...k, active_layout_index: 1 }))

  assert.equal(follow(after, states(before), "at-translated-set-2-keyboard").name, "at-translated-set-2-keyboard")
})

test("keeps the current keyboard when nothing moved, as on a config reload naming every device", () => {
  const now = seat(keyboard("at-translated-set-2-keyboard"), keyboard("keychron-k2", 1))

  assert.equal(follow(now, states(now), "keychron-k2").name, "keychron-k2")
})

test("ignores a keyboard plugged in since the last reading until it moves", () => {
  const before = seat(keyboard("at-translated-set-2-keyboard", 1))
  const after = seat(keyboard("at-translated-set-2-keyboard", 1), keyboard("keychron-k2"))

  assert.equal(follow(after, states(before), "at-translated-set-2-keyboard").name, "at-translated-set-2-keyboard")
})

test("starts on a keyboard someone has switched or locked, ignoring the virtual one", () => {
  const now = seat(keyboard("at-translated-set-2-keyboard", 0, true))

  assert.equal(follow(now, {}, null).name, "at-translated-set-2-keyboard")
})
