import AppKit
import Carbon.HIToolbox

// MARK: - Atalho global (Carbon, sem exigir permissão de acessibilidade)
// Reaproveitado do Soprano.

/// Registra um hotkey global e chama `action` quando pressionado.
final class GlobalHotKey {
    private var ref: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    var action: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()
        guard keyCode != 0 || modifiers != 0 else { return }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            let me = Unmanaged<GlobalHotKey>.fromOpaque(userData!).takeUnretainedValue()
            me.action?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let hkID = EventHotKeyID(signature: OSType(0x4F565231), id: 1)  // 'OVR1'
        RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        if let handlerRef { RemoveEventHandler(handlerRef); self.handlerRef = nil }
    }
}

/// Converte os modificadores do NSEvent para as flags do Carbon.
func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var m: UInt32 = 0
    if flags.contains(.command) { m |= UInt32(cmdKey) }
    if flags.contains(.option)  { m |= UInt32(optionKey) }
    if flags.contains(.control) { m |= UInt32(controlKey) }
    if flags.contains(.shift)   { m |= UInt32(shiftKey) }
    return m
}

/// Texto amigável de um atalho (ex.: "⌃⌥⌘O"), ou "Nenhum" se vazio.
func hotKeyLabel(keyCode: UInt32, carbonMods: UInt32) -> String {
    if keyCode == 0 && carbonMods == 0 { return "Nenhum" }
    var s = ""
    if carbonMods & UInt32(controlKey) != 0 { s += "⌃" }
    if carbonMods & UInt32(optionKey)  != 0 { s += "⌥" }
    if carbonMods & UInt32(shiftKey)   != 0 { s += "⇧" }
    if carbonMods & UInt32(cmdKey)     != 0 { s += "⌘" }
    s += keyName(for: keyCode)
    return s
}

/// Nome legível de uma tecla a partir do keyCode (Carbon).
func keyName(for keyCode: UInt32) -> String {
    let map: [UInt32: String] = [
        0:"A",11:"B",8:"C",2:"D",14:"E",3:"F",5:"G",4:"H",34:"I",38:"J",40:"K",
        37:"L",46:"M",45:"N",31:"O",35:"P",12:"Q",15:"R",1:"S",17:"T",32:"U",
        9:"V",13:"W",7:"X",16:"Y",6:"Z",
        18:"1",19:"2",20:"3",21:"4",23:"5",22:"6",26:"7",28:"8",25:"9",29:"0",
        49:"Espaço",36:"↩",48:"⇥",53:"Esc",
        122:"F1",120:"F2",99:"F3",118:"F4",96:"F5",97:"F6",98:"F7",100:"F8",
        101:"F9",109:"F10",103:"F11",111:"F12"
    ]
    return map[keyCode] ?? "tecla \(keyCode)"
}
