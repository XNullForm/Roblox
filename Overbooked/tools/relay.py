# Receives script sources POSTed from Studio and saves them.
# python relay.py  (port 8793)  ->  POST /<name>  body = source  ->  live/<name>
import http.server, os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.environ.get("RELAY_DIR","live"))
os.makedirs(ROOT, exist_ok=True)


class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        name = os.path.basename(self.path.strip("/")) or "unnamed.txt"
        n = int(self.headers.get("Content-Length", 0))
        data = self.rfile.read(n)
        with open(os.path.join(ROOT, name), "wb") as f:
            f.write(data)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *a):
        pass


port = int(sys.argv[1]) if len(sys.argv) > 1 else 8793
http.server.ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
