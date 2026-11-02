import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:my_own_app/apps/client_runner.dart';
import 'package:web/web.dart' as web;

/// The web: each run gets a Worker of its own, started before it is needed.
ClientRunner createClientRunner() => _WorkerRunner();

/// How long one client action may take, its server calls included.
const _timeout = Duration(seconds: 10);

/// The Worker's own code. Every message is a JSON string.
///
/// It first takes away every way to reach the network or other pages, from
/// the global and from its prototypes, keeping only its own `postMessage`.
/// Started from a `data:` URL the Worker also has an opaque origin, so not
/// even what is left can carry the person's cookies. Then it waits for one
/// `run`, and answers `done` or `error`; each `call` goes out as a message
/// and comes back as a `reply`. A `run` sent before the Worker has started
/// waits in its queue, so nothing needs to wait for `ready`; `ready` only
/// says the Worker did start.
const _source = r'''
'use strict';
const post = self.postMessage.bind(self);
const parse = JSON.parse;
const text = JSON.stringify;
for (const name of ['fetch', 'XMLHttpRequest', 'WebSocket', 'EventSource',
    'WebTransport', 'importScripts', 'Worker', 'SharedWorker',
    'BroadcastChannel', 'indexedDB', 'caches', 'Request', 'navigator']) {
  for (let o = self; o; o = Object.getPrototypeOf(o)) {
    try { delete o[name]; } catch (_) {}
  }
  try {
    Object.defineProperty(self, name, { value: undefined, writable: false, configurable: false });
  } catch (_) {}
}
let next = 0;
const waiting = new Map();
const call = (name, event) => new Promise((resolve, reject) => {
  const id = next++;
  waiting.set(id, { resolve, reject });
  post(text({ type: 'call', id, name: String(name), event: event ?? {} }));
});
let started = false;
self.onmessage = (message) => {
  const msg = parse(message.data);
  if (msg.type === 'reply') {
    const w = waiting.get(msg.id);
    if (!w) return;
    waiting.delete(msg.id);
    if (msg.error) w.reject(new Error(msg.error)); else w.resolve(msg.delta);
    return;
  }
  if (msg.type !== 'run' || started) return;
  started = true;
  Promise.resolve()
    .then(() => (0, eval)(msg.code + '\n;run')(msg.input, msg.event, call))
    .then(
      (out) => post(text({ type: 'done', patch: out ?? [] })),
      (e) => post(text({ type: 'error', error: String((e && e.message) || e) })),
    );
};
post(text({ type: 'ready' }));
''';

class _WorkerRunner implements ClientRunner {
  _WorkerRunner();

  /// A Worker already started and sandboxed, waiting for the next run.
  _Sandbox? _spare;
  bool _closed = false;

  @override
  void warm() {
    if (!_closed) _spare ??= _Sandbox();
  }

  @override
  Future<List<dynamic>> run({
    required String code,
    required Map<String, Object?> input,
    required Map<String, Object?> event,
    required ServerCall call,
  }) async {
    if (_closed) throw const ClientActionFailed('closed');
    final sandbox = _spare ?? _Sandbox();
    // The next run's Worker starts now, while this one runs.
    _spare = _Sandbox();
    final session = _Session(
      sandbox: sandbox,
      run: jsonEncode({
        'type': 'run',
        'code': code,
        'input': input,
        'event': event,
      }),
      call: call,
    );
    try {
      return await session.done.future.timeout(_timeout);
    } on TimeoutException {
      throw const ClientActionFailed('too long');
    } finally {
      sandbox.close();
    }
  }

  @override
  void close() {
    _closed = true;
    _spare?.close();
    _spare = null;
  }
}

/// One Worker, used for one run at most.
class _Sandbox {
  _Sandbox() {
    _start(opaque: _opaqueWorks);
  }

  /// Whether this browser starts a Worker from a `data:` URL. Once it has
  /// refused, later Workers start from the Blob straight away.
  static bool _opaqueWorks = true;

