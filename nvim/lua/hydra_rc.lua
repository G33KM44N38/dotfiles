local Hydra = require('hydra')

Hydra({
	name = 'Hydra',
	mode = {'n'},
	body = '<C-w>',
	config = {color = "red"},
	heads = {
	--active hydra
	{'d'},
	-- switch buffer up / down
      	{ 'k', '<C-w>k' ,{ desc = "↑"} },
      	{ 'j', '<C-w>j', { desc = "↓"} },
	-- switch buffer right left
      	{ 'h', '<C-w>h',{ desc = "←"} },
      	{ 'l', '<C-w>l',{ desc = "→"} },
	-- resize windows
	{ 'H', '<C-w>3<', { desc = '⇤' } },
	{ 'L', '<C-w>3>', { desc = '⇥' } },
	{ 'K', '<C-w>2+', { desc = '⤒' } },
	{ 'J', '<C-w>2-', { desc = '⤓' } },
	-- equalize windows
	{ 'e', '<C-w>=', { desc = '=' } },
	-- close active buffer
	{ 'Q', ':bdelete<CR>'},
	-- close active windows
	{ 'q', ':q<CR>'},
	-- exit hydra
	{ '<Esc>', nil, { exit = true, nowait = true} },
   }
})

