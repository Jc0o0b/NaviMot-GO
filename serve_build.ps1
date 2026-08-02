$root = "C:\Users\jkowa\OneDrive\Pulpit\Claude\motorcycle_routes\build\web"
$port = 8080
$url = "http://localhost:$port/"
$mime = @{
    ".html" = "text/html; charset=utf-8"
    ".js" = "application/javascript"
    ".wasm" = "application/wasm"
    ".css" = "text/css"
    ".png" = "image/png"
    ".jpg" = "image/jpeg"
    ".svg" = "image/svg+xml"
    ".json" = "application/json"
    ".map" = "application/json"
    ".ttf" = "font/ttf"
    ".otf" = "font/otf"
    ".frag" = "text/plain"
    ".ico" = "image/x-icon"
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
$listener.Start()
Write-Output "Server running at $url"

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response

    $path = $req.Url.AbsolutePath
    if ($path -eq "/") { $path = "/index.html" }
    $filePath = [System.IO.Path]::Combine($root, $path.TrimStart('/'))

    if (Test-Path $filePath -PathType Leaf) {
        $ext = [System.IO.Path]::GetExtension($filePath)
        $contentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $res.ContentType = $contentType
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
        $res.StatusCode = 404
        $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
        $res.OutputStream.Write($msg, 0, $msg.Length)
    }
    $res.Close()
}
