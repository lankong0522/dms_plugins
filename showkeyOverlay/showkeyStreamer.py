#!/usr/bin/env python3
import argparse
import ctypes
import fcntl
import json
import os
import re
import select
import shutil
import signal
import subprocess
import sys
import threading
import time
from dataclasses import dataclass

MOD_KEY_MAP = {
    "KEY_LEFTCTRL": "Ctrl",
    "KEY_RIGHTCTRL": "Ctrl",
    "KEY_LEFTALT": "Alt",
    "KEY_RIGHTALT": "Alt",
    "KEY_LEFTSHIFT": "Shift",
    "KEY_RIGHTSHIFT": "Shift",
    "KEY_LEFTMETA": "Super",
    "KEY_RIGHTMETA": "Super",
    "KEY_COMPOSE": "Compose",
}

SPECIAL_KEY_MAP = {
    "KEY_SPACE": "Space",
    "KEY_ENTER": "Enter",
    "KEY_ESC": "Esc",
    "KEY_BACKSPACE": "Backspace",
    "KEY_TAB": "Tab",
    "KEY_DELETE": "Delete",
    "KEY_INSERT": "Insert",
    "KEY_HOME": "Home",
    "KEY_END": "End",
    "KEY_PAGEUP": "PageUp",
    "KEY_PAGEDOWN": "PageDown",
    "KEY_UP": "↑",
    "KEY_DOWN": "↓",
    "KEY_LEFT": "←",
    "KEY_RIGHT": "→",
    "KEY_CAPSLOCK": "CapsLock",
    "KEY_NUMLOCK": "NumLock",
    "KEY_SYSRQ": "PrintScreen",
    "KEY_PRINT": "PrintScreen",
    "KEY_SLASH": "/",
    "KEY_BACKSLASH": "\\",
    "KEY_DOT": ".",
    "KEY_COMMA": ",",
    "KEY_MINUS": "-",
    "KEY_EQUAL": "=",
    "KEY_SEMICOLON": ";",
    "KEY_APOSTROPHE": "'",
    "KEY_GRAVE": "`",
    "KEY_LEFTBRACE": "[",
    "KEY_RIGHTBRACE": "]",
}

MOD_ORDER = ["Ctrl", "Alt", "Shift", "Super", "Compose"]

IN_CLOSE_WRITE = 0x00000008
IN_MOVED_TO = 0x00000080
IN_CREATE = 0x00000100
IN_DELETE = 0x00000200
IN_NONBLOCK = 0x00000800
IN_CLOEXEC = 0x00080000


@dataclass
class KeyRow:
    text: str
    expires_at: float


class RuntimePaths:
    def __init__(self):
        self.runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
        self.lock_path = os.path.join(self.runtime_dir, "showkey-overlay-dms-streamer.lock")
        self.state_path = os.path.join(self.runtime_dir, "showkey-overlay-dms-state.json")


