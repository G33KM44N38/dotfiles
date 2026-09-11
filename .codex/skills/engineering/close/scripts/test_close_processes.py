import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from close import Blocked, active_processes, session_process_role


class SessionProcessTests(unittest.TestCase):
    def setUp(self):
        self.resources = Path('/Applications/ChatGPT.app/Contents/Resources')
        self.cua = self.resources / 'cua_node/bin'
        self.ancestors = [10, 20, 30]
        self.processes = {
            10: {'name': 'python', 'executable': sys.executable, 'ppid': 20},
            20: {'name': 'codex', 'executable': str(self.resources / 'codex'), 'ppid': 30},
            30: {'name': 'herdr', 'executable': '/opt/homebrew/bin/herdr', 'ppid': 1},
            40: {'name': 'node_repl', 'executable': str(self.cua / 'node_repl'), 'ppid': 20},
        }

    def role(self, executable, argv, parent=20, state=''):
        self.processes[50] = {'name': Path(executable).name.lstrip('-'), 'executable': executable, 'ppid': parent}
        return session_process_role(50, self.processes, self.ancestors, argv, state)

    def test_recognizes_session_tool_entrypoints(self):
        repl = str(self.cua / 'node_repl')
        node = str(self.cua / 'node')
        host = str(self.resources / 'codex-code-mode-host')
        app = str(self.resources / 'codex')
        plugin = str(Path.home() / '.codex/plugins/cache/openai-bundled/unified-computer-use/version/scripts/launch.mjs')
        runtime = Path(tempfile.gettempdir()) / '.tmp-session'
        cases = [
            (repl, [repl], 20),
            (host, [host], 20),
            (node, [node, plugin], 20),
            (node, [node, '--experimental-vm-modules', str(runtime / 'kernel.js'), '--session-id', 'session', '--working-dir', '/worktree'], 40),
            (node, [node, str(runtime / 'trusted-worker.js'), '/worktree'], 40),
            (app, [app, 'app-server', '--listen', 'unix:///tmp/session.sock'], 40),
        ]
        for executable, argv, parent in cases:
            with self.subTest(argv=argv):
                self.assertIsNotNone(self.role(executable, argv, parent))

    def test_node_servers_and_codex_agents_remain_blocked(self):
        node = str(self.cua / 'node')
        app = str(self.resources / 'codex')
        plugin = str(Path.home() / '.codex/plugins/cache/openai-bundled/unified-computer-use/version/scripts/launch.mjs')
        for executable, argv in [
            (node, [node, '/worktree/server.js']),
            (node, [node, '--eval', 'startServer()', plugin]),
            (node, [node, '/worktree/.tmp-runtime/kernel.js']),
            ('/usr/local/bin/node_repl', ['/usr/local/bin/node_repl']),
            (app, [app, 'exec', 'work on another task']),
            (app, [app]),
        ]:
            with self.subTest(argv=argv):
                self.assertIsNone(self.role(executable, argv))

    def test_other_agent_helpers_remain_blocked(self):
        repl = str(self.cua / 'node_repl')
        for parent in (1, 20):
            self.processes[60] = {'name': 'codex', 'executable': str(self.resources / 'codex'), 'ppid': parent}
            self.assertIsNone(self.role(repl, [repl], parent=60))

    def test_only_idle_foreground_shell_without_jobs_is_allowed(self):
        self.assertEqual(self.role('-zsh', ['-zsh'], parent=30, state='Ss+ 50 50 ttys001'), 'idle terminal shell')
        self.assertIsNone(self.role('-zsh', ['-zsh'], parent=30, state='R+ 50 50 ttys001'))
        self.assertIsNone(self.role('-zsh', ['-zsh'], parent=30, state='Ss 50 60 ttys001'))
        self.assertIsNone(self.role('-zsh', ['-zsh', '-c', 'build'], parent=30, state='Ss+ 50 50 ttys001'))
        self.assertIsNone(self.role('-zsh', ['-zsh'], parent=99, state='Ss+ 50 50 ttys001'))
        self.processes[60] = {'name': 'node', 'executable': '/usr/local/bin/node', 'ppid': 50}
        self.assertIsNone(self.role('-zsh', ['-zsh'], parent=30, state='Ss+ 50 50 ttys001'))

    @unittest.skipUnless(sys.platform == 'darwin' and Path('/usr/bin/trash').exists(), 'macOS process inspection')
    def test_live_process_guard_and_inspector_false_positive(self):
        root = Path(tempfile.mkdtemp(prefix='close-process-test-')).resolve()
        try:
            self.assertEqual(active_processes(root), [])
            child = subprocess.Popen(
                [sys.executable, '-c', 'import sys; print("ready", flush=True); sys.stdin.read()'],
                cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
            )
            try:
                self.assertEqual(child.stdout.readline().strip(), 'ready')
                with self.assertRaises(Blocked) as raised:
                    active_processes(root)
                self.assertEqual([row['pid'] for row in raised.exception.processes], [child.pid])
                self.assertEqual(raised.exception.processes[0]['cwd'], str(root))
                self.assertTrue(raised.exception.processes[0]['executable'])
            finally:
                child.stdin.close()
                child.wait(timeout=5)
                child.stdout.close()
            self.assertEqual(active_processes(root), [])
        finally:
            subprocess.run(['/usr/bin/trash', '-s', str(root)], check=True)


if __name__ == '__main__':
    unittest.main()
