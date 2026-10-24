"""Exercise the RPC question/answer lifecycle without calling a model."""

import importlib.util
import hashlib
import json
import os
import socket
import shutil
import subprocess
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
    def test_extension_tool_question_to_completion(self):
        agent_dir = Path.home() / ".pi" / "agent"
        version_file = agent_dir / "install" / "current-version"
        if not version_file.exists():
            self.skipTest("Pi installation unavailable")
        version = version_file.read_text().strip()
        modules = agent_dir / "install" / "releases" / version / "node_modules"
        if not shutil.which("node") or not (modules / "jiti").exists():
            self.skipTest("Pi Node runtime unavailable")
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "tasks"
            fake_pi = Path(temp) / "mock-pi"
            fake_pi.write_text(MOCK_PI)
            fake_pi.chmod(0o755)
            extension = agent_dir / "extensions" / "subagent-task.ts"
            env = {**os.environ, "PI_TASK_ROOT": str(root), "PI_TASK_PI_BIN": str(fake_pi),
                   "NODE_PATH": str(modules), "TEST_EXTENSION": str(extension), "TEST_DIR": temp,
                   "TEST_MODULES": str(modules)}
            env.pop("PI_TASK_CHILD", None)  # The test harness must register delegate_task even inside a child.
            js = '''
const { createJiti } = require('jiti');
const jiti = createJiti(process.env.TEST_MODULES + '/@earendil-works/pi-coding-agent/dist/index.js');
const tools = [], events = {};
jiti(process.env.TEST_EXTENSION).default({ on: (name, handler) => { events[name] = handler }, registerTool: tool => tools.push(tool) });
const tool = tools.find(tool => tool.name === 'delegate_task');
if (events.session_start || String(events.session_shutdown).includes('setWidget')) throw Error('redundant editor widget still registered');
const theme = { fg: (_color, text) => text, bold: text => text };
const render = (component, width = 48) => {
  const lines = component.render(width);
  if (lines.some(line => line.replace(/\\x1b\\[[0-9;]*m/g, '').length > width)) throw Error('render overflow at width ' + width + ': ' + JSON.stringify(lines));
  return lines.join('\\n');
};
(async () => {
  const ctx = (id, dir = process.env.TEST_DIR) => ({ cwd: process.env.TEST_DIR, model: null, sessionManager: {
    getSessionId: () => id, getSessionDir: () => dir
  } });
  const sessionA = ctx('session-a'), sessionB = ctx('session-b');
  const sessionC = ctx('session-a', process.env.TEST_DIR + '/another-project');
  const lock = (id, dir = process.env.TEST_DIR) => process.env.PI_TASK_ROOT + '/.active-' + require('node:crypto').createHash('sha256')
    .update(dir + '\\0' + id).digest('hex');
  const fs = require('node:fs');
  const updates = [];
  const first = await tool.execute('a', {brief: 'Mock task', timeout: 5}, undefined, update => updates.push(update), sessionA);
  if (first.details.phase !== 'question' || !updates.length || !fs.existsSync(lock('session-a'))) throw Error(JSON.stringify(first));
  let sameSessionRejected = false;
  try { await tool.execute('duplicate', {brief: 'Second task'}, undefined, () => {}, sessionA); }
  catch (error) { sameSessionRejected = String(error).includes('already running in this session'); }
  if (!sameSessionRejected) throw Error('second child was allowed in same session');
  const other = await tool.execute('other', {brief: 'Independent task', timeout: 5}, undefined, () => {}, sessionB);
  if (other.details.phase !== 'question' || !fs.existsSync(lock('session-b'))) throw Error('second session could not start');
  const third = await tool.execute('third', {brief: 'Same id, different project', timeout: 5}, undefined, () => {}, sessionC);
  if (third.details.phase !== 'question' || !fs.existsSync(lock('session-a', process.env.TEST_DIR + '/another-project')))
    throw Error('different project with same session id could not start');
  let foreignResumeRejected = false;
  try { await tool.execute('wrong', {slug: first.details.slug, answer: 'Yes'}, undefined, () => {}, sessionB); }
  catch (error) { foreignResumeRejected = String(error).includes('in this session'); }
  if (!foreignResumeRejected || !fs.existsSync(lock('session-a'))) throw Error('cross-session resume was accepted');
  const question = render(tool.renderResult(first, {expanded: false, isPartial: false}, theme));
  if (!question.includes('question') || !question.includes('Which option?')) throw Error(question);
  const partial = { content: [], details: {
    slug: 'demo', phase: 'running', action: 'Reading files', elapsed: 12,
    contextUsage: {tokens: 1200, contextWindow: 8192},
    activity: ['[tool] read skill.md', '[assistant] Working'], dir: '/tmp/demo'
  } };
  const spinner = tool.renderResult(partial, {expanded: false, isPartial: true}, theme);
  const now = Date.now;
  let collapsed, nextFrame;
  try {
    Date.now = () => 0;
    collapsed = render(spinner);
    Date.now = () => 80;
    nextFrame = render(spinner);
  } finally { Date.now = now; }
  if (!collapsed.includes('⠋') || !nextFrame.includes('⠙')) throw Error('Pi spinner did not advance on redraw');
  if (!collapsed.includes('running') || !collapsed.includes('12s') || !collapsed.includes('ctx 1.2k/') ||
      !collapsed.includes('Reading files') || !collapsed.includes('Working')) throw Error(collapsed);
  const expanded = render(tool.renderResult(partial, {expanded: true, isPartial: true}, theme), 28);
  if (!expanded.includes('Recent activity') || !expanded.includes('Logs:') || !expanded.includes('Task: demo')) throw Error(expanded);
  const second = await tool.execute('b', {slug: first.details.slug, answer: 'Yes', timeout: 5}, undefined, () => {}, sessionA);
  if (fs.existsSync(lock('session-a')) || !fs.existsSync(lock('session-b')) ||
      !fs.existsSync(lock('session-a', process.env.TEST_DIR + '/another-project')))
    throw Error('session locks did not release independently');
  const otherDone = await tool.execute('other-done', {slug: other.details.slug, answer: 'Yes', timeout: 5}, undefined, () => {}, sessionB);
  if (otherDone.details.phase !== 'done' || fs.existsSync(lock('session-b'))) throw Error('second session did not finish');
  const thirdDone = await tool.execute('third-done', {slug: third.details.slug, answer: 'Yes', timeout: 5}, undefined, () => {}, sessionC);
  if (thirdDone.details.phase !== 'done' || fs.existsSync(lock('session-a', process.env.TEST_DIR + '/another-project')))
    throw Error('third session did not finish');
  if (second.details.phase !== 'done' || !second.content[0].text.includes('Verification: passed')) {
    throw Error(JSON.stringify(second));
  }
  const final = render(tool.renderResult(second, {expanded: false, isPartial: false}, theme));
  if (!final.includes('✓ done') || !final.includes('Finished') || final.includes('Recent activity')) throw Error(final);
  const full = render(tool.renderResult(second, {expanded: true, isPartial: false}, theme));
  if (!full.includes('Verification: passed')) throw Error(full);
  const blocked = render(tool.renderResult({content: [], isError: true, details: {
    slug: 'demo', phase: 'blocked', message: 'Need access', elapsed: 3, activity: [], dir: '/tmp/demo'
  }}, {expanded: false, isPartial: false}, theme));
  if (!blocked.includes('blocked') || !blocked.includes('Need access')) throw Error(blocked);
  events.session_shutdown({}, {mode: 'tui', ui: {setWidget: () => { throw Error('widget called') }}});
})().catch(error => {
  events.session_shutdown?.({}, {mode: 'tui', ui: {setWidget: () => {}}});
  console.error(error);
  process.exitCode = 1;
});
'''
            outcome = subprocess.run(["node", "-e", js], env=env, capture_output=True, timeout=12)
            self.assertEqual(outcome.returncode, 0, outcome.stderr.decode())
            self.assertFalse((root / ".active").exists())
            self.assertFalse((root / (".active-" + hashlib.sha256(f"{temp}\0session-a".encode()).hexdigest())).exists())
            self.assertFalse((root / (".active-" + hashlib.sha256(f"{temp}\0session-b".encode()).hexdigest())).exists())
            self.assertFalse((root / (".active-" + hashlib.sha256(f"{temp}/another-project\0session-a".encode()).hexdigest())).exists())

    def test_headless_runner_termination_releases_lock(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "tasks"
            brief = Path(temp) / "brief.md"
            brief.write_text("Mock task")
            fake_pi = Path(temp) / "mock-pi"
            fake_pi.write_text(MOCK_PI)
            fake_pi.chmod(0o755)
            env = {**os.environ, "PI_TASK_ROOT": str(root)}
            session_key = "a" * 64
            runner = subprocess.Popen(["bash", str(SCRIPT.with_name("headless-run.sh")),
                                       session_key, "abort", temp, str(brief), "", str(fake_pi)],
                                      env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                for _ in range(100):
                    if (root / "abort" / "ask").exists():
                        break
                    self.assertIsNone(runner.poll())
                    time.sleep(0.05)
                self.assertTrue((root / "abort" / "ask").exists())
                runner.terminate()
                runner.wait(timeout=5)
                self.assertFalse((root / (".active-" + session_key)).exists())
                self.assertFalse((root / "abort" / "control.sock").exists())
            finally:
                if runner.poll() is None:
                    runner.kill()
                    runner.wait(timeout=5)

    def test_headless_runner_question_and_lock(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "tasks"
            brief = Path(temp) / "brief.md"
            brief.write_text("Mock task")
            fake_pi = Path(temp) / "mock-pi"
            fake_pi.write_text(MOCK_PI)
            fake_pi.chmod(0o755)
            script = SCRIPT.with_name("headless-run.sh")
            env = {**os.environ, "PI_TASK_ROOT": str(root)}
            key_a, key_b = "a" * 64, "b" * 64
            args = ["bash", str(script), key_a, "one", temp, str(brief), "", str(fake_pi)]
            runner = subprocess.Popen(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            other_runner = None
            try:
                for _ in range(100):
                    if (root / "one" / "ask").exists():
                        break
                    self.assertIsNone(runner.poll(), "headless runner exited before asking")
                    time.sleep(0.05)
                self.assertTrue((root / "one" / "ask").exists())
                (root / ".active").write_text(f"legacy {os.getpid()} pane\n")
                duplicate = subprocess.run(["bash", str(script), key_a, "two", temp, str(brief), "", str(fake_pi)],
                                           env=env, capture_output=True, timeout=5)
                self.assertEqual(duplicate.returncode, 3)
                self.assertIn(b"another child", duplicate.stderr)
                other_runner = subprocess.Popen(["bash", str(script), key_b, "other", temp, str(brief), "", str(fake_pi)],
                                                env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                for _ in range(100):
                    if (root / "other" / "ask").exists():
                        break
                    self.assertIsNone(other_runner.poll())
                    time.sleep(0.05)
                self.assertTrue((root / "other" / "ask").exists())
                self.assertTrue((root / ".active").exists())  # Legacy pane lock must not block either session.
                answer = subprocess.run(["python3", str(SCRIPT), "send", "one", "Yes"],
                                        env=env, capture_output=True, timeout=5)
                self.assertEqual(answer.returncode, 0, answer.stderr)
                self.assertEqual(runner.wait(timeout=5), 0)
                self.assertFalse((root / (".active-" + key_a)).exists())
                self.assertTrue((root / (".active-" + key_b)).exists())
                answer_other = subprocess.run(["python3", str(SCRIPT), "send", "other", "Yes"],
                                              env=env, capture_output=True, timeout=5)
                self.assertEqual(answer_other.returncode, 0, answer_other.stderr)
                self.assertEqual(other_runner.wait(timeout=5), 0)
                self.assertFalse((root / (".active-" + key_b)).exists())
                self.assertEqual((root / "one" / "done").read_text().strip(), "Finished")
                self.assertEqual((root / "other" / "done").read_text().strip(), "Finished")
                self.assertEqual((root / "one" / "report.txt").read_text(), "Verification: passed")
            finally:
                for process in (runner, other_runner):
                    if process is None:
                        continue
                    if process.poll() is None:
                        process.terminate()
                        process.wait(timeout=5)
                    process.stdout.close()
                    process.stderr.close()

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
