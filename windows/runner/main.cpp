#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "flutter/method_channel.h"
#include "flutter/standard_method_codec.h"
#include <memory>
#include <iostream>
#include <algorithm>
#include <regex>
#include <thread>
#include <chrono>
#include <random>
#include <sstream>
#include <fstream>


std::string GetEnvironmentVariable(const std::string &var) {
    char *buf = nullptr;
    size_t sz = 0;
    if (_dupenv_s(&buf, &sz, var.c_str()) == 0 && buf != nullptr) {
        std::string value(buf);
        free(buf);
        return value;
    }
    return "";
}

void ExecuteCommandAsync(const std::string &command) {
    std::thread([command]() {
        // Generate a unique filename for the temporary file
        auto now = std::chrono::high_resolution_clock::now();
        auto duration = now.time_since_epoch();
        auto milliseconds = std::chrono::duration_cast<std::chrono::milliseconds>(duration).count();

        std::random_device rd;  // Will be used to obtain a seed for the random number engine
        std::mt19937 gen(rd()); // Standard mersenne_twister_engine seeded with rd()
        std::uniform_int_distribution<> distrib(1, 1000);

        std::stringstream ss;
        ss << "temp_" << milliseconds << "_" << distrib(gen) << ".txt";
        std::string tempFileName = ss.str();

        std::string fullCommand = "cmd /c " + command + " > " + tempFileName + " && type " + tempFileName + " && del " + tempFileName;
        system(fullCommand.c_str());
    }).detach();  // Detach the thread to run independently
}

bool isValidInput(const std::string &input) {
    return std::regex_match(input, std::regex("^[a-zA-Z0-9_\\-\\.\\:\\\\ ]+$"));
}

void RunGameClient(const std::string &characterName, const std::string &proxyAddress, const std::string &scriptName = "Tutorial Journey") {
    if (!isValidInput(characterName) || !isValidInput(proxyAddress) || !isValidInput(scriptName)) {
        throw std::invalid_argument("Unsafe characters in input.");
    }

    std::string userName = GetEnvironmentVariable("USERNAME");
    std::string command = "java -jar C:\\Users\\" + userName + "\\DreamBot\\BotData\\client.jar";
    command += " -script \"" + scriptName + "\" -account \"" + characterName + "\"";

    if (!proxyAddress.empty() && proxyAddress != "none") {
        command += " -proxy \"" + proxyAddress + "\"";
    }

    ExecuteCommandAsync(command);  // Run the command asynchronously
}

void ListJavaProcesses(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result) {
    std::string tempFileName = "temp_" + std::to_string(std::chrono::system_clock::now().time_since_epoch().count()) + ".txt";
    std::string command = "wmic process where \"name='java.exe' or name='javaw.exe'\" get CommandLine,ProcessId /FORMAT:LIST";
    std::string fullCommand = "cmd /c " + command + " > " + tempFileName;
    system(fullCommand.c_str());

    std::ifstream file(tempFileName, std::ios::binary);
    std::string content((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    file.close();
    std::remove(tempFileName.c_str());

    std::string encoded = base64_encode(reinterpret_cast<const unsigned char*>(content.data()), content.size());

    if (encoded.empty()) {
        result->Error("No Data", "Failed to retrieve or encode process data.");
    } else {
        result->Success(flutter::EncodableValue(encoded));
    }
}

void KillProcessAndChilds(const std::string &pidStr) {
    // Using taskkill to kill a pid and its children
    ExecuteCommandAsync("taskkill /F /PID " + pidStr + " /T");
}

void HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("listJavaProcesses") == 0) {
    ListJavaProcesses(result);
  } else if (method_call.method_name().compare("killProcessAndChilds") == 0) {
     const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments || arguments->find(flutter::EncodableValue("pid")) == arguments->end()) {
        result->Error("Invalid arguments", "Expected a PID.");
        return;
    }
    int pid = std::get<int>(arguments->at(flutter::EncodableValue("pid")));
    // Convert PID to string for command execution
    std::stringstream ss;
    ss << pid;
    std::string pidStr = ss.str();

    // Call the function to kill the process
    KillProcessAndChilds(pidStr);
    result->Success(flutter::EncodableValue("Process and its children terminated successfully"));
     } else if (method_call.method_name().compare("runCmdCommand") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments || arguments->find(flutter::EncodableValue("command")) == arguments->end()) {
        result->Error("Invalid arguments", "Expected a command string.");
        return;
    }
    std::string cmdCommand = std::get<std::string>(arguments->at(flutter::EncodableValue("command")));
    ExecuteCommandAsync(cmdCommand);
    result->Success(flutter::EncodableValue("Command executed successfully"));
  } else if (method_call.method_name().compare("runGameClient") == 0) {
        const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (!arguments) {
            result->Error("Invalid arguments", "Expected arguments for character name, proxy, and optionally script name.");
            return;
        }
        std::string characterName = std::get<std::string>(arguments->at(flutter::EncodableValue("characterName")));
        std::string proxyAddress = std::get<std::string>(arguments->at(flutter::EncodableValue("proxyAddress")));
        std::string scriptName = arguments->find(flutter::EncodableValue("scriptName")) != arguments->end() ? std::get<std::string>(arguments->at(flutter::EncodableValue("scriptName"))) : "Tutorial Journey";
        try {
            RunGameClient(characterName, proxyAddress, scriptName);
            result->Success(flutter::EncodableValue("Game client launched successfully"));
        } catch (const std::invalid_argument& e) {
            result->Error("Invalid Input", e.what());
        }
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
