import 'dart:js_interop';

@JS('healthMateSetChatbotLauncherVisible')
external void _setChatbotLauncherVisible(JSBoolean visible);

/// Shows or hides the Noupe launcher that `web/index.html` injects.
void setChatbotLauncherVisible(bool visible) {
  _setChatbotLauncherVisible(visible.toJS);
}
