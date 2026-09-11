"""Gracefully quit verified Neovim servers without saving or discarding buffers."""
import json
from pathlib import Path
import shutil
import subprocess
import time


class NeovimBlocked(Exception):
    pass


def rpc(root, pid, address, action):
    source = Path(__file__).with_suffix('.lua').read_text()
    params = json.dumps({'root': str(root), 'pid': pid, 'action': action})
    literal = lambda text: "'" + text.replace("'", "''") + "'"
    expression = f"json_encode(luaeval({literal(source)}, json_decode({literal(params)})))"
    try:
        result = subprocess.run(
            [shutil.which('nvim') or 'nvim', '--clean', '--headless', '--server', address, '--remote-expr', expression],
            cwd=root.parent, capture_output=True, timeout=5,
        )
        state = json.loads(result.stdout) if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired, ValueError):
        state = None
    if not isinstance(state, dict) or state.get('pid') != pid:
        raise NeovimBlocked(f'Neovim PID {pid}: RPC identity or response could not be verified.')
    return state


def quit_neovim(root, processes):
    """Only discovered Neovim socket owners may receive a quit request."""
    editors = []
    for process in processes:
        if process['name'] != 'nvim':
            continue
        pid = process['pid']
        sockets = subprocess.run(['lsof', '-n', '-P', '-a', '-p', str(pid), '-U', '-Fpn'],
                                 cwd=root.parent, capture_output=True, timeout=5)
        if sockets.returncode not in (0, 1):
            raise NeovimBlocked(f'Neovim PID {pid}: could not inspect owned sockets.')
        addresses = [line[1:] for line in sockets.stdout.decode(errors='replace').splitlines()
                     if line.startswith('n/') and Path(line[1:]).is_socket()]
        addresses.sort(key=lambda address: not Path(address).name.startswith(f'nvim.{pid}.'))
        for address in addresses:
            try:
                state = rpc(root, pid, address, 'inspect')
            except NeovimBlocked:
                continue
            if state['status'] != 'ready':
                details = json.dumps(state.get('modified_buffers', []), ensure_ascii=False)
                raise NeovimBlocked(f"Neovim PID {pid}: {state['status']}; modified buffers: {details}. No editor forced closed.")
            editors.append((pid, address))
            break
    # Inspect every reachable editor before requesting any shutdown.
    for pid, address in editors:
        try:
            state = rpc(root, pid, address, 'quit')
        except NeovimBlocked:
            # A successful quit can close RPC before its acknowledgement arrives.
            state = None
        if state is not None and state['status'] != 'scheduled':
            raise NeovimBlocked(f"Neovim PID {pid}: quit refused ({state['status']}).")
    pending = {pid for pid, _ in editors}
    deadline = time.monotonic() + 5
    while pending and time.monotonic() < deadline:
        result = subprocess.run(['ps', '-p', ','.join(map(str, pending)), '-o', 'pid=,stat='],
                                cwd=root.parent, capture_output=True, timeout=5)
        if result.returncode not in (0, 1):
            raise NeovimBlocked('Could not verify Neovim exit; no cleanup performed.')
        pending = {int(fields[0]) for line in result.stdout.decode().splitlines()
                   if len(fields := line.split()) == 2 and not fields[1].startswith('Z')}
        if pending:
            time.sleep(0.1)
    if pending:
        raise NeovimBlocked(f'Neovim did not exit after the safe quit request: {sorted(pending)}. No editor forced closed.')
    return [pid for pid, _ in editors]
