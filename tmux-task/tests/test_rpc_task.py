"""Exercise the RPC question/answer lifecycle without calling a model."""

import importlib.util
import json
import socket
import tempfile
import threading
import time
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "rpc-task.py"
spec = importlib.util.spec_from_file_location("rpc_task", SCRIPT)
rpc_task = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rpc_task)

MOCK_PI = '''#!/usr/bin/env python3
import json, sys

def emit(record):
    print(json.dumps(record), flush=True)

for raw in sys.stdin:
    command = json.loads(raw)
    if command["type"] == "get_state":
        emit({"type": "response", "id": command["id"], "success": True, "data": {}})
        continue
    if command["type"] == "get_session_stats":
        emit({"type": "response", "id": command["id"], "success": True,
              "data": {"contextUsage": {"tokens": 1200, "contextWindow": 8192,
                                         "percent": 14.6}}})
        continue
    emit({"type": "response", "id": command["id"], "success": True,
          "data": {"disposition": "started"}})
    outcome = "question" if command["id"] == "initial" else "done"
    emit({"type": "message_update", "assistantMessageEvent":
          {"type": "text_delta", "delta": "Working\\n"}})
    emit({"type": "tool_execution_start", "toolCallId": command["id"],
          "toolName": "task_report", "args": {"status": outcome}})
    emit({"type": "tool_execution_end", "toolCallId": command["id"],
          "toolName": "task_report", "isError": False,
          "result": {"details": {"status": outcome,
                                 "message": "Which option?" if outcome == "question" else "Finished",
                                 "report": "Verification: passed"}}})
    emit({"type": "turn_end"})
    emit({"type": "agent_settled", "aborted": False})
'''


class RpcTaskTest(unittest.TestCase):
    def test_question_answer_and_visibility(self):
        with tempfile.TemporaryDirectory() as temp:
            rpc_task.BASE = Path(temp)
            scratch = rpc_task.BASE / "test"
            scratch.mkdir()
            (scratch / "brief.md").write_text("Mock task")
            fake_pi = Path(temp) / "mock-pi"
            fake_pi.write_text(MOCK_PI)
            fake_pi.chmod(0o755)
            controller = rpc_task.Controller("test", str(fake_pi), "")
            thread = threading.Thread(target=controller.run)
            thread.start()
            try:
                for _ in range(100):
                    if (scratch / "ask").exists():
                        break
                    time.sleep(0.05)
                self.assertTrue((scratch / "ask").exists())
                self.assertFalse((scratch / "done").exists())
                view = {}
                for _ in range(100):
                    if (scratch / "view.json").exists():
                        view = json.loads((scratch / "view.json").read_text())
                        if view.get("contextUsage", {}).get("percent") == 14.6:
                            break
                    time.sleep(0.05)
                self.assertEqual(view["phase"], "question")
                self.assertEqual(view["contextUsage"],
                                 {"tokens": 1200, "contextWindow": 8192, "percent": 14.6})
                with socket.socket(socket.AF_UNIX) as conn:
                    conn.settimeout(2)
                    conn.connect(str(scratch / "control.sock"))
                    conn.sendall(b"[]\n")
                    rejection = json.loads(conn.recv(4096))
                self.assertFalse(rejection["ok"])
                self.assertIn("JSON object", rejection["error"])
                self.assertTrue((scratch / "ask").exists())
                self.assertTrue(thread.is_alive())
                rpc_task.answer("test", "Option A\nwith details")
                thread.join(timeout=5)
                self.assertFalse(thread.is_alive())
                self.assertEqual((scratch / "done").read_text().strip(), "Finished")
                self.assertEqual((scratch / "report.txt").read_text(), "Verification: passed")
                self.assertIn('"type": "agent_settled"', (scratch / "events.jsonl").read_text())
                self.assertIn("[assistant] Working", (scratch / "activity.log").read_text())
                self.assertFalse((scratch / "ask").exists())
            finally:
                if thread.is_alive():
                    controller.pi.terminate()
                    thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
