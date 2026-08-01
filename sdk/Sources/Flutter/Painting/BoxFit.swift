// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterSwiftBridge

// MARK: - BoxFit
/// How a box should be inscribed into another box.
///
/// See also:
///
///  * ``applyBoxFit(_:_:_:)``, which applies the sizing semantics of these values (though
///    not the alignment semantics).
///
/// **Dart Source:** `packages/flutter/lib/src/painting/box_fit.dart`
/// **Original Name:** `BoxFit`
/// **Lines:** 22-79
public enum BoxFit: Sendable {
    /// Fill the target box by distorting the source's aspect ratio.
    ///
    /// **Dart Source:** `box_fit.dart:23-26`
    case fill

    /// As large as possible while still containing the source entirely within the
    /// target box.
    ///
    /// **Dart Source:** `box_fit.dart:28-32`
    case contain

    /// As small as possible while still covering the entire target box.
    ///
    /// To actually clip the content, use `clipBehavior: Clip.hardEdge` alongside
    /// this in a `FittedBox`.
    ///
    /// **Dart Source:** `box_fit.dart:34-42`
    case cover

    /// Make sure the full width of the source is shown, regardless of
    /// whether this means the source overflows the target box vertically.
    ///
    /// To actually clip the content, use `clipBehavior: Clip.hardEdge` alongside
    /// this in a `FittedBox`.
    ///
    /// **Dart Source:** `box_fit.dart:44-50`
    case fitWidth

    /// Make sure the full height of the source is shown, regardless of
    /// whether this means the source overflows the target box horizontally.
    ///
    /// To actually clip the content, use `clipBehavior: Clip.hardEdge` alongside
    /// this in a `FittedBox`.
    ///
    /// **Dart Source:** `box_fit.dart:52-58`
    case fitHeight

    /// Align the source within the target box (by default, centering) and discard
    /// any portions of the source that lie outside the box.
    ///
    /// The source image is not resized.
    ///
    /// To actually clip the content, use `clipBehavior: Clip.hardEdge` alongside
    /// this in a `FittedBox`.
    ///
    /// **Dart Source:** `box_fit.dart:60-68`
    case none

    /// Align the source within the target box (by default, centering) and, if
    /// necessary, scale the source down to ensure that the source fits within the
    /// box.
    ///
    /// This is the same as ``contain`` if that would shrink the image, otherwise it
    /// is the same as ``none``.
    ///
    /// **Dart Source:** `box_fit.dart:70-78`
    case scaleDown
}

// MARK: - FittedSizes
/// The pair of sizes returned by ``applyBoxFit(_:_:_:)``.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/box_fit.dart`
/// **Original Name:** `FittedSizes`
/// **Lines:** 82-93
public struct FittedSizes: Equatable, Sendable {
    /// The size of the part of the input to show on the output.
    ///
    /// **Dart Source:** `box_fit.dart:88-89`
    public let source: Size

    /// The size of the part of the output on which to show the input.
    ///
    /// **Dart Source:** `box_fit.dart:91-92`
    public let destination: Size

    /// Creates an object to store a pair of sizes,
    /// as would be returned by ``applyBoxFit(_:_:_:)``.
    ///
    /// **Dart Source:** `box_fit.dart:84-86`
    public init(source: Size, destination: Size) {
        self.source = source
        self.destination = destination
    }
}

