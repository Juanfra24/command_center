#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "flutter/method_channel.h"
#include "flutter/standard_method_codec.h"
#include <memory>
#include <iostream>

void ExecuteCommand(const std::string &command) {
    std::string fullCommand = "cmd /c " + command + " > temp.txt && type temp.txt && del temp.txt";
    system(fullCommand.c_str());
}

void ListJavaProcesses() {
    // Using WMIC to get process name, PID, and command line
    ExecuteCommand("wmic process where \"name='java.exe' or name='javaw.exe'\" get ProcessID,CommandLine /FORMAT:CSV");
}

void HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("listJavaProcesses") == 0) {
    ListJavaProcesses();
    result->Success(flutter::EncodableValue("Java processes listed successfully"));
  } else if (method_call.method_name().compare("runCmdCommand") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
        result->Error("Invalid arguments", "Expected a command string.");
        return;
    }
    std::string cmdCommand = std::get<std::string>(arguments->at(flutter::EncodableValue("command")));
    ExecuteCommand(cmdCommand);
    result->Success(flutter::EncodableValue("Command executed successfully"));
  } else {
    result->NotImplemented();
  }
}

void RegisterCustomMethodChannel(flutter::FlutterViewController* controller) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        controller->engine()->messenger(), "com.onemanco/commands",
        &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler([controller](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
    });
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"command_center", origin, size)) {
    return EXIT_FAILURE;
  }

  flutter::FlutterViewController* controller = window.GetFlutterViewController();
  if (controller != nullptr) {
    RegisterCustomMethodChannel(controller);
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
