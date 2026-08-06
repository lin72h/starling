// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "include/FlutterWin32Bridge.h"

#include <stdio.h>
#include <stdlib.h>

// Before <windows.h>: this file calls the -W entry points throughout, and the
// resource macros follow UNICODE rather than the call. Without it IDC_ARROW
// expands to MAKEINTRESOURCEA — an LPSTR — and passing that to LoadCursorW is
// a pointer-type mismatch the compiler only warns about.
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>

// Direct inclusion of the vendored embedder headers, the same way the GTK
// bridge includes flutter_linux. Their cross-references are quoted-relative,
// so no include path is needed.
#include "flutter_windows/flutter_windows.h"

// The engine's own Win32 embedder owns the child window; ours is only the
// top-level frame that hosts it, so the state here is small.
struct FlWin32Host {
  HWND window;
  HWND child;  // the view's HWND, owned by the view controller
  FlutterDesktopViewControllerRef controller;
  int fullscreen;
  WINDOWPLACEMENT saved_placement;  // to restore from fullscreen
};

static const wchar_t kWindowClass[] = L"FlutterSwiftWin32Host";

// Timer draining libdispatch's main queue so @MainActor code and
// DispatchQueue.main.async blocks run on the Win32 message thread. Same
// arrangement as the GTK host's GLib timer. Resolved dynamically because the
// symbol is a libdispatch implementation detail with no public header.
#define kDrainTimerId 1
#define kDrainTimerMs 8

static void drain_gcd_main_queue(void) {
  static void (*drain)(void*) = NULL;
  static int looked_up = 0;
  if (!looked_up) {
    looked_up = 1;
    // Swift on Windows ships libdispatch as dispatch.dll. GetModuleHandleW,
    // not LoadLibrary: if it is not already loaded nothing has queued work,
    // and loading a second copy would be worse than doing nothing.
    HMODULE d = GetModuleHandleW(L"dispatch.dll");
    if (d != NULL) {
      drain = (void (*)(void*))GetProcAddress(
          d, "_dispatch_main_queue_callback_4CF");
    }
  }
  if (drain != NULL) {
    drain(NULL);
  }
}

