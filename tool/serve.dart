import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final root = Directory('../build/web');
  final port = 8080;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('Server running on http://localhost:$port');

  await for (final request in server) {
    final path = request.uri.path == '/' ? '/index.html' : request.uri.path;
    final file = File('${root.path}$path');
    final mime = <String, String>{
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

    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final ext = path.substring(path.lastIndexOf('.'));
      request.response.headers.contentType = ContentType.parse(mime[ext] ?? 'application/octet-stream');
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
    } else {
      request.response.statusCode = 404;
      request.response.write('Not Found');
    }
    await request.response.close();
  }
}
