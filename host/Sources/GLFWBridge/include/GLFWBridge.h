// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Umbrella header that exposes GLFW3 to Swift.
// GLFW_INCLUDE_NONE prevents transitive inclusion of <GL/gl.h> which
// can conflict with EGL/GLES headers used by the Flutter engine.

#ifndef GLFW_BRIDGE_H_
#define GLFW_BRIDGE_H_

#define GLFW_INCLUDE_NONE
#include "../../../.deps/include/GLFW/glfw3.h"

#endif  // GLFW_BRIDGE_H_
