import SwiftUI

extension View {
    /// Liquid Glass on macOS 26; a blur material under a tint on older systems.
    @ViewBuilder func glass<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(.regular.tint(tint), in: shape)
        } else {
            background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if let tint { shape.fill(tint) }
                }
            }
        }
    }

    /// Translucent window background, like the reference settings window.
    func glassWindow() -> some View {
        containerBackground(.ultraThinMaterial, for: .window)
    }
}
