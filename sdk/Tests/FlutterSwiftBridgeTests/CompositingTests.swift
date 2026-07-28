// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Migrated from: engine/src/flutter/testing/dart/compositing_test.dart

import Testing
@testable import FlutterSwiftBridge

// MARK: - Helper Functions

/// Creates a simple Picture with a single drawPaint call.
///
/// **Dart Source:** `compositing_test.dart:12-16`
/// The Dart tests create pictures using:
/// ```dart
/// final PictureRecorder recorder = PictureRecorder();
/// final Canvas canvas = Canvas(recorder);
/// canvas.drawPaint(Paint()..color = color);
/// final Picture picture = recorder.endRecording();
/// ```
///
/// This helper encapsulates that pattern for Swift tests.
private func createSimplePicture(color: Color = Color(0xFF123456)) -> any Picture {
    let recorder = NativePictureRecorder()
    let canvas = NativeCanvas(recorder: recorder)
    let paint = Paint()
    paint.color = color
    canvas.drawPaint(paint)
    return recorder.endRecording()
}

/// Creates a 16-element identity matrix as [Double].
///
/// **Dart Source:** `compositing_test.dart:82-99`
/// The Dart tests use:
/// ```dart
/// Float64List.fromList(<double>[
///   1, 0, 0, 0,
///   0, 1, 0, 0,
///   0, 0, 1, 0,
///   0, 0, 0, 1,
/// ])
/// ```
///
/// This is the standard 4x4 identity matrix in column-major order.
private func createIdentityMatrix4() -> [Double] {
    return [
        1, 0, 0, 0,  // Column 0
        0, 1, 0, 0,  // Column 1
        0, 0, 1, 0,  // Column 2
        0, 0, 0, 1   // Column 3
    ]
}

// MARK: - Compositing Tests

/// Tests for Flutter's compositing APIs (Scene, SceneBuilder, EngineLayer).
///
/// **Dart Source:** `engine/src/flutter/testing/dart/compositing_test.dart`
///
/// These tests verify the Swift implementation of Scene, SceneBuilder, and
/// related compositing types work correctly. Some tests are adapted from
/// the original Dart tests due to differences in assertion behavior between
/// Swift and Dart.
@Suite("Compositing Tests")
struct CompositingTests {
    // MARK: Scene Tests

    /// Tests that building a scene with pushOffset and addPicture succeeds.
    ///
    /// **Dart Source:** `compositing_test.dart:11-37` - 'Scene.toImageSync succeeds'
    ///
    /// **Adapted for Swift:** The original Dart test creates a scene with a picture,
    /// calls `scene.toImageSync(6, 8)` to render it to an image, and verifies the
    /// image dimensions and pixel data. Since `Scene.toImageSync` requires full
    /// engine integration (SnapshotDelegate + task runners) which is not yet
    /// available, this test verifies:
    /// - A Picture can be created using PictureRecorder and Canvas
    /// - A Scene can be built using SceneBuilder with pushOffset + addPicture
    /// - scene.build() returns a Scene without crash
    /// - scene.dispose() can be called without crash
    ///
    /// **Dart test code:**
    /// ```dart
    /// test('Scene.toImageSync succeeds', () async {
    ///   final PictureRecorder recorder = PictureRecorder();
    ///   final Canvas canvas = Canvas(recorder);
    ///   const Color color = Color(0xFF123456);
    ///   canvas.drawPaint(Paint()..color = color);
    ///   final Picture picture = recorder.endRecording();
    ///   final SceneBuilder builder = SceneBuilder();
    ///   builder.pushOffset(10, 10);
    ///   builder.addPicture(const Offset(5, 5), picture);
    ///   final Scene scene = builder.build();
    ///   // ... toImageSync and pixel verification ...
    ///   picture.dispose();
    ///   scene.dispose();
    /// });
    /// ```
    ///
    /// **Engine Integration Note:**
    /// Scene.toImageSync requires:
    /// - UIDartState's SnapshotDelegate for GPU rasterization
    /// - TaskRunners for scheduling the snapshot operation
    /// - DeferredImage creation from the rasterized texture
    /// These components are part of the full Flutter engine integration layer
    /// that is not yet available in the Swift bridge tests.
    @Test("Scene with pushOffset and addPicture builds successfully")
    func testSceneToImageSyncDimensionsValidation() {
        // Create a simple Picture with a solid color fill
        // This mirrors the Dart test: compositing_test.dart:12-16
        let picture = createSimplePicture(color: Color(0xFF123456))

        // Verify picture was created successfully
        #expect(!picture.debugDisposed)

        // Build a Scene with the picture
        // This mirrors the Dart test: compositing_test.dart:17-20
        let builder = NativeSceneBuilder()
        let offsetLayer = builder.pushOffset(10, 10)

        // Verify the offset layer was created
        #expect(offsetLayer._nativeLayer != nil)

        // Add the picture to the scene
        builder.addPicture(Offset(5, 5), picture: picture, isComplexHint: false, willChangeHint: false)

        // Pop the offset layer
        builder.pop()

        // Build the scene - this should succeed without crash
        let scene = builder.build()

        // Verify the scene was created successfully
        // In Dart, scene is an instance of Scene (abstract class)
        // In Swift, scene conforms to the Scene protocol
        #expect(scene is NativeScene)

        // Dispose of picture and scene
        // This mirrors the Dart test: compositing_test.dart:23-24
        picture.dispose()
        scene.dispose()

        // Verify picture is disposed
        #expect(picture.debugDisposed)
    }