  static final _dataUrl =
      'data:text/javascript;charset=utf-8,${Uri.encodeComponent(_source)}';

  static final String _blobUrl = web.URL.createObjectURL(
    web.Blob(
      [_source.toJS].toJS,
      web.BlobPropertyBag(type: 'text/javascript'),
    ),
  );

  web.Worker? _worker;
  bool _ready = false;
  bool _closed = false;

  /// Why the Worker could not start, before anyone was listening.
  String? _failed;

  /// The run given to it, sent again if the Worker has to restart.
  String? _run;
  void Function(Map<String, dynamic>)? _onMessage;
  void Function(String)? _onFail;

  void _start({required bool opaque}) {
    final web.Worker worker;
    try {
      worker = web.Worker((opaque ? _dataUrl : _blobUrl).toJS);
    } on Object {
      if (opaque) {
        _opaqueWorks = false;
        return _start(opaque: false);
      }
      return _fail('no worker');
    }
    _worker = worker;
    worker
      ..onmessage = _receive.toJS
      ..onerror = ((web.Event _) {
        // A browser that will not start a Worker from a data: URL says so
        // here, before it is ready: start it from a Blob instead.
        if (!_ready && opaque) {
          _opaqueWorks = false;
          worker.terminate();
          _start(opaque: false);
        } else {
          _fail('worker error');
        }
      }).toJS;
    final run = _run;
    if (run != null) post(run);
  }

  /// Gives it its one run; what it says from then on goes to [onMessage].
  void begin(
    String run, {
    required void Function(Map<String, dynamic>) onMessage,
    required void Function(String) onFail,
  }) {
    _run = run;
    _onMessage = onMessage;
    _onFail = onFail;
    final failed = _failed;
    if (failed != null) return onFail(failed);
    post(run);
  }

  void _receive(web.MessageEvent message) {
    final data = message.data;
    if (data == null || !data.isA<JSString>()) return;
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode((data as JSString).toDart) as Map<String, dynamic>;
    } on Object {
      return;
    }
    if (msg['type'] == 'ready') {
      _ready = true;
      return;
    }
    _onMessage?.call(msg);
  }

  void _fail(String reason) {
    final onFail = _onFail;
    onFail != null ? onFail(reason) : _failed = reason;
  }

  void post(String message) {
    if (!_closed) _worker?.postMessage(message.toJS);
  }

  void close() {
    _closed = true;
    _worker?.terminate();
  }
}

/// One run: the messages to and from its Worker.
class _Session {
  _Session({required this.sandbox, required String run, required this.call}) {
    sandbox.begin(run, onMessage: _receive, onFail: _fail);
  }

  final _Sandbox sandbox;
  final ServerCall call;
  final done = Completer<List<dynamic>>();

  /// What a server call failed with, so the person reads the server's words
  /// rather than the action's.
  Object? _callError;

  void _receive(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'call':
        unawaited(_call(msg));
      case 'done':
        final patch = msg['patch'];
        if (done.isCompleted) return;
        patch is List
            ? done.complete(patch)
            : _fail('run did not return a patch');
      case 'error':
        if (done.isCompleted) return;
        final error = _callError;
        error != null ? done.completeError(error) : _fail('${msg['error']}');
    }
  }

  Future<void> _call(Map<String, dynamic> msg) async {
    final event = msg['event'];
    try {
      final delta = await call(
        '${msg['name']}',
        event is Map<String, dynamic> ? event : const {},
      );
      sandbox.post(
        jsonEncode({'type': 'reply', 'id': msg['id'], 'delta': delta}),
      );
    } on Object catch (error) {
      _callError = error;
      sandbox.post(
        jsonEncode({'type': 'reply', 'id': msg['id'], 'error': 'failed'}),
      );
    }
  }

  void _fail(String reason) {
    if (!done.isCompleted) done.completeError(ClientActionFailed(reason));
  }
}
