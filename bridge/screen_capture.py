"""
RAASE 2.0 - Roblox Studio Viewport Screen Capture Worker
Locates the active Roblox Studio window, brings it to foreground, retrieves its window rect,
and captures the window dimensions with .NET Graphics.
"""

import os
import sys
import ctypes
from ctypes import wintypes
import subprocess

OUTPUT_FILENAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "viewport_latest.png"))

user32 = ctypes.windll.user32

class RECT(ctypes.Structure):
    _fields_ = [
        ("left", ctypes.c_long),
        ("top", ctypes.c_long),
        ("right", ctypes.c_long),
        ("bottom", ctypes.c_long)
    ]

# Ensure thread is attached to the interactive 'default' desktop on WinSta0
try:
    hDesk = user32.OpenDesktopW("default", 0, False, 0x01FF)
    if hDesk:
        user32.SetThreadDesktop(hDesk)
except Exception:
    pass

def find_roblox_studio_window():
    target_hwnd = None
    fallback_hwnd = None
    WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)

    def enum_windows_callback(hwnd, lparam):
        nonlocal target_hwnd, fallback_hwnd
        if user32.IsWindowVisible(hwnd):
            length = user32.GetWindowTextLengthW(hwnd)
            if length > 0:
                buff = ctypes.create_unicode_buffer(length + 1)
                user32.GetWindowTextW(hwnd, buff, length + 1)
                title = buff.value
                if "Test Guide" not in title:
                    if " - Roblox Studio" in title:
                        target_hwnd = hwnd
                        return False
                    elif "Roblox Studio" in title and fallback_hwnd is None:
                        fallback_hwnd = hwnd
        return True

    user32.EnumWindows(WNDENUMPROC(enum_windows_callback), 0)
    return target_hwnd or fallback_hwnd

try:
    user32.SetProcessDPIAware()
except Exception:
    pass

def get_window_bounds(hwnd):
    rect = RECT()
    if user32.GetWindowRect(hwnd, ctypes.byref(rect)):
        if rect.left < -10000 or rect.top < -10000:
            return None
        screen_w = user32.GetSystemMetrics(0)
        screen_h = user32.GetSystemMetrics(1)
        x = max(0, rect.left)
        y = max(0, rect.top)
        w = max(100, min(screen_w - x, rect.right - x))
        h = max(100, min(screen_h - y, rect.bottom - y))
        return (x, y, w, h)
    return None

gdi32 = ctypes.windll.gdi32
gdiplus = ctypes.windll.gdiplus

class GdiplusStartupInput(ctypes.Structure):
    _fields_ = [
        ("GdiplusVersion", ctypes.c_uint32),
        ("DebugEventCallback", ctypes.c_void_p),
        ("SuppressBackgroundThread", ctypes.c_bool),
        ("SuppressExternalCodecs", ctypes.c_bool)
    ]

class CLSID(ctypes.Structure):
    _fields_ = [
        ("Data1", ctypes.c_ulong),
        ("Data2", ctypes.c_ushort),
        ("Data3", ctypes.c_ushort),
        ("Data4", ctypes.c_ubyte * 8)
    ]

PNG_CLSID = CLSID(0x557cf406, 0x1a04, 0x11d3, (ctypes.c_ubyte * 8)(0x9a, 0x73, 0x00, 0x00, 0xf8, 0x1e, 0xf3, 0x2e))

user32.GetDC.restype = ctypes.c_void_p
user32.GetDC.argtypes = [ctypes.c_void_p]
user32.ReleaseDC.restype = ctypes.c_int
user32.ReleaseDC.argtypes = [ctypes.c_void_p, ctypes.c_void_p]

gdi32.CreateCompatibleDC.restype = ctypes.c_void_p
gdi32.CreateCompatibleDC.argtypes = [ctypes.c_void_p]
gdi32.CreateCompatibleBitmap.restype = ctypes.c_void_p
gdi32.CreateCompatibleBitmap.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
gdi32.SelectObject.restype = ctypes.c_void_p
gdi32.SelectObject.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
gdi32.BitBlt.restype = ctypes.c_bool
gdi32.BitBlt.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_uint]
gdi32.DeleteDC.restype = ctypes.c_bool
gdi32.DeleteDC.argtypes = [ctypes.c_void_p]
gdi32.DeleteObject.restype = ctypes.c_bool
gdi32.DeleteObject.argtypes = [ctypes.c_void_p]

