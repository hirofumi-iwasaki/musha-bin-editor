#include "flutter_window.h"

#include <filesystem>
#include <limits>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/standard_method_codec.h>

namespace {

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) return L"";
  if (value.size() > static_cast<size_t>((std::numeric_limits<int>::max)())) {
    return L"";
  }
  const int input_length = static_cast<int>(value.size());
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                         value.data(), input_length, nullptr, 0);
  if (length == 0) return L"";
  std::wstring result(length, L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                          input_length, result.data(), length) == 0) {
    return L"";
  }
  return result;
}

flutter::EncodableValue SaveResult(const std::string& status,
                                   const std::string& message = "",
                                   const std::wstring& recovery_path = L"") {
  flutter::EncodableMap result;
  result[flutter::EncodableValue("status")] = flutter::EncodableValue(status);
  if (!message.empty()) {
    result[flutter::EncodableValue("message")] = flutter::EncodableValue(message);
  }
  if (!recovery_path.empty()) {
    if (recovery_path.size() >
        static_cast<size_t>((std::numeric_limits<int>::max)())) {
      return flutter::EncodableValue(result);
    }
    const int recovery_path_length = static_cast<int>(recovery_path.size());
    const int length = WideCharToMultiByte(CP_UTF8, 0, recovery_path.data(),
                                            recovery_path_length, nullptr, 0,
                                            nullptr, nullptr);
    std::string utf8(length, '\0');
    WideCharToMultiByte(CP_UTF8, 0, recovery_path.data(), recovery_path_length,
                        utf8.data(), length, nullptr, nullptr);
    result[flutter::EncodableValue("recoveryPath")] = flutter::EncodableValue(utf8);
  }
  return flutter::EncodableValue(result);
}

bool IsRegularFile(const std::wstring& path) {
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) == 0;
}

bool SameVolume(const std::wstring& first, const std::wstring& second) {
  wchar_t first_root[MAX_PATH];
  wchar_t second_root[MAX_PATH];
  if (!GetVolumePathNameW(first.c_str(), first_root, MAX_PATH) ||
      !GetVolumePathNameW(second.c_str(), second_root, MAX_PATH)) {
    return false;
  }
  DWORD first_serial = 0;
  DWORD second_serial = 0;
  return GetVolumeInformationW(first_root, nullptr, 0, &first_serial, nullptr,
                               nullptr, nullptr, 0) &&
         GetVolumeInformationW(second_root, nullptr, 0, &second_serial, nullptr,
                               nullptr, nullptr, 0) &&
         first_serial == second_serial;
}

std::wstring BackupPath(const std::wstring& destination) {
  return destination + L".mushagaeshi-backup-" +
         std::to_wstring(GetCurrentProcessId()) + L"-" +
         std::to_wstring(GetTickCount64()) + L".bak";
}

flutter::EncodableValue InstallSavedFile(const std::string& staged_utf8,
                                         const std::string& destination_utf8) {
  const std::wstring staged = Utf8ToWide(staged_utf8);
  const std::wstring destination = Utf8ToWide(destination_utf8);
  if (staged.empty() || destination.empty() || !IsRegularFile(staged)) {
    return SaveResult("failed", "The staged file is not a regular file.");
  }
  const std::wstring parent =
      std::filesystem::path(destination).parent_path().wstring();
  if (parent.empty() || !SameVolume(staged, parent)) {
    return SaveResult("failed", "Safe installation requires staging on the destination volume.");
  }

  const DWORD attributes = GetFileAttributesW(destination.c_str());
  if (attributes == INVALID_FILE_ATTRIBUTES) {
    if (GetLastError() != ERROR_FILE_NOT_FOUND && GetLastError() != ERROR_PATH_NOT_FOUND) {
      return SaveResult("failed", "Unable to inspect the destination file.");
    }
    // Do not permit a late-created destination to be overwritten.
    if (MoveFileExW(staged.c_str(), destination.c_str(), MOVEFILE_WRITE_THROUGH)) {
      return SaveResult("installed");
    }
    return SaveResult("ambiguous", "The new destination could not be installed; the complete staged file was retained.", staged);
  }
  if ((attributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) != 0) {
    return SaveResult("failed", "The destination is not a regular file.");
  }

  const std::wstring backup = BackupPath(destination);
  if (ReplaceFileW(destination.c_str(), staged.c_str(), backup.c_str(),
                   REPLACEFILE_WRITE_THROUGH, nullptr, nullptr)) {
    // A retained backup after successful replacement is harmless. Do not turn a
    // completed save into a destructive cleanup failure.
    DeleteFileW(backup.c_str());
    return SaveResult("installed");
  }

  // ReplaceFileW can leave more than one complete copy after an I/O failure.
  // Never copy over either path. Preserve a verifiable recovery file instead.
  const bool stage_exists = IsRegularFile(staged);
  const bool backup_exists = IsRegularFile(backup);
  const bool destination_exists = IsRegularFile(destination);
  if (backup_exists && !destination_exists) {
    if (MoveFileExW(backup.c_str(), destination.c_str(), MOVEFILE_WRITE_THROUGH)) {
      return SaveResult(
          "ambiguous",
          "Replacement did not complete; the destination backup was restored.",
          destination);
    }
    return SaveResult(
        "ambiguous",
        "Replacement did not complete; the backup file was retained for recovery.",
        backup);
  }
  if (stage_exists) {
    return SaveResult("ambiguous", "Replacement did not complete; the staged file was retained for recovery.", staged);
  }
  if (backup_exists) {
    return SaveResult("ambiguous", "Replacement did not complete; the backup file was retained for recovery.", backup);
  }
  if (destination_exists) {
    return SaveResult("ambiguous", "Replacement reported a failure; inspect the destination before retrying.", destination);
  }
  return SaveResult("failed", "Replacement failed before a recoverable file could be identified.");
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  save_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "mushagaeshi/files",
      &flutter::StandardMethodCodec::GetInstance());
  save_channel_->SetMethodCallHandler(
      [](const auto& call, auto result) {
        if (call.method_name() != "installSavedFile") {
          result->NotImplemented();
          return;
        }
        const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments == nullptr) {
          result->Success(SaveResult("failed", "Invalid save installation arguments."));
          return;
        }
        const auto staged_it = arguments->find(flutter::EncodableValue("stagedPath"));
        const auto destination_it = arguments->find(flutter::EncodableValue("destinationPath"));
        if (staged_it == arguments->end() || destination_it == arguments->end()) {
          result->Success(SaveResult("failed", "Missing save installation paths."));
          return;
        }
        const auto* staged = std::get_if<std::string>(&staged_it->second);
        const auto* destination = std::get_if<std::string>(&destination_it->second);
        if (staged == nullptr || destination == nullptr) {
          result->Success(SaveResult("failed", "Invalid save installation paths."));
          return;
        }
        result->Success(InstallSavedFile(*staged, *destination));
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // The channel owns a handler registered with the engine messenger. Dispose
  // it before the controller tears that messenger down.
  save_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
