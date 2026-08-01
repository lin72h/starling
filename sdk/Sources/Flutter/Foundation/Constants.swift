// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// MARK: - Build Mode Constants
/// Build mode constants for conditional compilation.
///
/// **Dart Source:** `packages/flutter/lib/src/foundation/constants.dart`
/// **Lines:** 8-64

/// A constant that is true if the application was compiled in release mode.
///
/// Since this is a compile-time constant, it can be used to indicate to the compiler that
/// a particular block of code will not be executed in release mode, and hence
/// can be removed.
///
/// Generally it is better to use `kDebugMode` or `assert` to gate code, since
/// using `kReleaseMode` will introduce differences between release and profile
/// builds, which makes performance testing less representative.
///
/// **Dart Source:** `constants.dart:8-25`
#if DEBUG
public let kReleaseMode: Bool = false
#else
public let kReleaseMode: Bool = true
#endif

/// A constant that is true if the application was compiled in profile mode.
///
/// Since this is a compile-time constant, it can be used to indicate to the compiler that
/// a particular block of code will not be executed in profile mode, and hence
/// can be removed.
///
/// **Dart Source:** `constants.dart:27-40`
///
/// Note: Swift does not have a built-in profile mode concept. This is always false.
/// For profiling, use Instruments or other profiling tools.
public let kProfileMode: Bool = false

/// A constant that is true if the application was compiled in debug mode.
///
/// Since this is a compile-time constant, it can be used to indicate to the compiler that
/// a particular block of code will not be executed in debug mode, and hence
/// can be removed.
///
/// **Dart Source:** `constants.dart:42-64`
#if DEBUG
public let kDebugMode: Bool = true
#else
public let kDebugMode: Bool = false
#endif

// MARK: - Precision Tolerance
/// The epsilon of tolerable double precision error.
///
/// This is used in various places in the framework to allow for floating point
/// precision loss in calculations. Differences below this threshold are safe to
/// disregard.
///
/// **Dart Source:** `constants.dart:66-71`
public let precisionErrorTolerance: Double = 1e-10

// MARK: - Platform Constants
/// A constant that is true if the application was compiled to run on the web.
///
/// **Dart Source:** `constants.dart:73-83`
///
/// Note: In Swift, this is always false since we're targeting native platforms.
public let kIsWeb: Bool = false

/// A constant that is true if the application was compiled to WebAssembly.
///
/// **Dart Source:** `constants.dart:85-95`
///
/// Note: In Swift, this is always false since we're targeting native platforms.
public let kIsWasm: Bool = false
