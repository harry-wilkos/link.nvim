-- lua/link/init.lua
local M = {}
function M.setup(opts)
	require("mason").setup({})
	require("mason-lspconfig").setup({})
	require("conform").setup({})

	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function()
			require("link.link_class")(opts)
		end,
	})
end
return M
