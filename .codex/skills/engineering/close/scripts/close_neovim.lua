(function()
  local uv = vim.uv or vim.loop
  local function inside(path)
    return path == _A.root or path:sub(1, #_A.root + 1) == _A.root .. '/'
  end
  local function inspect()
    local state = {pid = vim.fn.getpid(), status = 'ready', modified_buffers = {}}
    if state.pid ~= _A.pid then
      state.status = 'wrong_pid'
      return state
    end
    if not inside(uv.fs_realpath(uv.cwd()) or '') then
      state.status = 'outside_worktree'
      return state
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local name = vim.api.nvim_buf_get_name(buf)
        if vim.bo[buf].modified then
          table.insert(state.modified_buffers, {number = buf, name = name})
        end
        if vim.bo[buf].buftype == 'terminal' then
          local job = vim.b[buf].terminal_job_id
          if job and vim.fn.jobwait({job}, 0)[1] == -1 then
            state.status = 'running_terminal'
          end
        elseif vim.bo[buf].buftype == '' and vim.bo[buf].buflisted and name ~= '' then
          if not inside(uv.fs_realpath(name) or vim.fn.fnamemodify(name, ':p')) then
            state.status = 'outside_buffer'
          end
        end
      end
    end
    if #state.modified_buffers > 0 then
      state.status = 'modified_buffers'
    end
    return state
  end
  local state = inspect()
  if _A.action == 'quit' and state.status == 'ready' then
    -- Reply first, then recheck in the same callback that issues the normal quit.
    vim.schedule(function()
      if inspect().status ~= 'ready' then return end
      local options = {vim.o.autowrite, vim.o.autowriteall, vim.o.confirm}
      vim.o.autowrite, vim.o.autowriteall, vim.o.confirm = false, false, false
      -- No force, automatic saves, prompts or project/plugin exit autocmds.
      local ok = pcall(vim.cmd, 'noautocmd qall')
      if not ok then
        vim.o.autowrite, vim.o.autowriteall, vim.o.confirm = unpack(options)
      end
    end)
    state.status = 'scheduled'
  end
  return state
end)()
