import Carbon

/// macOS virtual keycode constants mapped to human-readable names.
enum KeyCodes {
    // Letters
    static let a: UInt16 = UInt16(kVK_ANSI_A)
    static let b: UInt16 = UInt16(kVK_ANSI_B)
    static let c: UInt16 = UInt16(kVK_ANSI_C)
    static let d: UInt16 = UInt16(kVK_ANSI_D)
    static let e: UInt16 = UInt16(kVK_ANSI_E)
    static let f: UInt16 = UInt16(kVK_ANSI_F)
    static let g: UInt16 = UInt16(kVK_ANSI_G)
    static let h: UInt16 = UInt16(kVK_ANSI_H)
    static let i: UInt16 = UInt16(kVK_ANSI_I)
    static let j: UInt16 = UInt16(kVK_ANSI_J)
    static let k: UInt16 = UInt16(kVK_ANSI_K)
    static let l: UInt16 = UInt16(kVK_ANSI_L)
    static let m: UInt16 = UInt16(kVK_ANSI_M)
    static let n: UInt16 = UInt16(kVK_ANSI_N)
    static let o: UInt16 = UInt16(kVK_ANSI_O)
    static let p: UInt16 = UInt16(kVK_ANSI_P)
    static let q: UInt16 = UInt16(kVK_ANSI_Q)
    static let r: UInt16 = UInt16(kVK_ANSI_R)
    static let s: UInt16 = UInt16(kVK_ANSI_S)
    static let t: UInt16 = UInt16(kVK_ANSI_T)
    static let u: UInt16 = UInt16(kVK_ANSI_U)
    static let v: UInt16 = UInt16(kVK_ANSI_V)
    static let w: UInt16 = UInt16(kVK_ANSI_W)
    static let x: UInt16 = UInt16(kVK_ANSI_X)
    static let y: UInt16 = UInt16(kVK_ANSI_Y)
    static let z: UInt16 = UInt16(kVK_ANSI_Z)

    // Numbers
    static let key1: UInt16 = UInt16(kVK_ANSI_1)
    static let key2: UInt16 = UInt16(kVK_ANSI_2)
    static let key3: UInt16 = UInt16(kVK_ANSI_3)
    static let key4: UInt16 = UInt16(kVK_ANSI_4)
    static let key5: UInt16 = UInt16(kVK_ANSI_5)
    static let key6: UInt16 = UInt16(kVK_ANSI_6)
    static let key7: UInt16 = UInt16(kVK_ANSI_7)
    static let key8: UInt16 = UInt16(kVK_ANSI_8)
    static let key9: UInt16 = UInt16(kVK_ANSI_9)
    static let key0: UInt16 = UInt16(kVK_ANSI_0)

    // Special
    static let space: UInt16 = UInt16(kVK_Space)
    static let returnKey: UInt16 = UInt16(kVK_Return)
    static let tab: UInt16 = UInt16(kVK_Tab)
    static let escape: UInt16 = UInt16(kVK_Escape)
    static let delete: UInt16 = UInt16(kVK_Delete)

    // Arrow keys
    static let leftArrow: UInt16 = UInt16(kVK_LeftArrow)
    static let rightArrow: UInt16 = UInt16(kVK_RightArrow)
    static let upArrow: UInt16 = UInt16(kVK_UpArrow)
    static let downArrow: UInt16 = UInt16(kVK_DownArrow)

    /// Map from key name strings to keycodes (for config parsing).
    static let nameToKeyCode: [String: UInt16] = {
        var map: [String: UInt16] = [:]
        // Letters
        for (name, code) in [
            ("a", a), ("b", b), ("c", c), ("d", d), ("e", e), ("f", f),
            ("g", g), ("h", h), ("i", i), ("j", j), ("k", k), ("l", l),
            ("m", m), ("n", n), ("o", o), ("p", p), ("q", q), ("r", r),
            ("s", s), ("t", t), ("u", u), ("v", v), ("w", w), ("x", x),
            ("y", y), ("z", z)
        ] {
            map[name] = code
        }
        // Numbers
        for (name, code) in [
            ("1", key1), ("2", key2), ("3", key3), ("4", key4), ("5", key5),
            ("6", key6), ("7", key7), ("8", key8), ("9", key9), ("0", key0)
        ] {
            map[name] = code
        }
        // Special
        map["space"] = space
        map["return"] = returnKey
        map["tab"] = tab
        map["escape"] = escape
        map["delete"] = delete
        map["left"] = leftArrow
        map["right"] = rightArrow
        map["up"] = upArrow
        map["down"] = downArrow
        return map
    }()
}