    /// Tests that building a scene with a texture layer succeeds.
    ///
    /// **Dart Source:** `compositing_test.dart:39-59` - 'Scene.toImageSync succeeds with texture layer'
    ///
    /// **Adapted for Swift:** The original Dart test creates a scene with a texture layer,
    /// calls `scene.toImageSync(20, 20)` to render it to an image, and verifies the
    /// image dimensions and pixel data (all zeros since texture ID 0 doesn't exist).
    /// Since `Scene.toImageSync` requires full engine integration which is not yet
    /// available, this test verifies:
    /// - A Scene can be built using SceneBuilder with pushOffset + addTexture
    /// - addTexture with textureId=0, width=10, height=10 works
    /// - scene.build() returns a Scene without crash
    /// - scene.dispose() can be called without crash
    ///
    /// **Dart test code:**
    /// ```dart
    /// test('Scene.toImageSync succeeds with texture layer', () async {
    ///   final SceneBuilder builder = SceneBuilder();
    ///   builder.pushOffset(10, 10);
    ///   builder.addTexture(0, width: 10, height: 10);
    ///
    ///   final Scene scene = builder.build();
    ///   final Image image = scene.toImageSync(20, 20);
    ///   scene.dispose();
    ///   // ... image verification ...
    /// });
    /// ```
    ///
    /// **Engine Integration Note:**
    /// Scene.toImageSync requires full engine integration (SnapshotDelegate, TaskRunners).
    /// Actual texture rendering would require a registered texture with the given ID.
    /// This test verifies that the scene graph construction with textures works correctly.
    @Test("Scene with texture layer builds successfully")
    func testSceneWithTextureLayer() {
        // Create a SceneBuilder
        // This mirrors the Dart test: compositing_test.dart:40
        let builder = NativeSceneBuilder()

        // Push an offset layer
        // This mirrors the Dart test: compositing_test.dart:41
        let offsetLayer = builder.pushOffset(10, 10)

        // Verify the offset layer was created
        #expect(offsetLayer._nativeLayer != nil)

        // Add a texture to the scene
        // This mirrors the Dart test: compositing_test.dart:42
        // Note: textureId=0 is used, which doesn't correspond to any actual texture,
        // but the scene building should still succeed
        builder.addTexture(0, width: 10, height: 10)

        // Pop the offset layer
        builder.pop()

        // Build the scene - this should succeed without crash
        // This mirrors the Dart test: compositing_test.dart:44
        let scene = builder.build()

        // Verify the scene was created successfully
        #expect(scene is NativeScene)

        // Dispose of the scene
        // This mirrors the Dart test: compositing_test.dart:46
        scene.dispose()

        // Note: In a full engine integration test, we would also verify:
        // - scene.toImageSync(20, 20) creates an Image of correct dimensions
        // - The texture area renders correctly (zeros for non-existent texture)
        // These require SnapshotDelegate and TaskRunners which are not yet available.
    }

