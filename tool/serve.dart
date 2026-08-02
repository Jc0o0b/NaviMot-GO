import 'dart:io';

const Map<String, String> _mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.json': 'application/json',
  '.map': 'application/json',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
};

Future<void> main() async {
  final root = Directory('build/web');
  final port = 8080;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stderr.writeln('Server running on http://localhost:$port');

  await for (final request in server) {
    var path = request.uri.path;
    if (path == '/' || path.isEmpty) path = '/index.html';

    // Strip the base-href prefix used for GitHub Pages builds so the same
    // release bundle works when served locally from the root.
    if (path.startsWith('/NaviMot-GO')) {
      path = path.substring('/NaviMot-GO'.length);
      if (path.isEmpty || path == '/') path = '/index.html';
    }

    final file = File('${root.path}$path');
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final ext = path.substring(path.lastIndexOf('.'));
      request.response.headers.contentType =
          ContentType.parse(_mime[ext] ?? 'application/octet-stream');
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
    } else {
      request.response.statusCode = 404;
      request.response.write('Not Found');
    }
    await request.response.close();
  }
}
