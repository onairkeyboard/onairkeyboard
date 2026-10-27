; A fake microphone registry for tests: HKCU\Software\OnAirKeyboardTest\microphone, laid out
; like Windows' CapabilityAccessManager key (package keys, NonPackaged\<EXE path with #>).
class FakeMic {
    static Key := "Software\OnAirKeyboardTest\microphone"

    ; keyName: a package name or an EXE path with # (nonPackaged); "" values leave the key empty
    static Set(keyName, start, stop, nonPackaged := false) {
        sub := FakeMic.Key (nonPackaged ? "\NonPackaged\" : "\") keyName
        if start = "" {
            RegWrite("Allow", "REG_SZ", "HKCU\" sub, "Value")
            return
        }
        FakeMic._Qword(sub, "LastUsedTimeStart", start)
        FakeMic._Qword(sub, "LastUsedTimeStop", stop)
    }

    static Reset() {
        FakeMic.Delete()
        RegCreateKey("HKCU\" FakeMic.Key)
    }

    static Delete() {
        try RegDeleteKey("HKCU\Software\OnAirKeyboardTest")
    }

    ; RegWrite has no REG_QWORD
    static _Qword(sub, name, value) {
        r := DllCall("Advapi32\RegSetKeyValueW", "Ptr", -2147483647, "Str", sub, "Str", name
            , "UInt", 11, "Int64*", value, "UInt", 8, "UInt")  ; REG_QWORD
        if r != 0
            throw OSError(r, , "RegSetKeyValueW " sub)
    }
}
