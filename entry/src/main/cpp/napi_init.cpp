#include <string>
#include <vector>

#include "napi/native_api.h"
#include "limbo_vm.h"

namespace {

napi_value MakeString(napi_env env, const std::string &value) {
  napi_value result = nullptr;
  napi_create_string_utf8(env, value.c_str(), value.size(), &result);
  return result;
}

napi_value MakeBool(napi_env env, bool value) {
  napi_value result = nullptr;
  napi_get_boolean(env, value, &result);
  return result;
}

napi_value MakeInt(napi_env env, int value) {
  napi_value result = nullptr;
  napi_create_int32(env, value, &result);
  return result;
}

bool ReadString(napi_env env, napi_value value, std::string &out) {
  size_t length = 0;
  if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok) {
    return false;
  }
  std::vector<char> buffer(length + 1, '\0');
  if (napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &length) != napi_ok) {
    return false;
  }
  out.assign(buffer.data(), length);
  return true;
}

bool ReadInt(napi_env env, napi_value value, int &out) {
  int32_t number = 0;
  if (napi_get_value_int32(env, value, &number) != napi_ok) {
    return false;
  }
  out = static_cast<int>(number);
  return true;
}

bool ReadBool(napi_env env, napi_value value, bool &out) {
  bool flag = false;
  if (napi_get_value_bool(env, value, &flag) != napi_ok) {
    return false;
  }
  out = flag;
  return true;
}

std::vector<std::string> ReadStringArray(napi_env env, napi_value value) {
  std::vector<std::string> result;
  bool isArray = false;
  if (napi_is_array(env, value, &isArray) != napi_ok || !isArray) {
    return result;
  }
  uint32_t length = 0;
  napi_get_array_length(env, value, &length);
  result.reserve(length);
  for (uint32_t i = 0; i < length; ++i) {
    napi_value element = nullptr;
    if (napi_get_element(env, value, i, &element) != napi_ok) {
      continue;
    }
    std::string item;
    if (ReadString(env, element, item)) {
      result.push_back(item);
    }
  }
  return result;
}

