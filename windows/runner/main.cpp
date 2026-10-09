#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shobjidl_core.h>
#include <cstring>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  const auto arguments = GetCommandLineArguments();
  if (arguments.size() == 1 && arguments.front().size() < 65536 &&
      _strnicmp(arguments.front().c_str(), "xyd:", 4) == 0) {
    HWND existing = ::FindWindow(L"XY_CRYPTO_MAIN_WINDOW", nullptr);
    if (existing != nullptr) {
      const auto& link = arguments.front();
      COPYDATASTRUCT data = {};
      // app_links' public Windows activation protocol (APPLINK_MSG_ID).
      data.dwData = WM_USER + 2;
      data.cbData = static_cast<DWORD>(link.size() + 1);
      data.lpData = const_cast<char*>(link.c_str());
      DWORD_PTR response = 0;
      if (::SendMessageTimeout(existing, WM_COPYDATA, 0,
            reinterpret_cast<LPARAM>(&data), SMTO_ABORTIFHUNG, 3000, &response)) {
        ::ShowWindow(existing, SW_RESTORE);
        ::SetForegroundWindow(existing);
        return EXIT_SUCCESS;
      }
    }
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  ::SetCurrentProcessExplicitAppUserModelID(L"com.hujiayucc.decode");

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"XY加密", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}