    // MARK: SceneBuilder Validation Tests

    /// Tests that Picture.dispose() sets debugDisposed flag and that a non-disposed picture works.
    ///
    /// **Dart Source:** `compositing_test.dart:61-78` - 'addPicture with disposed picture does not crash'
    ///
    /// **Adapted for Swift:** The original Dart test verifies that calling `addPicture` with a
    /// disposed picture throws an `AssertionError`. In Swift, assertions use `assert()` which
    /// traps (crashes) in debug mode rather than throwing a catchable exception.
    ///
    /// This test verifies:
    /// 1. A Picture can be created and disposed
    /// 2. `picture.debugDisposed` returns true after dispose
    /// 3. Building a scene with a non-disposed picture succeeds (positive path)
    ///
    /// **Dart test code:**
    /// ```dart
    /// test('addPicture with disposed picture does not crash', () {
    ///   final PictureRecorder recorder = PictureRecorder();
    ///   final Canvas canvas = Canvas(recorder);
    ///   canvas.drawPaint(Paint());
    ///   final Picture picture = recorder.endRecording();
    ///   picture.dispose();
    ///
    ///   expect(picture.debugDisposed, isTrue);
    ///
    ///   final SceneBuilder builder = SceneBuilder();
    ///   expect(
    ///     () => builder.addPicture(Offset.zero, picture),
    ///     throwsA(const isInstanceOf<AssertionError>()),
    ///   );
    ///
    ///   final Scene scene = builder.build();
    ///   scene.dispose();
    /// });
    /// ```
    ///
    /// **DIFFERENCE FROM DART:** Swift assertions trap (crash) instead of throwing catchable
    /// exceptions. We cannot test that addPicture(disposed picture) triggers an assertion
    /// without crashing the test process. Instead, we verify the debugDisposed flag works
    /// correctly and document the expected assertion behavior.
    ///
    /// **Expected Behavior (documented, not tested):**
    /// Calling `builder.addPicture(offset, picture: disposedPicture)` with a disposed picture
    /// triggers an assertion failure with message: "Picture is disposed."
    /// This is a debug-only check (assert) that will crash in debug builds but is stripped
    /// in release builds.
    @Test("Picture.dispose sets debugDisposed flag")
    func testAddPictureWithDisposedPicture() {
        // Create a Picture
        // This mirrors the Dart test: compositing_test.dart:62-65
        let recorder = NativePictureRecorder()
        let canvas = NativeCanvas(recorder: recorder)
        canvas.drawPaint(Paint())
        let picture = recorder.endRecording()

        // Verify picture is not disposed initially
        #expect(!picture.debugDisposed)

        // Dispose the picture
        // This mirrors the Dart test: compositing_test.dart:66
        picture.dispose()

        // Verify picture is disposed
        // This mirrors the Dart test: compositing_test.dart:68
        #expect(picture.debugDisposed)

        // Note: In Dart, the test verifies that calling addPicture with a disposed picture
        // throws an AssertionError. In Swift, this would trigger an assert() which traps
        // (crashes) in debug mode. We cannot test this behavior without crashing the test.
        //
        // The Swift implementation should have:
        //   assert(!picture.debugDisposed, "Picture is disposed.")
        // in the addPicture method.

        // Test positive path: verify a non-disposed picture works with addPicture
        let validPicture = createSimplePicture()
        #expect(!validPicture.debugDisposed)

        let builder = NativeSceneBuilder()
        builder.addPicture(Offset.zero, picture: validPicture, isComplexHint: false, willChangeHint: false)
        let scene = builder.build()

        // Verify scene was built successfully
        #expect(scene is NativeScene)

        // Clean up
        validPicture.dispose()
        scene.dispose()

        #expect(validPicture.debugDisposed)
    }