static LRESULT CALLBACK host_wnd_proc(HWND hwnd,
                                      UINT message,
                                      WPARAM wparam,
                                      LPARAM lparam) {
  FlWin32Host* host =
      (FlWin32Host*)GetWindowLongPtrW(hwnd, GWLP_USERDATA);

  if (host != NULL && host->controller != NULL) {
    // Give the engine and any plugins first refusal — this is what routes
    // keyboard, IME and accessibility messages the embedder cares about.
    LRESULT result = 0;
    if (FlutterDesktopViewControllerHandleTopLevelWindowProc(
            host->controller, hwnd, message, wparam, lparam, &result)) {
      return result;
    }
  }

  switch (message) {
    case WM_SIZE:
      // Keep the engine's child window filling the frame.
      if (host != NULL && host->child != NULL) {
        RECT frame;
        GetClientRect(hwnd, &frame);
        MoveWindow(host->child, 0, 0, frame.right - frame.left,
                   frame.bottom - frame.top, TRUE);
      }
      return 0;

    case WM_SETFOCUS:
      // Hand keyboard focus down to the engine's view. Activating the frame
      // focuses the frame, and the view is a child window — without this the
      // key messages are delivered to a window the embedder is not listening
      // on, so the app renders and takes mouse input but silently ignores
      // every keystroke. Flutter's own Win32 runner does exactly this.
      if (host != NULL && host->child != NULL) {
        SetFocus(host->child);
      }
      return 0;

    case WM_FONTCHANGE:
      if (host != NULL && host->controller != NULL) {
        FlutterDesktopEngineReloadSystemFonts(
            FlutterDesktopViewControllerGetEngine(host->controller));
      }
      return 0;

    case WM_DESTROY:
      PostQuitMessage(0);
      return 0;

    case WM_TIMER:
      if (wparam == kDrainTimerId) {
        drain_gcd_main_queue();
        return 0;
      }
      break;

    default:
      break;
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}

// UTF-8 -> UTF-16. Caller frees.
static wchar_t* to_wide(const char* utf8) {
  if (utf8 == NULL) {
    return NULL;
  }
  int n = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
  if (n <= 0) {
    return NULL;
  }
  wchar_t* out = (wchar_t*)calloc((size_t)n, sizeof(wchar_t));
  if (out == NULL) {
    return NULL;
  }
  MultiByteToWideChar(CP_UTF8, 0, utf8, -1, out, n);
  return out;
}

FlWin32Host* flwin32_host_create(const char* title,
                                 int32_t width,
                                 int32_t height,
                                 const void* runtime_controller) {
  HINSTANCE instance = GetModuleHandleW(NULL);

  // Per-monitor DPI so the engine sees a truthful pixel ratio. Best effort:
  // a manifest may have set awareness already, in which case this fails and
  // the existing setting stands.
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

  WNDCLASSEXW wc = {0};
  wc.cbSize = sizeof(WNDCLASSEXW);
  wc.style = CS_HREDRAW | CS_VREDRAW;
  wc.lpfnWndProc = host_wnd_proc;
  wc.hInstance = instance;
  wc.hCursor = LoadCursorW(NULL, IDC_ARROW);
  wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
  wc.lpszClassName = kWindowClass;
  // Ignore "already registered" — a second host in one process is fine.
  RegisterClassExW(&wc);

  wchar_t* wtitle = to_wide(title != NULL ? title : "Flutter");

  // Size the frame so the *client* area is the requested size.
  RECT frame = {0, 0, (LONG)width, (LONG)height};
  AdjustWindowRect(&frame, WS_OVERLAPPEDWINDOW, FALSE);

  HWND window = CreateWindowExW(
      0, kWindowClass, wtitle != NULL ? wtitle : L"Flutter",
      WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
      frame.right - frame.left, frame.bottom - frame.top, NULL, NULL,
      instance, NULL);
  free(wtitle);

  if (window == NULL) {
    fprintf(stderr, "[FlWin32Host] CreateWindowExW failed (%lu)\n",
            GetLastError());
    return NULL;
  }

  // Engine data files resolve the standard Flutter bundle way:
  // <executable dir>/data/{icudtl.dat,flutter_assets}. These paths are
  // documented as relative to the executable's directory, so no absolute
  // path is needed here.
  FlutterDesktopEngineProperties properties = {0};
  properties.assets_path = L"data\\flutter_assets";
  properties.icu_data_path = L"data\\icudtl.dat";
  // The Swift framework is main-thread-bound (MainActor): runtime callbacks
  // and platform messages must arrive on the message thread, not the engine's
  // own UI thread. The embedder already merges them unless asked not to, but
  // say so explicitly — the enum's Default is documented as changing.
  properties.ui_thread_policy = RunOnPlatformThread;

  FlutterDesktopEngineRef engine = FlutterDesktopEngineCreate(&properties);
  if (engine == NULL) {
    fprintf(stderr, "[FlWin32Host] FlutterDesktopEngineCreate failed\n");
    DestroyWindow(window);
    return NULL;
  }

  // Swift mode must be set before the engine runs, and creating the view
  // controller is what runs it.
  FlutterDesktopEngineSetSwiftRuntime(engine, runtime_controller);

  RECT client;
  GetClientRect(window, &client);
  FlutterDesktopViewControllerRef controller = FlutterDesktopViewControllerCreate(
      client.right - client.left, client.bottom - client.top, engine);
  if (controller == NULL) {
    // The engine is destroyed for us when view controller creation fails.
    fprintf(stderr,
            "[FlWin32Host] FlutterDesktopViewControllerCreate failed\n");
    DestroyWindow(window);
    return NULL;
  }

  FlWin32Host* host = (FlWin32Host*)calloc(1, sizeof(FlWin32Host));
  if (host == NULL) {
    FlutterDesktopViewControllerDestroy(controller);
    DestroyWindow(window);
    return NULL;
  }
  host->window = window;
  host->controller = controller;
  host->child =
      FlutterDesktopViewGetHWND(FlutterDesktopViewControllerGetView(controller));
  host->saved_placement.length = sizeof(WINDOWPLACEMENT);

  // The Win32 embedder documents that view hookup is the caller's job. This is
  // exactly what the engine's own SetChildContent (host_window.cc) does — in
  // particular it does NOT rewrite the child's GWL_STYLE, because the view is
  // already created as a child and overwriting the style word would drop the
  // other bits the embedder set on it.
  SetParent(host->child, window);
  MoveWindow(host->child, client.left, client.top, client.right - client.left,
             client.bottom - client.top, TRUE);

  SetWindowLongPtrW(window, GWLP_USERDATA, (LONG_PTR)host);
  return host;
}

void flwin32_host_show(FlWin32Host* host) {
  if (host == NULL) {
    return;
  }
  ShowWindow(host->window, SW_SHOW);
  UpdateWindow(host->window);
  SetFocus(host->child);
}

void flwin32_host_run(FlWin32Host* host) {
  if (host == NULL) {
    return;
  }
  SetTimer(host->window, kDrainTimerId, kDrainTimerMs, NULL);

  MSG message;
  while (GetMessageW(&message, NULL, 0, 0) > 0) {
    TranslateMessage(&message);
    DispatchMessageW(&message);
  }

  KillTimer(host->window, kDrainTimerId);
}

void flwin32_host_set_fullscreen(FlWin32Host* host, int32_t fullscreen) {
  if (host == NULL || (host->fullscreen != 0) == (fullscreen != 0)) {
    return;
  }
  if (fullscreen) {
    // Borderless window covering the monitor the window is currently on --
    // the ordinary Win32 idiom, and it keeps the engine's child window and
    // its swap chain intact.
    GetWindowPlacement(host->window, &host->saved_placement);
    MONITORINFO mi = {sizeof(MONITORINFO)};
    if (GetMonitorInfoW(MonitorFromWindow(host->window, MONITOR_DEFAULTTONEAREST),
                        &mi)) {
      SetWindowLongPtrW(host->window, GWL_STYLE, WS_POPUP | WS_VISIBLE);
      SetWindowPos(host->window, HWND_TOP, mi.rcMonitor.left, mi.rcMonitor.top,
                   mi.rcMonitor.right - mi.rcMonitor.left,
                   mi.rcMonitor.bottom - mi.rcMonitor.top,
                   SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    }
  } else {
    SetWindowLongPtrW(host->window, GWL_STYLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE);
    SetWindowPlacement(host->window, &host->saved_placement);
    SetWindowPos(host->window, NULL, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER |
                     SWP_FRAMECHANGED);
  }
  host->fullscreen = fullscreen ? 1 : 0;
}
