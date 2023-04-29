local map = vim.api.nvim_set_keymap

map('n', '<leader><leader>l', ":execute 'silent !kitty -d src love . &' | redraw!<cr>", {
	silent = true,
	noremap = true
})