    /// Tests that pushTransform works correctly with a valid 4x4 identity matrix.
    ///
    /// **Dart Source:** `compositing_test.dart:80-159` - 'pushTransform validates the matrix'
    ///
    /// **Adapted for Swift:** The original Dart test verifies that:
    /// 1. A valid 16-element identity matrix returns a non-null TransformEngineLayer
    /// 2. A matrix with wrong length (14 elements) throws AssertionError
    /// 3. A matrix with NaN values throws AssertionError
    /// 4. A matrix with Infinity values throws AssertionError
    ///
    /// Since Swift assertions trap (crash) instead of throwing catchable exceptions,
    /// this test only verifies the positive path (valid matrix succeeds).
    ///
    /// **Dart test code:**
    /// ```dart
    /// test('pushTransform validates the matrix', () {
    ///   final SceneBuilder builder = SceneBuilder();
    ///   final Float64List matrix4 = Float64List.fromList(<double>[
    ///     1, 0, 0, 0,
    ///     0, 1, 0, 0,
    ///     0, 0, 1, 0,
    ///     0, 0, 0, 1,
    ///   ]);
    ///   expect(builder.pushTransform(matrix4), isNotNull);
    ///
    ///   // ... invalid matrix tests that throw AssertionError ...
    /// });
    /// ```
    ///
    /// **DIFFERENCE FROM DART:** Swift assertions trap (crash) instead of throwing catchable
    /// exceptions. We cannot test that pushTransform(invalidMatrix) triggers an assertion
    /// without crashing the test process. Instead, we verify the valid path works and
    /// document the expected assertion behavior for invalid inputs.
    ///
    /// **Expected Assertion Behavior (documented, not tested):**
    /// The Swift implementation validates the matrix with `matrix4IsValid()` helper which
    /// uses assertions to verify:
    /// - Matrix has exactly 16 elements: `assert(matrix4.count == 16, "Matrix4 must have 16 entries.")`
    /// - All elements are finite: `assert(element.isFinite, "Matrix4 entries must be finite.")`
    ///
    /// **Invalid Cases (from Dart test):**
    /// 1. Wrong length (14 elements): triggers assertion
    ///    ```dart
    ///    Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0])
    ///    ```
    /// 2. NaN value at position 15: triggers assertion
    ///    ```dart
    ///    Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, double.nan])
    ///    ```
    /// 3. Infinity value at position 15: triggers assertion
    ///    ```dart
    ///    Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, double.infinity])
    ///    ```
    @Test("pushTransform with valid matrix returns TransformEngineLayer")
    func testPushTransformValidatesMatrix() {
        // Create a SceneBuilder
        let builder = NativeSceneBuilder()

        // Create a valid 16-element identity matrix
        // This mirrors the Dart test: compositing_test.dart:82-99
        let matrix4 = createIdentityMatrix4()

        // Push transform with valid matrix - should return non-nil TransformEngineLayer
        // This mirrors the Dart test: compositing_test.dart:100
        let transformLayer = builder.pushTransform(matrix4)

        // Verify the TransformEngineLayer was created (equivalent to Dart's isNotNull)
        #expect(transformLayer._nativeLayer != nil)

        // Pop the transform layer
        builder.pop()

        // Build the scene to complete the test
        let scene = builder.build()

        // Verify scene was built successfully
        #expect(scene is NativeScene)

        // Clean up
        scene.dispose()
    }

    // MARK: Layer Reuse Tests

