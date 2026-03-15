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
#include <sstream>
#include <vector>
#include <comdef.h>
#include <Wbemidl.h>
#pragma comment(lib, "wbemuuid.lib")

std::string GetEnvironmentVariable(const std::string &var)
{
    char *buf = nullptr;
    size_t sz = 0;
    if (_dupenv_s(&buf, &sz, var.c_str()) == 0 && buf != nullptr)
    {
        std::string value(buf);
        free(buf);
        return value;
    }
    return "";
}

void RunDetachedProcess(const std::string &command)
{
    std::thread([command]()
                {
        STARTUPINFOA si;
        PROCESS_INFORMATION pi;
        ZeroMemory(&si, sizeof(si));
        si.cb = sizeof(si);
        ZeroMemory(&pi, sizeof(pi));

        std::vector<char> cmdBuf(command.begin(), command.end());
        cmdBuf.push_back('\0');

        if (CreateProcessA(nullptr, cmdBuf.data(), nullptr, nullptr, FALSE,
                           CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi))
        {
            CloseHandle(pi.hProcess);
            CloseHandle(pi.hThread);
        } })
        .detach();
}

bool containsShellMetachars(const std::string &input)
{
    return input.find_first_of("&|;<>`$") != std::string::npos;
}

int RunGameClient(const flutter::EncodableMap &args)
{
    auto getString = [&](const char *key) -> std::string {
        auto it = args.find(flutter::EncodableValue(key));
        if (it != args.end() && std::holds_alternative<std::string>(it->second))
            return std::get<std::string>(it->second);
        return "";
    };
    auto getBool = [&](const char *key, bool defaultVal = false) -> bool {
        auto it = args.find(flutter::EncodableValue(key));
        if (it != args.end() && std::holds_alternative<bool>(it->second))
            return std::get<bool>(it->second);
        return defaultVal;
    };

    std::string characterName = getString("characterName");
    std::string proxyAddress = getString("proxyAddress");
    std::string scriptName = getString("scriptName");
    std::string world = getString("world");
    std::string render = getString("render");
    std::string scriptParams = getString("scriptParams");
    std::string advancedFlags = getString("advancedFlags");
    bool covert = getBool("covert");
    bool destroyOnBan = getBool("destroyOnBan", true);
    bool destroy = getBool("destroy", true);
    bool minimized = getBool("minimized", true);

    // Validate structured fields against shell metacharacters
    if (containsShellMetachars(characterName) || containsShellMetachars(proxyAddress) ||
        containsShellMetachars(scriptName) || containsShellMetachars(world) ||
        containsShellMetachars(render) || containsShellMetachars(scriptParams))
    {
        throw std::invalid_argument("Unsafe characters in input.");
    }

    std::string userName = GetEnvironmentVariable("USERNAME");
    std::string command = "java -jar C:\\Users\\" + userName + "\\DreamBot\\Launcher.jar";
    command += " -script \"" + scriptName + "\" -account \"" + characterName + "\"";

    if (!proxyAddress.empty() && proxyAddress != "none")
    {
        command += " -proxy \"" + proxyAddress + "\"";
    }
    if (!world.empty() && world != "auto")
    {
        command += " -world " + world;
    }
    if (covert)
    {
        command += " -covert";
    }
    if (!render.empty() && render != "NONE")
    {
        command += " -render " + render;
    }
    if (destroy)
    {
        command += " -destroy";
    }
    if (destroyOnBan)
    {
        command += " -destroy-on-ban";
    }
    if (minimized)
    {
        command += " -minimized";
    }
    if (!advancedFlags.empty())
    {
        command += " " + advancedFlags;
    }
    // -params must be last per DreamBot requirements
    if (!scriptParams.empty())
    {
        command += " -params " + scriptParams;
    }

    // Use CreateProcess instead of system() — no CMD shell, returns PID directly
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    // CreateProcess needs a mutable copy of the command string
    std::vector<char> cmdBuf(command.begin(), command.end());
    cmdBuf.push_back('\0');

    if (!CreateProcessA(nullptr, cmdBuf.data(), nullptr, nullptr, FALSE,
                        CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi))
    {
        throw std::runtime_error("CreateProcess failed with error " + std::to_string(GetLastError()));
    }

    int pid = static_cast<int>(pi.dwProcessId);

    // Close handles — we don't need to wait on the process
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    return pid;
}

