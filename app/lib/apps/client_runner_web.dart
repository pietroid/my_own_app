import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:my_own_app/apps/client_runner.dart';
import 'package:web/web.dart' as web;

/// The web: each run gets a Worker of its own.
ClientRunner createClientRunner() => const _WorkerRunner();

/// How long one client action may take, its server calls included.
const _timeout = Duration(seconds: 10);

/// The Worker's own code. Every message is a JSON string.
///
/// It first takes away every way to reach the network or other pages, from
/// the global and from its prototypes, keeping only its own `postMessage`.
/// Started from a `data:` URL the Worker also has an opaque origin, so not
/// even what is left can carry the person's cookies. Then it waits for one
/// `run`, and answers `done` or `error`; each `call` goes out as a message
/// and comes back as a `reply`.
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
  const _WorkerRunner();

  @override
  Future<List<dynamic>> run({
    required String code,
    required Map<String, Object?> input,
    required Map<String, Object?> event,
    required ServerCall call,
  }) async {
    final run = jsonEncode({
      'type': 'run',
      'code': code,
      'input': input,
      'event': event,
    });
    final session = _Session(run: run, call: call);
    try {
      return await session.done.future.timeout(_timeout);
    } on TimeoutException {
      throw const ClientActionFailed('too long');
    } finally {
      session.close();
    }
  }
}

/// One run: the Worker, and the messages to and from it.
class _Session {
  _Session({required this.run, required this.call}) {
    _start(opaque: true);
  }

  final String run;
  final ServerCall call;
  final done = Completer<List<dynamic>>();

  web.Worker? _worker;
  String? _blobUrl;
  bool _ready = false;

  /// What a server call failed with, so the person reads the server's words
  /// rather than the action's.
  Object? _callError;

  void _start({required bool opaque}) {
    final web.Worker worker;
    try {
      worker = web.Worker(_url(opaque: opaque).toJS);
    } on Object {
      if (opaque) return _start(opaque: false);
      return _fail('no worker');
    }
    _worker = worker;
    worker
      ..onmessage = _receive.toJS
      ..onerror = ((web.Event _) {
        // A browser that will not start a Worker from a data: URL says so
        // here, before it is ready: start it from a Blob instead.
        if (!_ready && opaque) {
          worker.terminate();
          _start(opaque: false);
        } else {
          _fail('worker error');
        }
      }).toJS;
  }

  String _url({required bool opaque}) {
    if (opaque) {
      return 'data:text/javascript;charset=utf-8,'
          '${Uri.encodeComponent(_source)}';
    }
    final blob = web.Blob(
      [_source.toJS].toJS,
      web.BlobPropertyBag(type: 'text/javascript'),
    );
    return _blobUrl = web.URL.createObjectURL(blob);
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
    switch (msg['type']) {
      case 'ready':
        _ready = true;
        _post(run);
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
      _post(jsonEncode({'type': 'reply', 'id': msg['id'], 'delta': delta}));
    } on Object catch (error) {
      _callError = error;
      _post(jsonEncode({'type': 'reply', 'id': msg['id'], 'error': 'failed'}));
    }
  }

  void _post(String message) => _worker?.postMessage(message.toJS);

  void _fail(String reason) {
    if (!done.isCompleted) done.completeError(ClientActionFailed(reason));
  }

  void close() {
    _worker?.terminate();
    final url = _blobUrl;
    if (url != null) web.URL.revokeObjectURL(url);
  }
}