    /// Tests that SceneBuilder accepts typed layers for layer reuse with oldLayer parameter.
    ///
    /// **Dart Source:** `compositing_test.dart:161-173` - 'SceneBuilder accepts typed layers'
    ///
    /// This test verifies that:
    /// 1. SceneBuilder.pushOpacity returns a non-nil OpacityEngineLayer
    /// 2. The returned OpacityEngineLayer can be passed as oldLayer to a subsequent pushOpacity call
    /// 3. Both scenes build successfully
    ///
    /// **Dart test code:**
    /// ```dart
    /// test('SceneBuilder accepts typed layers', () {
    ///   final SceneBuilder builder1 = SceneBuilder();
    ///   final OpacityEngineLayer opacity1 = builder1.pushOpacity(100);
    ///   expect(opacity1, isNotNull);
    ///   builder1.pop();
    ///   builder1.build();
    ///
    ///   final SceneBuilder builder2 = SceneBuilder();
    ///   final OpacityEngineLayer opacity2 = builder2.pushOpacity(200, oldLayer: opacity1);
    ///   expect(opacity2, isNotNull);
    ///   builder2.pop();
    ///   builder2.build();
    /// });
    /// ```
    ///
    /// **Layer Reuse Concept:**
    /// When building consecutive frames, layers from a previous frame can be reused
    /// via the `oldLayer` parameter. This allows the engine to optimize rendering by
    /// updating existing layers rather than creating new ones. The typed layer system
    /// (OpacityEngineLayer, TransformEngineLayer, etc.) ensures type safety so that
    /// only compatible layers can be reused (e.g., an OpacityEngineLayer can only be
    /// passed as oldLayer to pushOpacity, not to pushTransform).
    @Test("SceneBuilder accepts typed layers for reuse")
    func testSceneBuilderAcceptsTypedLayers() {
        // Create first scene builder
        // This mirrors the Dart test: compositing_test.dart:162
        let builder1 = NativeSceneBuilder()

        // Push opacity with alpha=100, returns OpacityEngineLayer
        // This mirrors the Dart test: compositing_test.dart:163
        let opacity1 = builder1.pushOpacity(100)

        // Verify the OpacityEngineLayer was created (equivalent to Dart's isNotNull)
        // This mirrors the Dart test: compositing_test.dart:164
        #expect(opacity1._nativeLayer != nil)

        // Pop the opacity layer
        // This mirrors the Dart test: compositing_test.dart:165
        builder1.pop()

        // Build the first scene
        // This mirrors the Dart test: compositing_test.dart:166
        let scene1 = builder1.build()

        // Verify scene1 was built successfully
        #expect(scene1 is NativeScene)

        // Create second scene builder
        // This mirrors the Dart test: compositing_test.dart:168
        let builder2 = NativeSceneBuilder()

        // Push opacity with alpha=200, reusing opacity1 as oldLayer
        // This mirrors the Dart test: compositing_test.dart:169
        let opacity2 = builder2.pushOpacity(200, oldLayer: opacity1)

        // Verify the new OpacityEngineLayer was created (equivalent to Dart's isNotNull)
        // This mirrors the Dart test: compositing_test.dart:170
        #expect(opacity2._nativeLayer != nil)

        // Pop the opacity layer
        // This mirrors the Dart test: compositing_test.dart:171
        builder2.pop()

        // Build the second scene
        // This mirrors the Dart test: compositing_test.dart:172
        let scene2 = builder2.build()

        // Verify scene2 was built successfully
        #expect(scene2 is NativeScene)

        // Clean up
        scene1.dispose()
        scene2.dispose()
    }

    // MARK: Layer Sharing Tests

