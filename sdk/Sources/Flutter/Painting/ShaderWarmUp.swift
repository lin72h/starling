// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Stub implementation of ShaderWarmUp for PaintingBinding dependencies.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/shader_warm_up.dart`
/// **Lines:** 56-100
///
/// NOTE: This is a minimal stub to support PaintingBinding migration.
/// A full ShaderWarmUp implementation will be completed in a future task.

import FlutterSwiftBridge

// MARK: - ShaderWarmUp Protocol

/// An abstract class to perform GPU shader warm-up.
///
/// Shader warm-up is useful for smooth app start-up by removing initial
/// shader compilation jank. The GPU shader compile time is commonly known
/// as "shader jank".
///
/// Subclasses can override `warmUpOnCanvas` to perform specific draw operations
/// that trigger shader compilation during app startup.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/shader_warm_up.dart`
/// **Lines:** 56-100
public protocol ShaderWarmUp {
    /// The size of the warm up image.
    ///
    /// The exact size shouldn't matter much as long as all draws are onscreen.
    /// 100x100 is an arbitrary small size that's easy to fit significant draw
    /// calls onto.
    ///
    /// A custom shader warm up can override this based on targeted devices.
    ///
    /// **Dart Source:** `shader_warm_up.dart:61-68`
    var size: Size { get }

    /// Trigger draw operations on a given canvas to warm up GPU shader
    /// compilation cache.
    ///
    /// To decide which draw operations to be added to your custom warm up
    /// process, consider capturing an skp using `flutter screenshot
    /// --vm-service-uri=<uri> --type=skia` and analyzing it with
    /// https://debugger.skia.org/. Alternatively, one may run the app with
    /// `flutter run --trace-skia` and then examine the raster thread in the
    /// Flutter DevTools timeline to see which Skia draw operations are commonly used,
    /// and which shader compilations are causing jank.
    ///
    /// **Dart Source:** `shader_warm_up.dart:70-81`
    func warmUpOnCanvas(_ canvas: Canvas) async

    /// Construct an offscreen image of `size`, and execute `warmUpOnCanvas` on a
    /// canvas associated with that image.
    ///
    /// **Dart Source:** `shader_warm_up.dart:83-100`
    func execute() async
}

// MARK: - Default Implementations

extension ShaderWarmUp {
    /// Default size for shader warm-up image.
    ///
    /// **Dart Source:** `shader_warm_up.dart:68`
    public var size: Size {
        Size(100.0, 100.0)
    }

    /// Default implementation of execute.
    ///
    /// Construct an offscreen image of `size`, and execute `warmUpOnCanvas` on a
    /// canvas associated with that image.
    ///
    /// **Dart Source:** `shader_warm_up.dart:87-100`
    public func execute() async {
        let recorder = NativePictureRecorder()
        let canvas = NativeCanvas(recorder: recorder)
        await warmUpOnCanvas(canvas)
        let _ = recorder.endRecording()
        // In debug mode, additional timeline tracking would occur here
    }
}
