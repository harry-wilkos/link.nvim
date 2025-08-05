-- lua/link/init.lua
local M = {}
local link_instances = {}

function M.setup(opts)
    require("mason").setup({})
    require("mason-lspconfig").setup({})

    -- BufReadPost: create & stash instance
    vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function(args)
            local init_link = require("link.start")(opts)
            link_instances[args.buf] = init_link:lsp_setup()
        end,
    })

    -- BufUnload: clean up if it exists
    vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
            local inst = link_instances[args.buf]
            if inst then
                vim.defer_fn(function() inst:clean() end,1000)
                link_instances[args.buf] = nil
            end
        end,
    })
end
return M