    /// Tests that valid layer reuse works correctly and documents layer sharing assertions.
    ///
    /// **Dart Source:** `compositing_test.dart:419-526` - 'SceneBuilder does not share a layer between addRetained and push*'
    ///
    /// **Adapted for Swift:** The original Dart test uses the `testNoSharing` helper function
    /// which runs 9 different sub-tests, each expecting an `AssertionError` to be thrown when
    /// layers are shared incorrectly between `addRetained` and `push*` methods.
    ///
    /// Since Swift assertions trap (crash) instead of throwing catchable exceptions, we:
    /// 1. Test the POSITIVE case: verify that a layer CAN be used once correctly as `oldLayer`
    /// 2. Document all 9 assertion cases that trigger in the Dart version
    ///
    /// **Dart test code structure:**
    /// ```dart
    /// test('SceneBuilder does not share a layer between addRetained and push*', () {
    ///   testNoSharing((SceneBuilder builder, EngineLayer? oldLayer) {
    ///     return builder.pushOffset(0, 0, oldLayer: oldLayer as OffsetEngineLayer?);
    ///   });
    ///   // ... repeated for pushTransform, pushClipRect, pushOpacity, etc.
    /// });
    ///
    /// void testNoSharing(_TestNoSharingFunction pushFunction) {
    ///   testPushThenIllegalRetain(pushFunction);       // Case 1
    ///   testAddRetainedThenIllegalPush(pushFunction);  // Case 2
    ///   testDoubleAddRetained(pushFunction);           // Case 3
    ///   testPushOldLayerTwice(pushFunction);           // Case 4
    ///   testPushChildLayerOfRetainedLayer(pushFunction); // Case 5
    ///   testRetainParentLayerOfPushedChild(pushFunction); // Case 6
    ///   testRetainOldLayer(pushFunction);              // Case 7
    ///   testPushOldLayer(pushFunction);                // Case 8
    ///   testRetainsParentOfOldLayer(pushFunction);     // Case 9
    /// }
    /// ```
    ///
    /// **DIFFERENCE FROM DART:** Swift assertions trap (crash) instead of throwing catchable
    /// exceptions. We cannot test that invalid layer sharing triggers assertions without crashing
    /// the test process. Instead, we verify the valid path works and document all 9 assertion cases.
    ///
    /// **Assertion Cases (documented, not tested):**
    ///
    /// **Case 1: testPushThenIllegalRetain** (`compositing_test.dart:176-199`)
    /// Using same layer as oldLayer then in addRetained in the same scene.
    /// ```dart
    /// final SceneBuilder builder2 = SceneBuilder();
    /// pushFunction(builder2, layer);  // Use as oldLayer
    /// builder2.pop();
    /// builder2.addRetained(layer);    // ERROR: "The layer is already being used"
    /// ```
    ///
    /// **Case 2: testAddRetainedThenIllegalPush** (`compositing_test.dart:201-224`)
    /// Using same layer in addRetained then as oldLayer in the same scene.
    /// ```dart
    /// final SceneBuilder builder2 = SceneBuilder();
    /// builder2.addRetained(layer);    // Retain the layer
    /// pushFunction(builder2, layer);  // ERROR: "The layer is already being used"
    /// ```
    ///
    /// **Case 3: testDoubleAddRetained** (`compositing_test.dart:226-248`)
    /// Double addRetained with same layer in the same scene.
    /// ```dart
    /// final SceneBuilder builder2 = SceneBuilder();
    /// builder2.addRetained(layer);    // First retain
    /// builder2.addRetained(layer);    // ERROR: "The layer is already being used"
    /// ```
    ///
    /// **Case 4: testPushOldLayerTwice** (`compositing_test.dart:250-272`)
    /// Using oldLayer twice in same scene.
    /// ```dart
    /// final SceneBuilder builder2 = SceneBuilder();
    /// pushFunction(builder2, layer);  // First use as oldLayer
    /// pushFunction(builder2, layer);  // ERROR: "was previously used as oldLayer"
    /// ```
    ///
    /// **Case 5: testPushChildLayerOfRetainedLayer** (`compositing_test.dart:274-298`)
    /// Using child of retained layer as oldLayer.
    /// ```dart
    /// // Build scene with parent layer containing child layer
    /// final SceneBuilder builder2 = SceneBuilder();
    /// builder2.addRetained(parentLayer);           // Retain parent (includes child)
    /// builder2.pushOpacity(321, oldLayer: childLayer); // ERROR: "The layer is already being used"
    /// ```
    ///
    /// **Case 6: testRetainParentLayerOfPushedChild** (`compositing_test.dart:300-325`)
    /// Retaining parent after child used as oldLayer.
    /// ```dart
    /// final SceneBuilder builder2 = SceneBuilder();
    /// builder2.pushOpacity(234, oldLayer: childLayer); // Use child as oldLayer
    /// builder2.pop();
    /// builder2.addRetained(parentLayer);  // ERROR: "The layer is already being used"
    /// ```
    ///
    /// **Case 7: testRetainOldLayer** (`compositing_test.dart:327-351`)
    /// Retaining layer that was used as oldLayer in previous frame.
    /// ```dart
    /// final SceneBuilder builder2 = SceneBuilder();
    /// pushFunction(builder2, layer);  // Use as oldLayer
    /// builder2.pop();
    /// final SceneBuilder builder3 = SceneBuilder();
    /// builder3.addRetained(layer);    // ERROR: "was previously used as oldLayer"
    /// ```
    ///
    /// **Case 8: testPushOldLayer** (`compositing_test.dart:353-377`)
    /// Using layer as oldLayer that was already used as oldLayer in previous frame.
    /// ```dart
    /// final SceneBuilder builder2 = SceneBuilder();
    /// pushFunction(builder2, layer);  // Use as oldLayer in frame 2
    /// builder2.pop();
    /// final SceneBuilder builder3 = SceneBuilder();
    /// pushFunction(builder3, layer);  // ERROR: "was previously used as oldLayer"
    /// ```
    ///
    /// **Case 9: testRetainsParentOfOldLayer** (`compositing_test.dart:379-405`)
    /// Retaining parent of layer used as oldLayer in previous frame.
    /// ```dart
    /// final SceneBuilder builder2 = SceneBuilder();
    /// builder2.pushOpacity(321, oldLayer: childLayer); // Use child as oldLayer
    /// builder2.pop();
    /// final SceneBuilder builder3 = SceneBuilder();
    /// builder3.addRetained(parentLayer);  // ERROR: "was previously used as oldLayer"
    /// ```
    @Test("Valid layer reuse as oldLayer succeeds")
    func testLayerSharingPrevention() {
        // Test the POSITIVE case: verify that a layer CAN be used once correctly as oldLayer
        // This is equivalent to the first part of each Dart testNoSharing sub-test before
        // the assertion-triggering code.

        // Create first scene with an offset layer
        // This mirrors the pattern from compositing_test.dart:177-180
        let builder1 = NativeSceneBuilder()
        let layer = builder1.pushOffset(0, 0)
        builder1.pop()
        let scene1 = builder1.build()

        // Verify the layer was created successfully
        #expect(layer._nativeLayer != nil)

        // Create second scene reusing the layer as oldLayer
        // This mirrors the pattern from compositing_test.dart:182-184
        let builder2 = NativeSceneBuilder()
        let newLayer = builder2.pushOffset(10, 20, oldLayer: layer)
        builder2.pop()
        let scene2 = builder2.build()

        // Verify the new layer was created successfully (valid reuse)
        #expect(newLayer._nativeLayer != nil)

        // Verify both scenes were built successfully
        #expect(scene1 is NativeScene)
        #expect(scene2 is NativeScene)

        // Clean up
        scene1.dispose()
        scene2.dispose()

        // Note: The 9 assertion cases documented above cannot be tested in Swift because
        // Swift's assert() traps (crashes) in debug mode rather than throwing a catchable
        // exception like Dart's AssertionError.
        //
        // In a debug build, the Swift implementation should have assertions like:
        //   assert(!layer._alreadyUsed, "The layer is already being used.")
        //   assert(!layer._previouslyUsedAsOldLayer, "Layer was previously used as oldLayer.")
        //
        // These assertions provide the same safety guarantees as the Dart version,
        // catching programming errors during development.
    }
}