void ListJavaProcesses(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> &result)
{
    IWbemLocator *pLocator = nullptr;
    IWbemServices *pServices = nullptr;
    IEnumWbemClassObject *pEnumerator = nullptr;

    HRESULT hr = CoCreateInstance(CLSID_WbemLocator, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_IWbemLocator, (LPVOID *)&pLocator);
    if (FAILED(hr))
    {
        result->Error("WMI Error", "Failed to create WbemLocator");
        return;
    }

    hr = pLocator->ConnectServer(_bstr_t(L"ROOT\\CIMV2"), nullptr, nullptr, nullptr,
                                  0, nullptr, nullptr, &pServices);
    if (FAILED(hr))
    {
        pLocator->Release();
        result->Error("WMI Error", "Failed to connect to WMI");
        return;
    }

    hr = CoSetProxyBlanket(pServices, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE, nullptr,
                           RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE,
                           nullptr, EOAC_NONE);
    if (FAILED(hr))
    {
        pServices->Release();
        pLocator->Release();
        result->Error("WMI Error", "Failed to set proxy blanket");
        return;
    }

    hr = pServices->ExecQuery(
        bstr_t("WQL"),
        bstr_t("SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name = 'java.exe' OR Name = 'javaw.exe'"),
        WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
        nullptr, &pEnumerator);
    if (FAILED(hr))
    {
        pServices->Release();
        pLocator->Release();
        result->Error("WMI Error", "WMI query failed");
        return;
    }

    flutter::EncodableList processList;
    IWbemClassObject *pObj = nullptr;
    ULONG numReturned = 0;

    while (pEnumerator->Next(WBEM_INFINITE, 1, &pObj, &numReturned) == S_OK)
    {
        VARIANT vtPid, vtCmd;
        VariantInit(&vtPid);
        VariantInit(&vtCmd);

        int pid = 0;
        std::string commandLine;

        if (SUCCEEDED(pObj->Get(L"ProcessId", 0, &vtPid, nullptr, nullptr)) && vtPid.vt == VT_UI4)
        {
            pid = static_cast<int>(vtPid.uintVal);
        }
        if (SUCCEEDED(pObj->Get(L"CommandLine", 0, &vtCmd, nullptr, nullptr)) && vtCmd.vt == VT_BSTR)
        {
            int len = WideCharToMultiByte(CP_UTF8, 0, vtCmd.bstrVal, -1, nullptr, 0, nullptr, nullptr);
            if (len > 0)
            {
                std::string utf8(len - 1, '\0');
                WideCharToMultiByte(CP_UTF8, 0, vtCmd.bstrVal, -1, &utf8[0], len, nullptr, nullptr);
                commandLine = utf8;
            }
        }

        VariantClear(&vtPid);
        VariantClear(&vtCmd);
        pObj->Release();

        if (!commandLine.empty())
        {
            flutter::EncodableMap entry;
            entry[flutter::EncodableValue("pid")] = flutter::EncodableValue(pid);
            entry[flutter::EncodableValue("commandLine")] = flutter::EncodableValue(commandLine);
            processList.push_back(flutter::EncodableValue(entry));
        }
    }

    pEnumerator->Release();
    pServices->Release();
    pLocator->Release();

    result->Success(flutter::EncodableValue(processList));
}

void KillProcessAndChilds(const std::string &pidStr)
{
    RunDetachedProcess("taskkill /F /PID " + pidStr + " /T");
}

void HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
{
    if (method_call.method_name().compare("listJavaProcesses") == 0)
    {
        ListJavaProcesses(result);
    }
    else if (method_call.method_name().compare("killProcessAndChilds") == 0)
    {
        const auto *arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (!arguments || arguments->find(flutter::EncodableValue("pid")) == arguments->end())
        {
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
    }
    else if (method_call.method_name().compare("runGameClient") == 0)
    {
        const auto *arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
        if (!arguments)
        {
            result->Error("Invalid arguments", "Expected arguments map.");
            return;
        }
        try
        {
            int pid = RunGameClient(*arguments);
            result->Success(flutter::EncodableValue(pid));
        }
        catch (const std::invalid_argument &e)
        {
            result->Error("Invalid Input", e.what());
        }
        catch (const std::runtime_error &e)
        {
            result->Error("Launch Error", e.what());
        }
    }
    else
    {
        result->NotImplemented();
    }
}

void RegisterCustomMethodChannel(flutter::FlutterViewController *controller)
{
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        controller->engine()->messenger(), "com.onemanco/commands",
        &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler([controller](const auto &call, auto result)
                                  { HandleMethodCall(call, std::move(result)); });
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command)
{
    // Attach to console when present (e.g., 'flutter run') or create a
    // new console when running with a debugger.
    if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
    {
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
    if (!window.Create(L"command_center", origin, size))
    {
        return EXIT_FAILURE;
    }

    flutter::FlutterViewController *controller = window.GetFlutterViewController();
    if (controller != nullptr)
    {
        RegisterCustomMethodChannel(controller);
    }

    window.SetQuitOnClose(true);

    ::MSG msg;
    while (::GetMessage(&msg, nullptr, 0, 0))
    {
        ::TranslateMessage(&msg);
        ::DispatchMessage(&msg);
    }

    ::CoUninitialize();
    return EXIT_SUCCESS;
}
