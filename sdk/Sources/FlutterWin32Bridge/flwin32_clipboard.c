// Copyright the Starling authors
// SPDX-License-Identifier: Apache-2.0

/*
 * flwin32_clipboard.c -- the system clipboard for the Win32 host.
 *
 * Deliberately plain ASCII throughout, comments included: this tree has a long
 * history of MSVC/PowerShell trouble with non-ASCII bytes, and a clipboard
 * shim is not the place to find another one.
 *
 * Win32's clipboard is a handoff, not a negotiation: the data is copied into
 * global memory at set time and read straight back at get time. So unlike the
 * Wayland and GTK backends there is no owner to ask, nothing to wait on, and
 * no way for another process to stall a paste -- which is why this is
 * synchronous and needs no thread of its own.
 */

#include <windows.h>

#include "include/FlutterWin32Bridge.h"

int32_t flwin32_clipboard_set_text(const char* text) {
    if (!text) return 0;

    /* Size first: the count includes the terminator. */
    int wlen = MultiByteToWideChar(CP_UTF8, 0, text, -1, NULL, 0);
    if (wlen <= 0) return 0;

    if (!OpenClipboard(NULL)) return 0;
    EmptyClipboard();

    HGLOBAL block = GlobalAlloc(GMEM_MOVEABLE, (SIZE_T)wlen * sizeof(WCHAR));
    if (!block) {
        CloseClipboard();
        return 0;
    }
    WCHAR* dst = (WCHAR*)GlobalLock(block);
    if (!dst) {
        GlobalFree(block);
        CloseClipboard();
        return 0;
    }
    MultiByteToWideChar(CP_UTF8, 0, text, -1, dst, wlen);
    GlobalUnlock(block);

    /* SetClipboardData takes ownership on success -- freeing the block after
     * that hands the clipboard a dangling handle. On failure it is still ours
     * and must be released here. */
    if (!SetClipboardData(CF_UNICODETEXT, block)) {
        GlobalFree(block);
        CloseClipboard();
        return 0;
    }
    CloseClipboard();
    return 1;
}

int32_t flwin32_clipboard_get_text(char* out, int32_t out_size) {
    if (!out || out_size <= 0) return -1;
    out[0] = '\0';

    if (!IsClipboardFormatAvailable(CF_UNICODETEXT)) return 0;
    if (!OpenClipboard(NULL)) return 0;

    /* The handle belongs to the clipboard: lock and copy, never free it. */
    HANDLE handle = GetClipboardData(CF_UNICODETEXT);
    if (!handle) {
        CloseClipboard();
        return 0;
    }
    const WCHAR* src = (const WCHAR*)GlobalLock(handle);
    if (!src) {
        CloseClipboard();
        return 0;
    }

    int32_t result;
    int need = WideCharToMultiByte(CP_UTF8, 0, src, -1, NULL, 0, NULL, NULL);
    if (need <= 0) {
        result = 0;
    } else if (need > out_size) {
        result = -1;                 /* caller retries with a bigger buffer */
    } else {
        result = (int32_t)WideCharToMultiByte(CP_UTF8, 0, src, -1,
                                              out, out_size, NULL, NULL);
    }

    GlobalUnlock(handle);
    CloseClipboard();
    return result;
}
