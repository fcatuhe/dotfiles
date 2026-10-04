import QtQuick
import QtTest
import "KeyboardLayoutModel.js" as Model

TestCase {
  name: "KeyboardLayoutModel"

  function keyboard(name, active_layout_index = 0, numLock = false) {
    return { name, active_layout_index, numLock }
  }

  function seat(laptop, external) {
    return [keyboard("sof-hda-dsp-headphone"), laptop, keyboard("thinkpad-extra-buttons"), external, keyboard("hl-virtual-keyboard-fcitx5", 1, true)].filter(Boolean)
  }

  function test_follows_the_keyboard_whose_digit_lock_flipped_not_the_first_one_listed() {
    const before = seat(keyboard("at-translated-set-2-keyboard"))
    const after = seat(keyboard("at-translated-set-2-keyboard", 0, true))

    compare(Model.follow(after, Model.states(before), "sof-hda-dsp-headphone").name, "at-translated-set-2-keyboard")
  }

  function test_keeps_the_current_keyboard_when_a_seat_wide_change_moves_every_device() {
    const before = seat(keyboard("at-translated-set-2-keyboard", 0, true))
    const after = seat(keyboard("at-translated-set-2-keyboard", 1, true)).map(k => Object.assign({}, k, { active_layout_index: 1 }))

    compare(Model.follow(after, Model.states(before), "at-translated-set-2-keyboard").name, "at-translated-set-2-keyboard")
  }

  function test_keeps_the_current_keyboard_when_nothing_moved_as_on_a_config_reload_naming_every_device() {
    const now = seat(keyboard("at-translated-set-2-keyboard"), keyboard("keychron-k2", 1))

    compare(Model.follow(now, Model.states(now), "keychron-k2").name, "keychron-k2")
  }

  function test_ignores_a_keyboard_plugged_in_since_the_last_reading_until_it_moves() {
    const before = seat(keyboard("at-translated-set-2-keyboard", 1))
    const after = seat(keyboard("at-translated-set-2-keyboard", 1), keyboard("keychron-k2"))

    compare(Model.follow(after, Model.states(before), "at-translated-set-2-keyboard").name, "at-translated-set-2-keyboard")
  }

  function test_starts_on_a_keyboard_someone_has_switched_or_locked_ignoring_the_virtual_one() {
    const now = seat(keyboard("at-translated-set-2-keyboard", 0, true))

    compare(Model.follow(now, {}, null).name, "at-translated-set-2-keyboard")
  }
}
