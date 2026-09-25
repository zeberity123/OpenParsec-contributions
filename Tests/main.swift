// Run: swiftc OpenParsec/KoreanKeyboardRouter.swift Tests/main.swift -o /tmp/keyboard-tests && /tmp/keyboard-tests
typealias Event = KoreanKeyboardRouter.Event
func down(_ code: Int) -> Event { Event(code: code, pressed: true) }
func up(_ code: Int) -> Event { Event(code: code, pressed: false) }
let toggle = [down(230), up(230)]
var router = KoreanKeyboardRouter()

for key in [144, 230] {
    assert(router.handle(code: key, pressed: true) == toggle)
    assert(router.handle(code: key, pressed: true).isEmpty)
    assert(router.repeatKey == nil)
    assert(router.handle(code: key, pressed: false).isEmpty)
}
for modifier in [224, 225, 228, 229] {
    assert(router.handle(code: modifier, pressed: true) == [down(modifier)])
    assert(router.handle(code: 44, pressed: true) == [up(modifier)] + toggle)
    assert(router.repeatKey == nil)
    assert(router.handle(code: 44, pressed: true).isEmpty)
    // Type before the keyboard delivers its delayed modifier-up: no Ctrl/Shift.
    assert(router.handle(code: 4, pressed: true) == [down(4)])
    assert(router.handle(code: 4, pressed: false) == [up(4)])
    assert(router.handle(code: modifier, pressed: false).isEmpty)
    assert(router.handle(code: 44, pressed: false).isEmpty)
    // An explicit new modifier press must still work normally.
    assert(router.handle(code: modifier, pressed: true) == [down(modifier)])
    assert(router.handle(code: modifier, pressed: false) == [up(modifier)])
}
// Reverse release order and repeats during the delayed Ctrl-up window.
_ = router.handle(code: 224, pressed: true)
assert(router.handle(code: 44, pressed: true) == [up(224)] + toggle)
assert(router.handle(code: 44, pressed: false).isEmpty)
assert(router.handle(code: 224, pressed: true).isEmpty)
assert(router.handle(code: 44, pressed: true) == [down(44)])
assert(router.handle(code: 44, pressed: false) == [up(44)])
assert(router.reset().isEmpty)
assert(router.handle(code: 224, pressed: false).isEmpty)
// A dedicated language key also releases a companion Ctrl immediately.
for key in [144, 230, 53] {
    _ = router.handle(code: 224, pressed: true)
    assert(router.handle(code: key, pressed: true, mapBacktick: true) == [up(224)] + toggle)
    assert(router.reset().isEmpty)
}
// Ordinary typing, shortcuts, and real backtick stay intact.
assert(router.handle(code: 53, pressed: true) == [down(53)])
assert(router.repeatKey == 53)
assert(router.handle(code: 53, pressed: false) == [up(53)])
assert(router.handle(code: 53, pressed: true, mapBacktick: true) == toggle)
assert(router.handle(code: 53, pressed: false).isEmpty)
assert(router.handle(code: 227, pressed: true) == [down(227)])
assert(router.handle(code: 44, pressed: true) == [down(44)])
assert(router.reset() == [up(44), up(227)])
// Ctrl+Shift+Space is not one of our language shortcuts.
_ = router.handle(code: 224, pressed: true)
_ = router.handle(code: 225, pressed: true)
assert(router.handle(code: 44, pressed: true) == [down(44)])
_ = router.reset()
// UIKit fallback may report modifier flags without a modifier press.
assert(router.handle(code: 44, pressed: true, spaceShortcut: true) == toggle)
assert(router.handle(code: 44, pressed: false).isEmpty)
// Cancellation/disconnection clears consumed keys as well as forwarded keys.
_ = router.handle(code: 144, pressed: true)
_ = router.handle(code: 4, pressed: true)
assert(router.reset() == [up(4)])
assert(router.repeatKey == nil)
assert(router.handle(code: 4, pressed: false).isEmpty)
assert(router.handle(code: 144, pressed: true) == toggle)
_ = router.reset()
// A touch toggle also preserves held modifiers and stops key repeat.
_ = router.handle(code: 225, pressed: true)
_ = router.handle(code: 4, pressed: true)
assert(router.toggle() == [up(225)] + toggle + [down(225)])
assert(router.repeatKey == nil)
assert(router.handle(code: 4, pressed: false) == [up(4)])
assert(router.handle(code: 225, pressed: false) == [up(225)])
assert(router.handle(code: 0, pressed: true).isEmpty)

