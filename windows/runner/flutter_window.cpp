#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>
#include <shobjidl.h>
#include <wrl/client.h>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

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
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "weils/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "close") {
          allow_close_ = true;
          result->Success();
          PostMessage(GetHandle(), WM_CLOSE, 0, 0);
        } else if (call.method_name() == "selectDirectory") {
          Microsoft::WRL::ComPtr<IFileOpenDialog> dialog;
          HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, nullptr,
              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dialog));
          FILEOPENDIALOGOPTIONS options = 0;
          if (SUCCEEDED(hr)) hr = dialog->GetOptions(&options);
          if (SUCCEEDED(hr)) hr = dialog->SetOptions(options | FOS_PICKFOLDERS |
              FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST | FOS_NOCHANGEDIR);
          if (SUCCEEDED(hr)) {
            dialog->SetTitle(L"\u9009\u62e9\u6570\u636e\u4fdd\u5b58\u76ee\u5f55");
            dialog->SetOkButtonLabel(L"\u9009\u62e9\u6b64\u6587\u4ef6\u5939");
            const auto* initial = call.arguments()
                ? std::get_if<std::string>(call.arguments()) : nullptr;
            if (initial && !initial->empty()) {
              const int length = MultiByteToWideChar(CP_UTF8, 0,
                  initial->c_str(), -1, nullptr, 0);
              std::wstring folder(length, L'\0');
              MultiByteToWideChar(CP_UTF8, 0, initial->c_str(), -1,
                  folder.data(), length);
              Microsoft::WRL::ComPtr<IShellItem> item;
              if (SUCCEEDED(SHCreateItemFromParsingName(folder.c_str(), nullptr,
                  IID_PPV_ARGS(&item)))) dialog->SetFolder(item.Get());
            }
            hr = dialog->Show(GetHandle());
          }
          if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
            result->Success();
          } else if (SUCCEEDED(hr)) {
            Microsoft::WRL::ComPtr<IShellItem> item;
            hr = dialog->GetResult(&item);
            PWSTR path = nullptr;
            if (SUCCEEDED(hr)) hr = item->GetDisplayName(SIGDN_FILESYSPATH, &path);
            if (SUCCEEDED(hr)) {
              const std::string selected = Utf8FromUtf16(path);
              CoTaskMemFree(path);
              if (selected.empty()) {
                result->Error("directory_picker", "Unable to read selected folder");
              } else {
                result->Success(flutter::EncodableValue(selected));
              }
            } else {
              result->Error("directory_picker", "Unable to read selected folder");
            }
          } else {
            result->Error("directory_picker", "Unable to open folder picker");
          }
        } else {
          result->NotImplemented();
        }
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
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_CLOSE && !allow_close_ && window_channel_) {
    window_channel_->InvokeMethod("closeRequested", nullptr);
    return 0;
  }
  if (message == WM_GETMINMAXINFO) {
    auto info = reinterpret_cast<MINMAXINFO*>(lparam);
    const UINT dpi = GetDpiForWindow(hwnd);
    info->ptMinTrackSize.x = MulDiv(1000, dpi, 96);
    info->ptMinTrackSize.y = MulDiv(650, dpi, 96);
    return 0;
  }
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
