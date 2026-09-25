// USB HID usages, matching Parsec's physical key codes. Kept independent of
// UIKit/GameController so event sequences can be tested on the build machine.
struct KoreanKeyboardRouter {
    struct Event: Equatable {
        let code: Int
        let pressed: Bool
    }

    private var held: Set<Int> = []
    // Physical -> remote key, so a layer key can be released before its target.
    private var forwarded: [Int: Int] = [:]
    private var consumed: Set<Int> = []
    private var capsLayerActive = false
    private var capsLayerUsed = false
    private(set) var repeatKey: Int?

    mutating func handle(code: Int, pressed: Bool, mapBacktick: Bool = false,
                         spaceShortcut: Bool = false, capsEscapeFn: Bool = false) -> [Event] {
        guard code > 3 && code < 65535 else { return [] }
        if !pressed {
            held.remove(code)
            if code == 57 && capsLayerActive {
                capsLayerActive = false
                return capsLayerUsed ? [] : [Event(code: 41, pressed: true), Event(code: 41, pressed: false)]
            }
            if consumed.remove(code) != nil { return [] }
            guard let remoteCode = forwarded.removeValue(forKey: code) else { return [] }
            if forwarded.values.contains(remoteCode) { return [] }
            if repeatKey == remoteCode { repeatKey = nil }
            return [Event(code: remoteCode, pressed: false)]
        }
        // A held language key must toggle once, never at the repeat rate.
        guard held.insert(code).inserted else { return [] }
        if code == 57 && capsEscapeFn {
            capsLayerActive = true
            capsLayerUsed = false
            repeatKey = nil
            return []
        }
        if capsLayerActive { capsLayerUsed = true }
        let modifiers = held.subtracting(consumed).filter { (224...231).contains($0) }
        let shiftOnly = !modifiers.isEmpty && modifiers.allSatisfy { $0 == 225 || $0 == 229 }
        let controlOnly = !modifiers.isEmpty && modifiers.allSatisfy { $0 == 224 || $0 == 228 }
        let languageKey = code == 144 || code == 230 || (mapBacktick && code == 53)
        if languageKey || (code == 44 && (spaceShortcut || shiftOnly || controlOnly)) {
            consumed.insert(code)
            return toggle(consumeModifiers: true)
        }
        let remoteCode: Int
        if capsLayerActive && (30...39).contains(code) {
            remoteCode = 58 + code - 30 // 1...9, 0 -> F1...F10
        } else if capsLayerActive && (45...46).contains(code) {
            remoteCode = 68 + code - 45 // -, = -> F11, F12
        } else {
            remoteCode = code
        }
        let alreadyForwarded = forwarded.values.contains(remoteCode)
        forwarded[code] = remoteCode
        // Lock keys and language keys must not acquire the software repeat timer.
        if !(224...231).contains(code) && ![57, 71, 83, 145].contains(code) {
            repeatKey = remoteCode
        }
        return alreadyForwarded ? [] : [Event(code: remoteCode, pressed: true)]
    }

    mutating func toggle(consumeModifiers: Bool = false) -> [Event] {
        repeatKey = nil
        let modifiers = forwarded.keys.filter { (224...231).contains($0) }.sorted()
        if consumeModifiers {
            // Bluetooth language keys can emit Ctrl+Space with a delayed Ctrl-up.
            // End the whole shortcut now; ignore those modifiers until real key-up.
            // Re-pressing Ctrl/Shift starts an ordinary shortcut immediately.
            for code in modifiers {
                forwarded.removeValue(forKey: code)
                consumed.insert(code)
            }
        }
        return modifiers.map { Event(code: $0, pressed: false) }
            + [Event(code: 230, pressed: true), Event(code: 230, pressed: false)]
            + (consumeModifiers ? [] : modifiers.map { Event(code: $0, pressed: true) })
    }

    mutating func reset() -> [Event] {
        let releases = Set(forwarded.values).sorted().map { Event(code: $0, pressed: false) }
        held.removeAll()
        forwarded.removeAll()
        consumed.removeAll()
        capsLayerActive = false
        capsLayerUsed = false
        repeatKey = nil
        return releases
    }
}