// Optional Caps layer: a tap emits Esc on release, never Caps Lock.
assert(router.handle(code: 57, pressed: true, capsEscapeFn: true).isEmpty)
assert(router.handle(code: 57, pressed: true, capsEscapeFn: true).isEmpty)
assert(router.handle(code: 57, pressed: false) == [down(41), up(41)])
assert(router.repeatKey == nil)
// Every F key, in either release order, retains the translated key until key-up.
for source in Array(30...39) + [45, 46] {
    let target = source <= 39 ? 58 + source - 30 : 68 + source - 45
    for releaseCapsFirst in [false, true] {
        assert(router.handle(code: 57, pressed: true, capsEscapeFn: true).isEmpty)
        assert(router.handle(code: source, pressed: true) == [down(target)])
        assert(router.repeatKey == target)
        assert(router.handle(code: source, pressed: true).isEmpty)
        if releaseCapsFirst {
            assert(router.handle(code: 57, pressed: false).isEmpty)
        }
        assert(router.handle(code: source, pressed: false) == [up(target)])
        assert(router.repeatKey == nil)
        if !releaseCapsFirst {
            assert(router.handle(code: 57, pressed: false).isEmpty)
        }
    }
}
// Shift+F5 (and other host shortcuts) keep their actual modifiers.
assert(router.handle(code: 225, pressed: true) == [down(225)])
_ = router.handle(code: 57, pressed: true, capsEscapeFn: true)
assert(router.handle(code: 34, pressed: true) == [down(62)])
assert(router.reset() == [up(62), up(225)])
assert(router.handle(code: 57, pressed: false).isEmpty)
assert(router.handle(code: 34, pressed: false).isEmpty)
// Cancel a pending Esc without emitting it on resume.
_ = router.handle(code: 57, pressed: true, capsEscapeFn: true)
assert(router.reset().isEmpty)
assert(router.handle(code: 57, pressed: false).isEmpty)
// Multiple keys per layer hold; unrelated typing must not generate stray Esc.
_ = router.handle(code: 57, pressed: true, capsEscapeFn: true)
assert(router.handle(code: 30, pressed: true) == [down(58)])
assert(router.handle(code: 31, pressed: true) == [down(59)])
assert(router.handle(code: 30, pressed: false) == [up(58)])
assert(router.repeatKey == 59)
assert(router.handle(code: 31, pressed: false) == [up(59)])
assert(router.handle(code: 4, pressed: true) == [down(4)])
assert(router.handle(code: 4, pressed: false) == [up(4)])
assert(router.handle(code: 57, pressed: false).isEmpty)
// A physical F key and its layer alias share a single remote hold.
_ = router.handle(code: 57, pressed: true, capsEscapeFn: true)
assert(router.handle(code: 30, pressed: true) == [down(58)])
assert(router.handle(code: 58, pressed: true).isEmpty)
assert(router.handle(code: 30, pressed: false).isEmpty)
assert(router.handle(code: 58, pressed: false) == [up(58)])
assert(router.handle(code: 57, pressed: false).isEmpty)
// With the setting off, Caps Lock and the number row remain unchanged.
assert(router.handle(code: 57, pressed: true) == [down(57)])
assert(router.repeatKey == nil)
assert(router.handle(code: 30, pressed: true) == [down(30)])
assert(router.reset() == [up(30), up(57)])
print("Korean keyboard event-sequence tests passed")
