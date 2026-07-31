#!/usr/bin/env python3
"""Minimal parent socket server to run SettingsApp standalone for debugging."""
import socket, os, sys, struct, time, threading, signal, subprocess, select

SOCKET_PATH = "/tmp/test_settings_dmabuf.sock"

def main():
    # Clean up old socket
    try: os.unlink(SOCKET_PATH)
    except: pass

    # Create server socket
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(1)
    print(f"[Parent] Listening on {SOCKET_PATH}", flush=True)

    # Launch SettingsApp
    env = os.environ.copy()
    env["FLUTTER_DMABUF_SOCKET"] = SOCKET_PATH
    env["LD_LIBRARY_PATH"] = os.path.abspath("../engine/src/out/host_debug")

    proc = subprocess.Popen(
        ["stdbuf", "-oL", ".build/debug/SettingsApp"],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    print(f"[Parent] Launched SettingsApp pid={proc.pid}", flush=True)

    # Accept connection with timeout
    server.settimeout(10)
    try:
        conn, addr = server.accept()
        print("[Parent] Child connected", flush=True)
    except socket.timeout:
        print("[Parent] Timeout waiting for child", flush=True)
        # Print any child output
        proc.terminate()
        out = proc.stdout.read()
        print(out.decode('utf-8', errors='replace'), flush=True)
        return

    # Receive DMA-BUF fd + metadata via SCM_RIGHTS
    try:
        msg, ancdata, flags, addr2 = conn.recvmsg(16, socket.CMSG_SPACE(4))
        if msg:
            w, h, s, f = struct.unpack('iiii', msg[:16])
            print(f"[Parent] DMA-BUF meta: {w}x{h} stride={s} fourcc=0x{f:08x}", flush=True)
        for cmsg_level, cmsg_type, cmsg_data in ancdata:
            if cmsg_level == socket.SOL_SOCKET and cmsg_type == socket.SCM_RIGHTS:
                fds = struct.unpack('i' * (len(cmsg_data) // 4), cmsg_data)
                for fd in fds:
                    os.close(fd)
                print(f"[Parent] Got {len(fds)} fd(s)", flush=True)
    except Exception as e:
        print(f"[Parent] recvmsg error: {e}", flush=True)

    conn.setblocking(False)
    frame_count = 0
    last_report = time.time()

    # Main loop: read child stdout + socket
    try:
        start = time.time()
        while time.time() - start < 15:  # Run for 15 seconds
            # Check child stdout (non-blocking)
            if proc.stdout and select.select([proc.stdout], [], [], 0.1)[0]:
                line = proc.stdout.readline()
                if line:
                    sys.stdout.write(line.decode('utf-8', errors='replace'))
                    sys.stdout.flush()

            # Check socket for frame signals
            try:
                data = conn.recv(4096)
                if data:
                    frame_count += len(data)
            except BlockingIOError:
                pass

            now = time.time()
            if now - last_report >= 2.0:
                print(f"[Parent] {frame_count} frame signals in 2s", flush=True)
                frame_count = 0
                last_report = now

            if proc.poll() is not None:
                print(f"[Parent] Child exited with code {proc.returncode}", flush=True)
                break
    except KeyboardInterrupt:
        pass
    finally:
        proc.terminate()
        try: proc.wait(timeout=3)
        except: proc.kill()
        conn.close()
        server.close()
        try: os.unlink(SOCKET_PATH)
        except: pass
        print("[Parent] Done", flush=True)

if __name__ == "__main__":
    main()
