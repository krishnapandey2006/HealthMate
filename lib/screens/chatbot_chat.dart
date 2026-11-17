import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_widgets.dart';

/// Full-screen native chat surface for the Noupe assistant.
///
/// The embed's own launcher is hidden in [chatbotHtml]; this screen supplies
/// the Flutter launcher instead. The WebView is kept mounted by the caller so
/// an open conversation survives closing and reopening the panel.
class ChatbotChat extends StatefulWidget {
  const ChatbotChat({
    super.key,
    required this.open,
    required this.onClosed,
  });

  /// Whether the chat panel is currently visible.
  final bool open;

  /// Called when the user closes the chat from inside the embed.
  final VoidCallback onClosed;

  @override
  State<ChatbotChat> createState() => _ChatbotChatState();
}

class _ChatbotChatState extends State<ChatbotChat> {
  late final WebViewController _controller;
  Timer? _readyTimer;
  Timer? _openTimer;

  bool _ready = false;
  bool _opened = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.mintBackground)
      ..addJavaScriptChannel(
        'HealthMateChatbot',
        onMessageReceived: _onJavaScriptMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) {
              _fail('WebView error ${error.errorCode}: ${error.description}');
            }
          },
        ),
      );
    _load();
  }

  @override
  void didUpdateWidget(covariant ChatbotChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.open && widget.open) {
      if (_failed) {
        _load(notify: true);
      } else if (_ready) {
        _openChat();
      }
    } else if (oldWidget.open && !widget.open) {
      _openTimer?.cancel();
      if (_opened) {
        _opened = false;
        unawaited(_runJavaScript(
          'window.__hmChatbot && window.__hmChatbot.setIsOpened(false);',
        ));
      }
    }
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _openTimer?.cancel();
    super.dispose();
  }

  void _load({bool notify = false}) {
    _readyTimer?.cancel();
    _openTimer?.cancel();
    _ready = false;
    _opened = false;
    _failed = false;
    if (notify && mounted) setState(() {});
    _readyTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_ready) {
        _fail('The assistant did not become ready within 30 seconds.');
      }
    });
    unawaited(_loadPage());
  }

  Future<void> _loadPage() async {
    try {
      await _controller.loadHtmlString(
        _chatbotHtml,
        baseUrl: 'https://www.noupe.com/',
      );
    } catch (error) {
      _fail('Could not load the assistant page: $error');
    }
  }

  void _onJavaScriptMessage(JavaScriptMessage message) {
    final Object? decoded;
    try {
      decoded = jsonDecode(message.message);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;

    switch (decoded['type']) {
      case 'ready':
        _ready = true;
        _readyTimer?.cancel();
        if (widget.open) _openChat();
        break;
      case 'state':
        final opened = decoded['opened'] == true;
        if (opened) {
          _openTimer?.cancel();
          if (_failed) {
            unawaited(_runJavaScript(
              'window.__hmChatbot && window.__hmChatbot.setIsOpened(false);',
            ));
            return;
          }
          if (!_opened) {
            _opened = true;
            if (mounted) setState(() {});
          }
        } else {
          final wasOpened = _opened;
          _opened = false;
          if (widget.open && wasOpened) widget.onClosed();
        }
        break;
      case 'error':
        _fail('Embed error: ${decoded['message']}');
        break;
    }
  }

  void _openChat() {
    if (!_ready || !widget.open || _failed) return;
    _openTimer?.cancel();
    _openTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_opened) {
        _fail('The assistant did not open within 10 seconds.');
      }
    });
    unawaited(_runJavaScript(
      'window.__hmChatbot && window.__hmChatbot.setIsOpened(true);',
    ));
  }

  Future<void> _runJavaScript(String script) async {
    try {
      await _controller.runJavaScript(script);
    } catch (error) {
      _fail('Assistant script failed: $error');
    }
  }

  void _fail(String reason) {
    _readyTimer?.cancel();
    _openTimer?.cancel();
    if (!mounted || _failed) return;
    debugPrint('HealthMate assistant: $reason');
    setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mintBackground,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            WebViewWidget(controller: _controller),
            if (!_failed && !_opened) _LoadingView(onClose: widget.onClosed),
            if (_failed)
              _ErrorView(
                onRetry: () => _load(notify: true),
                onClose: widget.onClosed,
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: AppColors.mintBackground,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'HealthMate assistant',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: l10n.t('close'),
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: AppColors.slate),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry, required this.onClose});

  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: AppColors.mintBackground,
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIconBadge(
                      icon: Icons.cloud_off_rounded,
                      size: 56,
                      iconSize: 26,
                      background: Colors.white,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.t('error_generic'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.t('retry')),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: l10n.t('close'),
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: AppColors.slate),
            ),
          ),
        ],
      ),
    );
  }
}

/// The exact Noupe embed, kept in one place.
///
/// Only the embed's own floating button is hidden; its chat panel remains
/// untouched. `AgentInitializer` is wrapped so the returned controller can
/// report readiness/open state back to Flutter.
const String _chatbotHtml = r'''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>HealthMate assistant</title>
<style>
  html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: transparent; overflow: hidden; }
  .chat-button-variant-2, .privacyPolicy { display: none !important; }
</style>
<script>
  window.__hmChatbot = null;
  (function () {
    function post(payload) {
      if (window.HealthMateChatbot) {
        window.HealthMateChatbot.postMessage(JSON.stringify(payload));
      }
    }
    var initializer;
    Object.defineProperty(window, 'AgentInitializer', {
      configurable: true,
      get: function () { return initializer; },
      set: function (value) {
        if (value && typeof value.init === 'function') {
          var originalInit = value.init.bind(value);
          value.init = function (options) {
            var api = originalInit(options);
            window.__hmChatbot = api;
            try {
              api.onAgentReadyChange(function (ready) {
                if (ready) post({ type: 'ready' });
              });
              api.onChatOpenStateChange(function (opened) {
                post({ type: 'state', opened: !!opened });
              });
            } catch (error) {
              post({ type: 'error', message: String(error && error.message || error) });
            }
            return api;
          };
        }
        initializer = value;
      }
    });
  })();
</script>
<script src="https://www.noupe.com/embed/01a16477e7307000884a6210c06553ca0769.js"></script>
</head>
<body></body>
</html>
''';
