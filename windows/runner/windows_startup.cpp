#include "windows_startup.h"

#include <windows.h>

#include <array>
#include <string>

std::wstring GetWindowsExecutablePath() {
  std::array<wchar_t, 32768> executable_path{};
  const DWORD length = GetModuleFileNameW(
      nullptr, executable_path.data(),
      static_cast<DWORD>(executable_path.size()));
  if (length == 0 || length >= executable_path.size()) {
    return {};
  }
  return std::wstring(executable_path.data(), length);
}

bool RegisterWindowsStartup(const std::wstring& executable_path) {
  if (executable_path.empty()) {
    return false;
  }
  const std::wstring command =
      L"\"" + executable_path + L"\" --startup";
  // Run entries have a documented 260-character command-line limit.
  if (command.size() > MAX_PATH) {
    return false;
  }

  HKEY run_key = nullptr;
  const LSTATUS opened = RegCreateKeyExW(
      HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Run", 0, nullptr,
      REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr, &run_key, nullptr);
  if (opened != ERROR_SUCCESS) {
    return false;
  }
  const LSTATUS written = RegSetValueExW(
      run_key, L"GeradorLicencasServer", 0, REG_SZ,
      reinterpret_cast<const BYTE*>(command.c_str()),
      static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  if (written == ERROR_SUCCESS) {
    RegDeleteValueW(run_key, L"LCCargaServer");
  }
  RegCloseKey(run_key);
  return written == ERROR_SUCCESS;
}