class KeyStreamer:
    def __init__(self, timeout: float, max_rows: int, min_interval: float):
        self.timeout = max(0.1, timeout)
        self.max_rows = max(1, max_rows)
        self.min_interval = max(0.0, min_interval)
        self.paths = RuntimePaths()
        self.rows = []
        self.pressed_mods = set()
        self.condition = threading.Condition()
        self.child = None
        self.running = True
        self.last_text = ""
        self.last_time = 0.0
        self.last_output = None
        self.lock_file = None
        self.is_leader = False

    def try_acquire_lock(self) -> bool:
        os.makedirs(self.paths.runtime_dir, exist_ok=True)
        if self.lock_file is None or self.lock_file.closed:
            self.lock_file = open(self.paths.lock_path, "w", encoding="utf-8")
        try:
            fcntl.flock(self.lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.is_leader = True
            return True
        except BlockingIOError:
            self.is_leader = False
            return False

    def release_lock(self):
        if self.lock_file is not None and not self.lock_file.closed:
            try:
                fcntl.flock(self.lock_file, fcntl.LOCK_UN)
            except Exception:
                pass
            try:
                self.lock_file.close()
            except Exception:
                pass
        self.lock_file = None
        self.is_leader = False

    @staticmethod
    def normalize_key(key_name: str) -> str:
        if key_name in MOD_KEY_MAP:
            return MOD_KEY_MAP[key_name]

        if key_name in SPECIAL_KEY_MAP:
            return SPECIAL_KEY_MAP[key_name]

        if key_name.startswith("KEY_"):
            name = key_name[4:]

            if len(name) == 1:
                return name

            if re.fullmatch(r"F\d{1,2}", name):
                return name

            if name.startswith("KP"):
                return name.replace("KP", "Num")

            return name.replace("_", " ").title().replace(" ", "")

        return key_name

    def ordered_mods(self):
        return [mod for mod in MOD_ORDER if mod in self.pressed_mods]

    def emit(self, text: str):
        payload = json.dumps({"text": text}, ensure_ascii=False)
        print(payload, flush=True)

    def emit_error(self, message: str):
        payload = json.dumps({"text": "", "error": message}, ensure_ascii=False)
        print(payload, flush=True)

    def write_state(self, text: str):
        payload = json.dumps({"text": text}, ensure_ascii=False)
        tmp_path = self.paths.state_path + ".tmp"
        os.makedirs(self.paths.runtime_dir, exist_ok=True)
        with open(tmp_path, "w", encoding="utf-8") as file:
            file.write(payload)
        os.replace(tmp_path, self.paths.state_path)

    def read_state(self) -> str:
        try:
            with open(self.paths.state_path, "r", encoding="utf-8") as file:
                payload = json.loads(file.read() or "{}")
            return str(payload.get("text", ""))
        except FileNotFoundError:
            return ""
        except Exception:
            return ""

    def publish(self, text: str):
        self.write_state(text)
        self.emit(text)

    def prune_expired_locked(self, now: float):
        self.rows[:] = [row for row in self.rows if row.expires_at > now]

    def build_output_locked(self) -> str:
        return "\n".join(row.text for row in self.rows)

    def add_row(self, text: str):
        now = time.monotonic()

        with self.condition:
            if text == self.last_text and now - self.last_time < self.min_interval:
                return

            self.last_text = text
            self.last_time = now
            self.rows.append(KeyRow(text=text, expires_at=now + self.timeout))

            while len(self.rows) > self.max_rows:
                self.rows.pop(0)

            self.condition.notify_all()

    def handle_event(self, event):
        if event.get("event_name") != "KEYBOARD_KEY":
            return

        key_name = event.get("key_name", "")
        state = event.get("state_name", "")

        if key_name in MOD_KEY_MAP:
            mod = MOD_KEY_MAP[key_name]
            if state == "PRESSED":
                self.pressed_mods.add(mod)
            elif state == "RELEASED":
                self.pressed_mods.discard(mod)
            return

        if state not in ("PRESSED", "REPEATED"):
            return

        key = self.normalize_key(key_name)
        mods = self.ordered_mods()
        text = " + ".join(mods + [key]) if mods else key
        self.add_row(text)

    def read_showmethekey_output(self):
        if self.child is None or self.child.stdout is None:
            return

        for line in self.child.stdout:
            if not self.running:
                break
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            self.handle_event(event)

    def output_loop(self):
        while self.running:
            with self.condition:
                now = time.monotonic()
                self.prune_expired_locked(now)
                output = self.build_output_locked()

                if output != self.last_output:
                    self.publish(output)
                    self.last_output = output

                if self.rows:
                    next_expiration = min(row.expires_at for row in self.rows)
                    wait_time = max(0.01, next_expiration - time.monotonic())
                else:
                    wait_time = None

                self.condition.wait(timeout=wait_time)

    def stop_child(self):
        if self.child and self.child.poll() is None:
            try:
                if self.child.stdin:
                    self.child.stdin.write("stop\n")
                    self.child.stdin.flush()
            except Exception:
                pass

            try:
                self.child.terminate()
            except Exception:
                pass

    def stop(self, signum=None, frame=None):
        self.running = False
        with self.condition:
            self.rows.clear()
            self.condition.notify_all()
        if self.is_leader:
            self.publish("")
            self.stop_child()
        self.release_lock()
        sys.exit(0)

    def leader_loop(self):
        cli = shutil.which("showmethekey-cli")
        pkexec = shutil.which("pkexec")

        if not cli:
            self.emit_error("showmethekey-cli not found")
            sys.exit(1)

        if not pkexec:
            self.emit_error("pkexec not found")
            sys.exit(1)

        try:
            self.child = subprocess.Popen(
                [pkexec, cli],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1,
            )
        except OSError as exc:
            self.emit_error(f"failed to start showmethekey-cli: {exc}")
            sys.exit(1)

        self.publish("")

        reader_thread = threading.Thread(target=self.read_showmethekey_output, daemon=True)
        writer_thread = threading.Thread(target=self.output_loop, daemon=True)
        reader_thread.start()
        writer_thread.start()

        try:
            while self.running:
                time.sleep(1)
        finally:
            self.stop_child()
            self.publish("")
            self.release_lock()

    def follower_loop(self):
        last_text = None
        initial = self.read_state()
        self.emit(initial)
        last_text = initial

        watcher = InotifyWatcher(self.paths.runtime_dir)
        try:
            while self.running:
                if self.try_acquire_lock():
                    self.leader_loop()
                    return

                changed = watcher.wait(timeout=2.0)
                if changed:
                    current = self.read_state()
                    if current != last_text:
                        self.emit(current)
                        last_text = current
                else:
                    current = self.read_state()
                    if current != last_text:
                        self.emit(current)
                        last_text = current
        finally:
            watcher.close()
            self.release_lock()

    def start(self):
        signal.signal(signal.SIGINT, self.stop)
        signal.signal(signal.SIGTERM, self.stop)

        if self.try_acquire_lock():
            self.leader_loop()
        else:
            self.follower_loop()


class InotifyWatcher:
    def __init__(self, directory: str):
        self.directory = directory
        self.fd = -1
        self.wd = -1
        self.libc = None
        self.available = False
        self.setup()

    def setup(self):
        try:
            self.libc = ctypes.CDLL("libc.so.6", use_errno=True)
            self.fd = self.libc.inotify_init1(IN_NONBLOCK | IN_CLOEXEC)
            if self.fd < 0:
                return
            mask = IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE | IN_DELETE
            self.wd = self.libc.inotify_add_watch(self.fd, self.directory.encode(), mask)
            if self.wd < 0:
                os.close(self.fd)
                self.fd = -1
                return
            self.available = True
        except Exception:
            self.available = False
            if self.fd >= 0:
                try:
                    os.close(self.fd)
                except Exception:
                    pass
                self.fd = -1

    def wait(self, timeout: float) -> bool:
        if not self.available or self.fd < 0:
            time.sleep(timeout)
            return True

        ready, _, _ = select.select([self.fd], [], [], timeout)
        if not ready:
            return False
        try:
            os.read(self.fd, 65536)
        except BlockingIOError:
            pass
        except OSError:
            return False
        return True

    def close(self):
        if self.fd >= 0:
            try:
                os.close(self.fd)
            except Exception:
                pass
            self.fd = -1


def parse_args():
    parser = argparse.ArgumentParser(description="Multi-instance key streamer for DMS ShowKey Overlay")
    parser.add_argument("--timeout", type=float, default=1.8, help="Seconds before each key row disappears")
    parser.add_argument("--max-rows", type=int, default=6, help="Maximum number of displayed rows")
    parser.add_argument("--min-interval", type=float, default=0.05, help="Minimum interval for deduplicating identical key text")
    return parser.parse_args()


def main():
    args = parse_args()
    streamer = KeyStreamer(timeout=args.timeout, max_rows=args.max_rows, min_interval=args.min_interval)
    streamer.start()


if __name__ == "__main__":
    main()
