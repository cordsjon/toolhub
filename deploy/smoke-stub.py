#!/usr/bin/env python3
"""Stub of NPM+toolhub for deploy/test-smoke-live.sh. STUB_MODE: ok|badcookie|backend-down|exposed|forbidden."""
import os, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

MODE = os.environ.get("STUB_MODE", "ok")

class H(BaseHTTPRequestHandler):
    def do_HEAD(self): self._h()
    def do_GET(self): self._h()
    def _h(self):
        path = self.path.split("?")[0]
        has_cookie = "session_token=good" in self.headers.get("Cookie", "")
        if MODE == "backend-down": self.send_response(500)
        elif MODE == "exposed": self.send_response(200)
        elif not has_cookie or MODE == "badcookie":
            self.send_response(302); self.send_header("Location", f"/login?next={path}")
        elif MODE == "forbidden": self.send_response(403)
        else:
            self.send_response(200)
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "credentialless")
        self.end_headers()
    def log_message(self, *a): pass

HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
