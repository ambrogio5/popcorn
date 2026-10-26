import GameController

/// Game controllers and, in the simulator or with a hardware keyboard, the keyboard. The first
/// controller is player 1, the second is player 2. Keyboard: arrows + space for P1, WASD + F for P2.
final class ControllerInput {
    func input(for player: Int) -> PlayerInput {
        var result = PlayerInput()
        let controllers = GCController.controllers().filter { $0.extendedGamepad != nil || $0.microGamepad != nil }
        if controllers.indices.contains(player) {
            let c = controllers[player]
            if let pad = c.extendedGamepad {
                let x = pad.leftThumbstick.xAxis.value
                let y = pad.leftThumbstick.yAxis.value
                if pad.dpad.left.isPressed || x < -0.4 { result.moveX = -1 }
                if pad.dpad.right.isPressed || x > 0.4 { result.moveX = 1 }
                if pad.dpad.up.isPressed || y > 0.5 { result.moveY = 1 }
                if pad.dpad.down.isPressed || y < -0.5 { result.moveY = -1 }
                result.fire = pad.buttonA.isPressed || pad.rightTrigger.isPressed || pad.buttonX.isPressed
            } else if let micro = c.microGamepad {
                if micro.dpad.left.isPressed { result.moveX = -1 }
                if micro.dpad.right.isPressed { result.moveX = 1 }
                if micro.dpad.up.isPressed { result.moveY = 1 }
                if micro.dpad.down.isPressed { result.moveY = -1 }
                result.fire = micro.buttonA.isPressed
            }
        }
        if let keyboard = GCKeyboard.coalesced?.keyboardInput {
            func down(_ code: GCKeyCode) -> Bool { keyboard.button(forKeyCode: code)?.isPressed ?? false }
            if player == 0 {
                if down(.leftArrow) { result.moveX = -1 }
                if down(.rightArrow) { result.moveX = 1 }
                if down(.upArrow) { result.moveY = 1 }
                if down(.downArrow) { result.moveY = -1 }
                if down(.spacebar) { result.fire = true }
            } else {
                if down(.keyA) { result.moveX = -1 }
                if down(.keyD) { result.moveX = 1 }
                if down(.keyW) { result.moveY = 1 }
                if down(.keyS) { result.moveY = -1 }
                if down(.keyF) { result.fire = true }
            }
        }
        return result
    }

    /// True if any physical controller is attached; used to show a hint on the menu.
    var hasController: Bool { !GCController.controllers().isEmpty }
}