// MARK: - applyBoxFit
/// Apply a ``BoxFit`` value.
///
/// The arguments to this method, in addition to the ``BoxFit`` value to apply,
/// are two sizes, ostensibly the sizes of an input box and an output box.
/// Specifically, the `inputSize` argument gives the size of the complete source
/// that is being fitted, and the `outputSize` gives the size of the rectangle
/// into which the source is to be drawn.
///
/// This function then returns two sizes, combined into a single ``FittedSizes``
/// object.
///
/// The ``FittedSizes/source`` size is the subpart of the `inputSize` that is to
/// be shown. If the entire input source is shown, then this will equal the
/// `inputSize`, but if the input source is to be cropped down, this may be
/// smaller.
///
/// The ``FittedSizes/destination`` size is the subpart of the `outputSize` in
/// which to paint the (possibly cropped) source. If the
/// ``FittedSizes/destination`` size is smaller than the `outputSize` then the
/// source is being letterboxed (or pillarboxed).
///
/// This method does not express an opinion regarding the alignment of the
/// source and destination sizes within the input and output rectangles.
/// Typically they are centered (this is what `BoxDecoration` does, for
/// instance, and is how ``BoxFit`` is defined). The `Alignment` class provides a
/// convenience function, `Alignment.inscribe`, for resolving the sizes to
/// rects.
///
/// See also:
///
///  * `FittedBox`, a widget that applies this algorithm to another widget.
///  * `paintImage`, a function that applies this algorithm to images for painting.
///  * `DecoratedBox`, `BoxDecoration`, and `DecorationImage`, which together
///    provide access to `paintImage` at the widgets layer.
///
/// **Dart Source:** `packages/flutter/lib/src/painting/box_fit.dart`
/// **Original Name:** `applyBoxFit`
/// **Lines:** 146-229
public func applyBoxFit(_ fit: BoxFit, _ inputSize: Size, _ outputSize: Size) -> FittedSizes {
    // Handle zero or negative sizes
    // **Dart Source:** `box_fit.dart:147-152`
    if inputSize.height <= 0.0 ||
       inputSize.width <= 0.0 ||
       outputSize.height <= 0.0 ||
       outputSize.width <= 0.0 {
        return FittedSizes(source: Size.zero, destination: Size.zero)
    }

    let sourceSize: Size
    let destinationSize: Size

    switch fit {
    case .fill:
        // **Dart Source:** `box_fit.dart:156-158`
        sourceSize = inputSize
        destinationSize = outputSize

    case .contain:
        // **Dart Source:** `box_fit.dart:159-171`
        sourceSize = inputSize
        if outputSize.width / outputSize.height > sourceSize.width / sourceSize.height {
            destinationSize = Size(
                sourceSize.width * outputSize.height / sourceSize.height,
                outputSize.height
            )
        } else {
            destinationSize = Size(
                outputSize.width,
                sourceSize.height * outputSize.width / sourceSize.width
            )
        }

    case .cover:
        // **Dart Source:** `box_fit.dart:172-181`
        if outputSize.width / outputSize.height > inputSize.width / inputSize.height {
            sourceSize = Size(
                inputSize.width,
                inputSize.width * outputSize.height / outputSize.width
            )
        } else {
            sourceSize = Size(
                inputSize.height * outputSize.width / outputSize.height,
                inputSize.height
            )
        }
        destinationSize = outputSize

    case .fitWidth:
        // **Dart Source:** `box_fit.dart:182-194`
        if outputSize.width / outputSize.height > inputSize.width / inputSize.height {
            // Like "cover"
            sourceSize = Size(
                inputSize.width,
                inputSize.width * outputSize.height / outputSize.width
            )
            destinationSize = outputSize
        } else {
            // Like "contain"
            sourceSize = inputSize
            destinationSize = Size(
                outputSize.width,
                sourceSize.height * outputSize.width / sourceSize.width
            )
        }

    case .fitHeight:
        // **Dart Source:** `box_fit.dart:195-210`
        if outputSize.width / outputSize.height > inputSize.width / inputSize.height {
            // Like "contain"
            sourceSize = inputSize
            destinationSize = Size(
                sourceSize.width * outputSize.height / sourceSize.height,
                outputSize.height
            )
        } else {
            // Like "cover"
            sourceSize = Size(
                inputSize.height * outputSize.width / outputSize.height,
                inputSize.height
            )
            destinationSize = outputSize
        }

    case .none:
        // **Dart Source:** `box_fit.dart:211-216`
        sourceSize = Size(
            min(inputSize.width, outputSize.width),
            min(inputSize.height, outputSize.height)
        )
        destinationSize = sourceSize

    case .scaleDown:
        // **Dart Source:** `box_fit.dart:217-227`
        sourceSize = inputSize
        var scaledDestination = inputSize
        let aspectRatio = inputSize.width / inputSize.height
        if scaledDestination.height > outputSize.height {
            scaledDestination = Size(
                outputSize.height * aspectRatio,
                outputSize.height
            )
        }
        if scaledDestination.width > outputSize.width {
            scaledDestination = Size(
                outputSize.width,
                outputSize.width / aspectRatio
            )
        }
        destinationSize = scaledDestination
    }

    return FittedSizes(source: sourceSize, destination: destinationSize)
}