napi_value NapiSetPaths(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value argv[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  std::string storageDir;
  std::string baseDir;
  if (argc >= 1) {
    ReadString(env, argv[0], storageDir);
  }
  if (argc >= 2) {
    ReadString(env, argv[1], baseDir);
  }
  LimboVm::Instance().SetPaths(storageDir, baseDir);
  return MakeBool(env, true);
}

napi_value NapiIsEngineAvailable(napi_env env, napi_callback_info info) {
  return MakeBool(env, LimboVm::Instance().IsEngineAvailable());
}

napi_value NapiStart(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value argv[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

  std::vector<std::string> args;
  int scaleMode = -1;
  int refreshRate = -1;
  if (argc >= 1) {
    args = ReadStringArray(env, argv[0]);
  }
  if (argc >= 2) {
    ReadInt(env, argv[1], scaleMode);
  }
  if (argc >= 3) {
    ReadInt(env, argv[2], refreshRate);
  }
  const std::string error = LimboVm::Instance().Start(args, scaleMode, refreshRate);
  return MakeString(env, error);
}

napi_value NapiStop(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value argv[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  bool restart = false;
  if (argc >= 1) {
    ReadBool(env, argv[0], restart);
  }
  const std::string error = LimboVm::Instance().Stop(restart);
  return MakeString(env, error);
}

napi_value NapiPause(napi_env env, napi_callback_info info) {
  return MakeString(env, LimboVm::Instance().Pause());
}

napi_value NapiResume(napi_env env, napi_callback_info info) {
  return MakeString(env, LimboVm::Instance().Resume());
}

napi_value NapiGetState(napi_env env, napi_callback_info info) {
  return MakeInt(env, LimboVm::Instance().GetState());
}

napi_value NapiSetScaleMode(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value argv[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  int mode = 1;
  if (argc >= 1) {
    ReadInt(env, argv[0], mode);
  }
  LimboVm::Instance().SetScaleMode(mode);
  return MakeBool(env, true);
}

napi_value NapiSetRefreshRateHz(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value argv[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  int hz = 0;
  if (argc >= 1) {
    ReadInt(env, argv[0], hz);
  }
  LimboVm::Instance().SetRefreshRate(hz);
  return MakeBool(env, true);
}

napi_value NapiRefreshScreen(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value argv[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  int value = 1;
  if (argc >= 1) {
    ReadInt(env, argv[0], value);
  }
  LimboVm::Instance().RefreshScreen(value);
  return MakeBool(env, true);
}

napi_value NapiSendKeyCombo(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value argv[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  std::string keys;
  int holdMs = 100;
  if (argc >= 1) {
    ReadString(env, argv[0], keys);
  }
  if (argc >= 2) {
    ReadInt(env, argv[1], holdMs);
  }
  return MakeString(env, LimboVm::Instance().SendKeyCombo(keys, holdMs));
}

napi_value NapiSendKeyEvent(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value argv[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  std::string key;
  bool down = false;
  if (argc >= 1) {
    ReadString(env, argv[0], key);
  }
  if (argc >= 2) {
    ReadBool(env, argv[1], down);
  }
  return MakeString(env, LimboVm::Instance().SendKeyEvent(key, down));
}

napi_value NapiSendText(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value argv[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  std::string text;
  int delayMs = 30;
  if (argc >= 1) {
    ReadString(env, argv[0], text);
  }
  if (argc >= 2) {
    ReadInt(env, argv[1], delayMs);
  }
  return MakeString(env, LimboVm::Instance().SendText(text, delayMs));
}

napi_value NapiSendMouseButton(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value argv[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  std::string button = "left";
  bool down = false;
  if (argc >= 1) {
    ReadString(env, argv[0], button);
  }
  if (argc >= 2) {
    ReadBool(env, argv[1], down);
  }
  return MakeString(env, LimboVm::Instance().SendMouseButton(button, down));
}

napi_value NapiSendMouseMove(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value argv[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  bool relative = true;
  int x = 0;
  int y = 0;
  if (argc >= 1) {
    ReadBool(env, argv[0], relative);
  }
  if (argc >= 2) {
    ReadInt(env, argv[1], x);
  }
  if (argc >= 3) {
    ReadInt(env, argv[2], y);
  }
  return MakeString(env, LimboVm::Instance().SendMouseMove(relative, x, y));
}

} // namespace

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor descriptors[] = {
    {"setPaths", nullptr, NapiSetPaths, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isEngineAvailable", nullptr, NapiIsEngineAvailable, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"start", nullptr, NapiStart, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"stop", nullptr, NapiStop, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pause", nullptr, NapiPause, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"resume", nullptr, NapiResume, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getState", nullptr, NapiGetState, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"setScaleMode", nullptr, NapiSetScaleMode, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"setRefreshRateHz", nullptr, NapiSetRefreshRateHz, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"refreshScreen", nullptr, NapiRefreshScreen, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendKeyCombo", nullptr, NapiSendKeyCombo, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendKeyEvent", nullptr, NapiSendKeyEvent, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendText", nullptr, NapiSendText, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendMouseButton", nullptr, NapiSendMouseButton, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendMouseMove", nullptr, NapiSendMouseMove, nullptr, nullptr, nullptr, napi_default, nullptr},
  };
  napi_define_properties(env, exports, sizeof(descriptors) / sizeof(descriptors[0]), descriptors);
  return exports;
}
EXTERN_C_END

static napi_module limboModule = {
  .nm_version = 1,
  .nm_flags = 0,
  .nm_filename = nullptr,
  .nm_register_func = Init,
  .nm_modname = "limbo",
  .nm_priv = nullptr,
  .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterLimboModule(void) {
  napi_module_register(&limboModule);
}