gdiplus.GdipCreateBitmapFromHBITMAP.restype = ctypes.c_int
gdiplus.GdipCreateBitmapFromHBITMAP.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]

gdiplus.GdipSaveImageToFile.restype = ctypes.c_int
gdiplus.GdipSaveImageToFile.argtypes = [ctypes.c_void_p, ctypes.c_wchar_p, ctypes.c_void_p, ctypes.c_void_p]

gdiplus.GdipDisposeImage.restype = ctypes.c_int
gdiplus.GdipDisposeImage.argtypes = [ctypes.c_void_p]

def capture_rect(x, y, w, h):
    hScreenDC = user32.GetDC(None)
    if not hScreenDC:
        return False
    hMemDC = gdi32.CreateCompatibleDC(hScreenDC)
    hBmp = gdi32.CreateCompatibleBitmap(hScreenDC, w, h)
    gdi32.SelectObject(hMemDC, hBmp)
    SRCCOPY = 0x00CC0020
    ok = gdi32.BitBlt(hMemDC, 0, 0, w, h, hScreenDC, x, y, SRCCOPY)
    if not ok:
        user32.ReleaseDC(None, hScreenDC)
        gdi32.DeleteDC(hMemDC)
        gdi32.DeleteObject(hBmp)
        return False

    token = ctypes.c_ulong()
    startup_in = GdiplusStartupInput(1, None, False, False)
    gdiplus.GdiplusStartup(ctypes.byref(token), ctypes.byref(startup_in), None)
    pBitmap = ctypes.c_void_p()
    gdiplus.GdipCreateBitmapFromHBITMAP(hBmp, 0, ctypes.byref(pBitmap))
    res = gdiplus.GdipSaveImageToFile(pBitmap, OUTPUT_FILENAME, ctypes.byref(PNG_CLSID), None)
    gdiplus.GdipDisposeImage(pBitmap)
    gdiplus.GdiplusShutdown(token)

    user32.ReleaseDC(None, hScreenDC)
    gdi32.DeleteDC(hMemDC)
    gdi32.DeleteObject(hBmp)
    return res == 0

import time

kernel32 = ctypes.windll.kernel32

def main():
    hwnd = find_roblox_studio_window()
    if hwnd:
        print(f"[ScreenCapture] Located Roblox Studio HWND: {hwnd}. Activating and bringing to foreground...")
        try:
            fg = user32.GetForegroundWindow()
            fg_tid = user32.GetWindowThreadProcessId(fg, None)
            cur_tid = kernel32.GetCurrentThreadId()
            if fg_tid != cur_tid:
                user32.AttachThreadInput(cur_tid, fg_tid, True)

            HWND_TOPMOST = -1
            HWND_NOTOPMOST = -2
            SWP_NOMOVE = 0x0002
            SWP_NOSIZE = 0x0001
            SWP_SHOWWINDOW = 0x0040

            user32.SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW)
            time.sleep(0.1)
            user32.SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW)

            if user32.IsIconic(hwnd):
                user32.ShowWindow(hwnd, 9) # SW_RESTORE
                time.sleep(0.2)
            user32.ShowWindow(hwnd, 5) # SW_SHOW
            user32.BringWindowToTop(hwnd)
            user32.SetForegroundWindow(hwnd)

            if fg_tid != cur_tid:
                user32.AttachThreadInput(cur_tid, fg_tid, False)
        except Exception as e:
            print(f"[ScreenCapture] Foreground activation warning: {e}")
        time.sleep(0.5)

        bounds = get_window_bounds(hwnd)
        if bounds:
            x, y, w, h = bounds
            print(f"[ScreenCapture] Capturing Studio window at bounds ({x}, {y}, {w}x{h})...")
            success = capture_rect(x, y, w, h)
        else:
            success = capture_rect(0, 0, 1920, 1080)
    else:
        print("[ScreenCapture] Roblox Studio window not detected. Capturing primary display.")
        success = capture_rect(0, 0, 1920, 1080)

    if success and os.path.exists(OUTPUT_FILENAME):
        size_kb = os.path.getsize(OUTPUT_FILENAME) / 1024
        print(f"[ScreenCapture] Successfully captured viewport to {OUTPUT_FILENAME} ({size_kb:.1f} KB)")
        sys.exit(0)
    else:
        print("[ScreenCapture] Error: Could not save viewport capture.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()

