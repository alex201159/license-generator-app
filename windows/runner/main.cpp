#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <memory>

#include "flutter_window.h"
#include "utils.h"
#include "windows_startup.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  const bool start_minimized =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--startup") != command_line_arguments.end();
  command_line_arguments.erase(
      std::remove(command_line_arguments.begin(), command_line_arguments.end(),
                  "--startup"),
      command_line_arguments.end());

  // Keep a single app/server per session, including when Windows starts it.
  const HANDLE instance_handle = CreateMutexW(
      nullptr, FALSE, L"Local\\LCCargaLicenseGenerator.SingleInstance");
  const DWORD instance_error = GetLastError();
  if (instance_handle == nullptr) {
    return EXIT_FAILURE;
  }
  const std::unique_ptr<void, decltype(&CloseHandle)> instance_guard(
      instance_handle, &CloseHandle);
  if (instance_error == ERROR_ALREADY_EXISTS) {
    if (!start_minimized) {
      HWND existing = FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW",
                                  L"Gerador de Licen\u00E7as");
      if (existing != nullptr) {
        ShowWindow(existing, SW_RESTORE);
        SetForegroundWindow(existing);
      }
    }
    return EXIT_SUCCESS;
  }

  const std::wstring executable_path = GetWindowsExecutablePath();
  const size_t directory_end = executable_path.find_last_of(L"\\/");
  if (directory_end == std::wstring::npos) {
    return EXIT_FAILURE;
  }
  if (!start_minimized && !RegisterWindowsStartup(executable_path)) {
    OutputDebugStringW(L"Gerador de Licencas: falha ao registrar a inicializacao do Windows.\n");
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // A logon launch may have a working directory outside the app's folder.
  flutter::DartProject project(
      executable_path.substr(0, directory_end) + L"\\data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, start_minimized);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Gerador de Licen\u00E7as", origin, size)) {
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
