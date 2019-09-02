
local ffi = require 'ffi';
local user32 = ffi.load(ffi.os == "Windows" and "user32");

if ffi.arch == 'x86' then ffi.cdef [[
  typedef uint32_t UINT_PTR;
  typedef int32_t INT_PTR;
]]
end

if ffi.arch == 'x64' then ffi.cdef [[
  typedef uint64_t UINT_PTR;
  typedef int64_t INT_PTR;
]]
end

ffi.cdef [[
typedef uint16_t WORD;
typedef uint32_t UINT;
typedef uint32_t DWORD;
typedef long LONG;
typedef char *LPTSTR;
typedef LPTSTR LPCTSTR;
typedef UINT_PTR HANDLE;
typedef HANDLE HWND;
typedef UINT_PTR ULONG_PTR;
typedef UINT WINAPI_WinMsg;
typedef UINT_PTR WPARAM;
typedef INT_PTR LONG_PTR;
typedef LONG_PTR LPARAM;
typedef DWORD *PDWORD;
typedef PDWORD LPDWORD;
typedef struct RECT {
    LONG left;
    LONG top;
    LONG right;
    LONG bottom;
} RECT;
typedef RECT *LPRECT;

bool PostMessageW(HWND hWnd, WINAPI_WinMsg Msg, WPARAM wParam, LPARAM lParam);
DWORD GetWindowThreadProcessId(HWND hWnd, LPDWORD lpdwProcessId);
int GetClassNameA(HWND hWnd, LPTSTR lpClassName, int nMaxCount);
HWND GetDesktopWindow();
HWND GetWindow(HWND hWnd, int uCmd);
bool ShowWindow(HWND hWnd, int nCmdShow);
bool GetWindowRect(HWND hWnd, LPRECT lpRect);
bool MoveWindow(HWND hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
bool AllowSetForegroundWindow(DWORD dwProcessId);
bool SetForegroundWindow(HWND hWnd);
]]

BSWindow = {
    handle = nil
};

function BSWindow:init()
    BotCommandFactory:registerCommand("BSWindow.minimizeWindow", self, self.cmdMinimize)
    BotCommandFactory:registerCommand("BSWindow.restoreWindow", self, self.cmdRestore)
    BotCommandFactory:registerCommand("BSWindow.resizeWindow", self, self.cmdResize)

    self.handle = self:GetHwnd(GetCurrentProcessId());
end

function BSWindow:cmdMinimize()
    if (nil ~= self.handle) then
        user32.ShowWindow(self.handle, 6);
    end
end

function BSWindow:cmdRestore()
    if (nil ~= self.handle) then
        user32.ShowWindow(self.handle, 9);
        user32.AllowSetForegroundWindow(GetCurrentProcessId());
        user32.SetForegroundWindow(self.handle);
    end
end

function BSWindow:cmdResize(dto)
    local cfg = json.decode(dto);
    local w = cfg.w or false;
    local h = cfg.h or false;
    if (w and h) then
        if (nil ~= self.handle) then
            self:cmdRestore();
            local rect = ffi.new("RECT"); -- curren position
            if (user32.GetWindowRect(self.handle, rect)) then
                user32.MoveWindow(self.handle, rect.left, rect.top, w, h, true);
            end;
        end
    end;
end

function BSWindow:GetHwnd(ProcessID)
    local RetPID = ffi.new("UINT_PTR[?]", ffi.sizeof("UINT_PTR"));
    local lHwnd = user32.GetDesktopWindow();
    local RetHwnd = user32.GetWindow(lHwnd, 5);
    while (nil ~= RetHwnd) do
        user32.GetWindowThreadProcessId(RetHwnd, RetPID);
        if RetPID[0] == ProcessID then
            local lpClassName = ffi.new("char[?]", 0xFF);
            user32.GetClassNameA(RetHwnd, lpClassName, ffi.sizeof(lpClassName));
            local className = tostring(ffi.string(lpClassName));
            if string.match(className, "l2UnrealWWindowsViewportWindow") then
                return RetHwnd;
            end;
        end

        RetHwnd = user32.GetWindow(RetHwnd, 2);
    end;

    return nil;
end