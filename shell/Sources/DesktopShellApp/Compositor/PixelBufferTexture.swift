// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import FlutterMacOSBridge
import CoreVideo

/// Bridges an OffscreenRenderer to Flutter's texture system.
///
/// Conforms to `FlutterTexture` so the engine's raster thread can call
/// `copyPixelBuffer()` to fetch the latest rendered frame.
class PixelBufferTexture: NSObject, FlutterTexture {

    let renderer: OffscreenRenderer

    init(renderer: OffscreenRenderer) {
        self.renderer = renderer
        super.init()
    }

    /// Called by the engine's raster thread to obtain the current frame.
    /// Ownership of the returned CVPixelBuffer is transferred to the caller.
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pb = renderer.copyLatestPixelBuffer() else { return nil }
        return Unmanaged.passRetained(pb)
    }
}
#endif
