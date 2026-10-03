#!/usr/bin/env python3
"""One-request, self-signed HTTPS fixture. Never changes the system keychain."""
import socket
import ssl
import subprocess
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory(prefix="uppy-tls-") as directory:
    root = Path(directory)
    subprocess.run([
        "/usr/bin/openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
        "-keyout", str(root / "key.pem"), "-out", str(root / "cert.pem"),
        "-days", "1", "-subj", "/CN=localhost",
    ], check=True)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(root / "cert.pem", root / "key.pem")
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        listener.settimeout(5)
        print(listener.getsockname()[1], flush=True)
        connection, _ = listener.accept()
        connection.settimeout(5)
        try:
            with context.wrap_socket(connection, server_side=True) as secure:
                secure.recv(4096)
                secure.sendall(b"HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n")
        except (ssl.SSLError, ConnectionResetError):
            connection.close()  # Certificate rejection is the expected client behavior.
