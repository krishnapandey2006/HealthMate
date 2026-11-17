/// Controls the Noupe chat launcher that `web/index.html` injects.
///
/// Native builds have no page-level launcher, so the stub makes this a no-op.
library;

export 'chatbot_web_stub.dart'
    if (dart.library.js_interop) 'chatbot_web_web.dart';
