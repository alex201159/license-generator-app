#ifndef RUNNER_WINDOWS_STARTUP_H_
#define RUNNER_WINDOWS_STARTUP_H_

#include <string>

std::wstring GetWindowsExecutablePath();

// Registers this executable for the current user's Windows logon.
bool RegisterWindowsStartup(const std::wstring& executable_path);

#endif  // RUNNER_WINDOWS_STARTUP_H_
