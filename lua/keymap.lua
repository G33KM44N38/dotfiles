local opts = { noremap = true, silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- running macro
keymap("n", "<leader>q", "@q", opts)
-- Save
keymap("n", "<leader>w", ":w<CR> :wa<CR>", opts)

-- mapping change viewport
keymap("n", "<S-TAB>", "<C-W><C-W>", opts)
keymap("n", "<TAB>", ":bn<CR>", opts)

-- add new line
keymap("n", "<leader>o", "o<Esc>", opts)
keymap("n", "O", "o<Esc>", opts)

-- make
keymap("n", "<leader>m", ":make<CR>", opts)

-- commante line
keymap("n", "<leader><leader>c", ":Commentary <CR>", opts)

-- mapping fugitif
keymap("n", "<leader>gs", ":G<CR>", opts)
keymap("n", "<leader>gc", ":Git commit<CR>", opts)
keymap("n", "<leader>gp", ":Git push<CR>", opts)
keymap("n", "<leader>gb", ":Git checkout", opts)
keymap("n", "<leader>g1", ":diffget //2<CR> ", opts)
keymap("n", "<leader>g2", ":diffget //3<CR> ", opts)

-- mapping find replace word undercursor in all buffer
keymap("n", "<Leader>sed", ":bufdo %s/<<C-r><C-w>>//g<Left><Left> | update", opts)
keymap("n", "<Leader>se",  ":s/<<C-r><C-w>>//g<Left><Left>", opts)

-- open term
keymap("n", "<leader>tt", ":ToggleTerm size=20 cmd='fish'<CR>", opts)

-- mark
keymap("n", "<leader><leader>1", ":mark a <CR>", opts)
keymap("n", "<leader><leader>2", ":mark b <CR>", opts)
keymap("n", "<leader><leader>3", ":mark c <CR>", opts)
keymap("n", "<leader>1", "'a", opts)
keymap("n", "<leader>2", "'b", opts)
keymap("n", "<leader>3", "'c", opts)

-- mapping Open Buffer fzf telescope
keymap("n", "<leader>b", ":lua require'telescope.builtin'.buffers()<CR>", opts)
keymap("n", "<leader>t", ":! ctags <CR> :lua require('telescope.builtin').tags()<CR>", opts)
keymap("n", "<leader>bf", ":lua require('telescope.builtin').find_files()<CR>", opts)
keymap("n", "<leader>dot", ":lua require('rc_telescope').search_dotfiles()<CR>", opts)
keymap("n", "<leader>conf", ":lua require('rc_telescope').config()<CR>", opts)

keymap("n", "<leader>br", ":lua require('telescope.builtin').live_grep()<CR>", opts)
keymap("n", "<leader>bq", ":lua require('telescope.builtin').quickfix()<CR>", opts)
keymap("n", "<leader>bg", ":lua require('telescope.builtin').git_files()<CR>", opts)
keymap("n", "<leader>xx", ":lua require('telescope.builtin').diagnostics()<CR>", opts)
keymap("n", "<leader>gt", ":lua require('telescope.builtin').git_status()<CR>", opts)

keymap("n", "<F19>", ":lua require('telescope.builtin').keymaps()<CR>", opts)
keymap("n", "<leader>man", ":lua require('telescope.builtin').man_pages()<CR>", opts)
keymap("n", "<leader>old", ":lua require('telescope.builtin').oldfiles()<CR>", opts)
keymap("n", "<leader>reset", ":LspRestart<CR>", opts)
keymap("n", "<leader>cheat", ":Cheat<CR>", opts)

-- vimspector mapping
keymap("n", "<F2>",  ":call vimspector#StepOver()<CR>", opts)
keymap("n", "<F3>",  ":call vimspector#StepInto()<CR>", opts)
keymap("n", "<F4>",  ":call vimspector#StepOut()<CR>", opts)
keymap("n", "<F12>", ":call vimspector#Restart()<CR>", opts)

-- mapping Lex
keymap("n", "<leader>rr", ":Ex<CR>", opts)

-- Visual Block --
-- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
