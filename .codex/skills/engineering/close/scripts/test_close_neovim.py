"""Real Neovim RPC checks; all editors and buffers belong to temporary fixtures."""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import select
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unittest

from close import Blocked, active_processes
from close_neovim import NeovimBlocked, quit_neovim, rpc


def evaluate(address, expression):
    return subprocess.run(['nvim', '--clean', '--headless', '--server', str(address), '--remote-expr', expression],
                          capture_output=True, check=True, timeout=5).stdout.decode()


@contextmanager
def editor(root, tui=False):
    # macOS Unix socket paths are limited to roughly 100 bytes.
    address = root.parent / f'n{time.monotonic_ns() % 100000000}'
    master, slave = os.openpty() if tui else (None, None)
    stop_reading = threading.Event()
    def drain_terminal():
        while not stop_reading.is_set():
            try:
                if select.select([master], [], [], 0.1)[0] and not os.read(master, 65536):
                    return
            except OSError:
                return
    reader = threading.Thread(target=drain_terminal, daemon=True) if tui else None
    if reader:
        reader.start()
    process = subprocess.Popen(['nvim', '--clean', *([] if tui else ['--headless']), '--listen', str(address)],
                               cwd=root, stdin=slave if tui else subprocess.DEVNULL,
                               stdout=slave if tui else subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                               start_new_session=True)
    try:
        deadline = time.monotonic() + 5
        while not address.exists() and time.monotonic() < deadline and process.poll() is None:
            time.sleep(0.05)
        pid = int(evaluate(address, 'getpid()'))
        yield process, address, pid
    finally:
        try:
            if process.poll() is None:
                # Forced quit applies only to this test-owned disposable editor.
                subprocess.run(['nvim', '--clean', '--headless', '--server', str(address), '--remote-send',
                                '<C-\\><C-n>:qall!<CR>'], capture_output=True, timeout=5)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.terminate()  # Only this test-owned fixture process.
                    process.wait(timeout=5)
        finally:
            stop_reading.set()
            if reader:
                reader.join(timeout=1)
            for fd in (master, slave):
                if fd is not None:
                    os.close(fd)


@unittest.skipUnless(sys.platform == 'darwin' and shutil.which('nvim'), 'macOS and Neovim required')
class NeovimTests(unittest.TestCase):
    def setUp(self):
        self.base = Path(tempfile.mkdtemp(prefix='close-nvim-test-')).resolve()
        self.root = self.base / 'worktree'
        self.root.mkdir()

    def tearDown(self):
        subprocess.run(['/usr/bin/trash', '-s', str(self.base)], check=True)

    def processes(self):
        with self.assertRaises(Blocked) as caught:
            active_processes(self.root)
        return caught.exception.processes

    def test_clean_headless_editor_exits(self):
        with editor(self.root) as (process, address, pid):
            self.assertEqual(quit_neovim(self.root, self.processes()), [pid])
            self.assertEqual(process.wait(timeout=5), 0)
        self.assertEqual(active_processes(self.root), [])

    def test_tui_and_embedded_server_exit_together(self):
        with editor(self.root, tui=True) as (process, address, pid):
            self.assertNotEqual(pid, process.pid)
            self.assertEqual(quit_neovim(self.root, self.processes()), [pid])
            self.assertEqual(process.wait(timeout=5), 0)
        self.assertEqual(active_processes(self.root), [])

    def test_unsaved_hidden_and_unnamed_buffers_are_preserved(self):
        with editor(self.root) as (process, address, pid):
            evaluate(address, "execute('set hidden autowriteall | call setline(1, \"KEEP_UNSAVED_FIXTURE\") | enew')")
            with self.assertRaisesRegex(NeovimBlocked, 'modified_buffers') as caught:
                quit_neovim(self.root, self.processes())
            self.assertNotIn('KEEP_UNSAVED_FIXTURE', str(caught.exception))
            self.assertIsNone(process.poll())
            self.assertIn('KEEP_UNSAVED_FIXTURE', evaluate(address, 'json_encode(getbufline(1, 1, "$"))'))
            self.assertEqual(evaluate(address, '&autowriteall'), '1')

    def test_modified_buffer_added_after_inspection_still_prevents_quit(self):
        with editor(self.root) as (process, address, pid):
            self.assertEqual(rpc(self.root, pid, str(address), 'inspect')['status'], 'ready')
            evaluate(address, "execute('call setline(1, \"KEEP_NEW_EDIT\")')")
            self.assertEqual(rpc(self.root, pid, str(address), 'quit')['status'], 'modified_buffers')
            self.assertIsNone(process.poll())

    def test_wrong_rpc_identity_never_quits_editor(self):
        with editor(self.root) as (process, address, pid):
            with self.assertRaisesRegex(NeovimBlocked, 'identity'):
                rpc(self.root, pid + 1, str(address), 'quit')
            self.assertIsNone(process.poll())

    def test_editor_with_other_project_buffer_is_preserved(self):
        outside = self.base / 'outside.txt'
        outside.write_text('keep\n')
        with editor(self.root) as (process, address, pid):
            evaluate(address, "execute('edit ' . fnameescape(" + json.dumps(str(outside)) + '))')
            with self.assertRaisesRegex(NeovimBlocked, 'outside_buffer'):
                quit_neovim(self.root, self.processes())
            self.assertIsNone(process.poll())

    def test_running_terminal_prevents_editor_shutdown(self):
        with editor(self.root) as (process, address, pid):
            evaluate(address, "jobstart(['sleep', '60'], {'term': v:true})")
            with self.assertRaisesRegex(NeovimBlocked, 'running_terminal'):
                quit_neovim(self.root, self.processes())
            self.assertIsNone(process.poll())

    def test_exit_autocmds_do_not_run(self):
        marker = self.root / 'autocmd-marker'
        with editor(self.root) as (process, address, pid):
            command = 'autocmd VimLeavePre * call writefile(["should not run"], ' + json.dumps(str(marker)) + ')'
            evaluate(address, 'execute(' + json.dumps(command) + ')')
            quit_neovim(self.root, self.processes())
            process.wait(timeout=5)
        self.assertFalse(marker.exists())
