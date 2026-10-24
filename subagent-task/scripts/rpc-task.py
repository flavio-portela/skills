#!/usr/bin/env python3
"""Run a Pi RPC child with live activity logs, or answer its question."""

import json
import os
import selectors
import signal
import socket
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

BASE = Path(os.environ.get("PI_TASK_ROOT", "/tmp/pi-tasks"))


def write_atomic(path, value):
    fd, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            output.write(value)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def answer(slug, message):
    scratch = BASE / slug
    question_id = (scratch / ".question-id").read_text().strip()
    with socket.socket(socket.AF_UNIX) as conn:
        conn.settimeout(15)
        conn.connect(str(scratch / "control.sock"))
        conn.sendall((json.dumps({"id": question_id, "answer": message}) + "\n").encode())
        response = b""
        while not response.endswith(b"\n"):
            part = conn.recv(4096)
            if not part:
                raise RuntimeError("RPC controller closed without acknowledging the answer")
            response += part
    result = json.loads(response)
    if not result.get("ok"):
        raise RuntimeError(result.get("error", "answer rejected"))
    print("answer accepted by Pi — waiting for the child")


class Controller:
    def __init__(self, slug, pi_bin, model):
        self.slug = slug
        self.scratch = BASE / slug
        self.socket_path = self.scratch / "control.sock"
        self.activity = (self.scratch / "activity.log").open("w", buffering=1)
        self.events = (self.scratch / "events.jsonl").open("w", buffering=1)
        self.stderr = (self.scratch / "stderr.log").open("w")
        self.selector = selectors.DefaultSelector()
        self.buffer = b""
        self.pending_report = None
        self.report_calls = set()
        self.question_id = None
        self.answer_conn = None
        self.answer_id = None
        self.at_line_start = True
        self.finished = False
        self.turn_error = False
        self.phase = "starting"
        self.action = "Reading brief"
        self.context_usage = None
        self.model = model
        self.stats_counter = 0
        command = [pi_bin, "--mode", "rpc", "--approve", "--name", f"task-{slug}",
                   "--extension", str(Path(__file__).with_name("task-report.ts"))]
        if model:
            command += ["--model", model]
        self.pi = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=self.stderr, cwd=os.getcwd(), bufsize=0)
        self.server = socket.socket(socket.AF_UNIX)
        self.server.bind(str(self.socket_path))
        os.chmod(self.socket_path, 0o600)
        self.server.listen(1)
        self.selector.register(self.server, selectors.EVENT_READ)
        self.selector.register(self.pi.stdout, selectors.EVENT_READ)

    def show(self, text):
        sys.stdout.write(text)
        sys.stdout.flush()
        self.activity.write(text)
        self.activity.flush()
        self.at_line_start = text.endswith("\n")

    def line(self, text):
        if not self.at_line_start:
            self.show("\n")
        self.show(text + "\n")

    def send(self, record):
        self.pi.stdin.write((json.dumps(record) + "\n").encode())
        self.pi.stdin.flush()

    def publish(self):
        write_atomic(self.scratch / "view.json", json.dumps({
            "slug": self.slug, "phase": self.phase, "action": self.action,
            "model": self.model, "contextUsage": self.context_usage,
        }, ensure_ascii=False))

    def request_stats(self):
        self.stats_counter += 1
        self.send({"id": f"stats-{self.stats_counter}", "type": "get_session_stats"})

    def fail(self, reason):
        self.line(f"[error] {reason}")
        self.phase, self.action = "error", reason
        self.publish()
        write_atomic(self.scratch / "status", f"exited: {reason}\n")
        self.finished = True

    def respond(self, conn, result):
        try:
            conn.sendall((json.dumps(result) + "\n").encode())
        except OSError:
            pass
        conn.close()

    def accept_answer(self):
        conn, _ = self.server.accept()
        try:
            conn.settimeout(2)
            request = b""
            while not request.endswith(b"\n"):
                part = conn.recv(4096)
                if not part or len(request) + len(part) > 100_000:
                    raise ValueError("invalid answer")
                request += part
            data = json.loads(request)
            if not isinstance(data, dict):
                raise ValueError("answer request must be a JSON object")
            if not self.question_id or data.get("id") != self.question_id or self.answer_conn:
                self.respond(conn, {"ok": False, "error": "question is no longer pending"})
                return
            self.answer_id = f"answer-{uuid.uuid4().hex}"
            self.answer_conn = conn
            self.send({"id": self.answer_id, "type": "prompt",
                       "message": f"Answer to question {self.question_id}:\n{data['answer']}"})
        except (OSError, ValueError, KeyError, TypeError) as exc:
            self.respond(conn, {"ok": False, "error": str(exc)})

    def event(self, event):
        kind = event.get("type")
        if kind == "response":
            if event.get("id") == "state" and event.get("success"):
                data = event.get("data", {})
                session = data.get("sessionFile")
                if session:
                    write_atomic(self.scratch / ".session-file", session + "\n")
                model = data.get("model") or {}
                if model.get("id"):
                    self.model = f"{model.get('provider', '?')}/{model['id']}"
                    self.publish()
            elif str(event.get("id", "")).startswith("stats-") and event.get("success"):
                self.context_usage = event.get("data", {}).get("contextUsage")
                self.publish()
            elif event.get("id") == "initial" and not event.get("success"):
                self.fail(f"initial prompt rejected: {event.get('error')}")
            elif event.get("id") == self.answer_id:
                conn, self.answer_conn = self.answer_conn, None
                self.answer_id = None
                if event.get("success") and event.get("data", {}).get("disposition") == "started":
                    (self.scratch / "ask").unlink(missing_ok=True)
                    (self.scratch / ".question-id").unlink(missing_ok=True)
                    self.question_id = None
                    self.pending_report = None
                    self.turn_error = False
                    self.phase, self.action = "running", "Answer received"
                    self.publish()
                    self.respond(conn, {"ok": True})
                    self.line("[answer accepted; child running]")
                else:
                    self.respond(conn, {"ok": False, "error": event.get("error", "prompt did not start")})
            return
        if kind == "message_end" and event.get("message", {}).get("role") == "assistant":
            if event["message"].get("stopReason") in ("error", "aborted"):
                self.turn_error = True
        elif kind == "turn_end":
            self.request_stats()
        elif kind == "compaction_start":
            self.context_usage = None
            self.action = "Compacting context"
            self.publish()
        elif kind == "compaction_end":
            self.request_stats()
        elif kind == "message_update":
            delta = event.get("assistantMessageEvent", {})
            if delta.get("type") in ("text_delta", "thinking_delta"):
                if self.at_line_start:
                    self.show("[thinking] " if delta["type"] == "thinking_delta" else "[assistant] ")
                self.show(delta.get("delta", ""))
        elif kind == "tool_execution_start":
            name = event.get("toolName", "?")
            if self.pending_report is not None:
                self.fail("child used another tool after task_report")
                return
            if name == "task_report":
                self.report_calls.add(event.get("toolCallId"))
                self.action = "Reporting outcome"
            else:
                args = json.dumps(event.get("args", {}), ensure_ascii=False)
                self.line(f"[tool] {name} {args[:180]}{'…' if len(args) > 180 else ''}")
                self.action = f"{name}: {args[:100]}"
            self.publish()
        elif kind == "tool_execution_end":
            if event.get("toolCallId") in self.report_calls:
                self.report_calls.remove(event.get("toolCallId"))
                if event.get("isError") or self.pending_report is not None:
                    self.fail("task_report failed or was called more than once")
                else:
                    self.pending_report = event.get("result", {}).get("details")
            else:
                failed = event.get("isError")
                self.line(f"[tool {'error' if failed else 'done'}] {event.get('toolName', '?')}")
                self.action = f"{'Failed' if failed else 'Finished'} {event.get('toolName', '?')}"
                self.publish()
                content = event.get("result", {}).get("content", [])
                output = "\n".join(item.get("text", "") for item in content if item.get("type") == "text").strip()
                if output:
                    excerpt = output[-600:] if failed else output[-240:]
                    for line in excerpt.splitlines():
                        self.line(f"  {line}")
        elif kind == "agent_settled":
            if event.get("aborted") or self.turn_error or not isinstance(self.pending_report, dict):
                self.fail("child stopped without a successful task_report")
                return
            report = self.pending_report
            status = report.get("status")
            message = report.get("message", "").strip()
            if status not in ("question", "blocked", "done") or not message:
                self.fail("invalid task_report")
                return
            if status == "question":
                self.question_id = uuid.uuid4().hex
                write_atomic(self.scratch / ".question-id", self.question_id + "\n")
                write_atomic(self.scratch / "ask", message + "\n")
                self.line(f"[question] {message}")
            else:
                write_atomic(self.scratch / "report.txt", report.get("report") or message)
                write_atomic(self.scratch / ("done" if status == "done" else "blocked"), message + "\n")
                self.line(f"[{status}] {message}")
                self.finished = True
            self.phase, self.action = status, message
            self.publish()

    def run(self):
        self.line(f"[task {self.slug}] RPC activity — raw events: {self.scratch / 'events.jsonl'}")
        self.phase = "running"
        self.publish()
        self.send({"id": "state", "type": "get_state"})
        self.send({"id": "initial", "type": "prompt", "message": (
            f"Read {self.scratch / 'brief.md'} in full and carry out exactly that task. "
            "To ask a question, report a blocker, or finish, call task_report with status "
            "question, blocked, or done. Include the complete verification and files touched "
            "in report when finishing. Call task_report as your LAST tool action, then end "
            "your turn. Do not proceed past a question or claim success without verification."
        )})
        try:
            while not self.finished:
                for key, _ in self.selector.select(timeout=1):
                    if key.fileobj is self.server:
                        self.accept_answer()
                    else:
                        chunk = os.read(self.pi.stdout.fileno(), 65536)
                        if not chunk:
                            self.fail(f"Pi RPC process exited ({self.pi.poll()})")
                            break
                        self.buffer += chunk
                        while b"\n" in self.buffer and not self.finished:
                            raw, self.buffer = self.buffer.split(b"\n", 1)
                            self.events.write(raw.decode("utf-8", errors="replace") + "\n")
                            try:
                                self.event(json.loads(raw))
                            except (ValueError, TypeError) as exc:
                                self.fail(f"invalid RPC event: {exc}")
        finally:
            if self.answer_conn:
                self.respond(self.answer_conn, {"ok": False, "error": "controller stopped"})
            self.selector.close()
            self.server.close()
            self.socket_path.unlink(missing_ok=True)
            if not self.pi.stdin.closed:
                self.pi.stdin.close()
            if self.pi.poll() is None:
                try:
                    self.pi.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.pi.terminate()
                    try:
                        self.pi.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        self.pi.kill()
                        self.pi.wait()
            self.pi.stdout.close()
            self.activity.close()
            self.events.close()
            self.stderr.close()
        return 0 if (self.scratch / "done").exists() else 1


if __name__ == "__main__":
    try:
        if sys.argv[1] == "send":
            answer(sys.argv[2], sys.argv[3])
        elif sys.argv[1] == "run":
            signal.signal(signal.SIGTERM, lambda *_: sys.exit(1))
            sys.exit(Controller(sys.argv[2], sys.argv[3], sys.argv[4]).run())
        else:
            raise ValueError("expected run or send")
    except (OSError, ValueError, RuntimeError, IndexError) as error:
        print(f"RPC task: {error}", file=sys.stderr)
        sys.exit(3)
