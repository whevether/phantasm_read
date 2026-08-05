//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <audioplayers_windows/audioplayers_windows_plugin.h>
#include <charset_converter/charset_converter_plugin.h>
#include <printing/printing_plugin.h>
#include <screen_brightness_windows/screen_brightness_windows_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AudioplayersWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AudioplayersWindowsPlugin"));
  CharsetConverterPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("CharsetConverterPlugin"));
  PrintingPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PrintingPlugin"));
  ScreenBrightnessWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenBrightnessWindowsPluginCApi"));
}
