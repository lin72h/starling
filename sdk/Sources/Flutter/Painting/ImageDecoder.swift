// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Image decoding utilities for the painting library.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_decoder.dart`

import FlutterSwiftBridge

// MARK: - Image Decoder

/// Creates an image from a list of bytes.
///
/// This function attempts to interpret the given bytes as an image. If successful,
/// the decoded image is returned. Otherwise, an error is thrown.
///
/// If the image is animated, this returns the first frame. Consider using
/// `instantiateImageCodecWithSize` if support for animated images is necessary.
///
/// This function differs from direct codec instantiation in that it defers to
/// `PaintingBinding.instantiateImageCodecWithSize`, and therefore can be mocked
/// in tests.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/image_decoder.dart`
/// **Lines:** 13-35
public func decodeImageFromList(_ bytes: [UInt8]) async throws -> Image {
    let buffer = ImmutableBuffer.fromUint8List(bytes)
    let codec = try await PaintingBindingInstance.instance.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: nil
    )
    defer { codec.dispose() }
    let frameInfo = try await codec.getNextFrame()
    return frameInfo.image
}
