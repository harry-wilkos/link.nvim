local util = require("link.util")
local link = util.class()
local append_unique = util.append_unique

function link:init(opts)
    self.file_type = vim.bo.filetype
    self.opts = vim.tbl_deep_extend("keep", opts, util.default_opts)
end


function link:lsp_setup()
    local opts = self.opts["lsps"]
    local include = opts["include"][self.file_type]
    local lspconfig_funcs = require("mason-lspconfig.mappings")
    local all_lsps = lspconfig_funcs.get_filetype_map()[self.file_type]
    local lsps = append_unique(include, all_lsps)
    if not lsps then
        return
    end

    local mason_convert_map = lspconfig_funcs.get_mason_map()["lspconfig_to_package"]
    local mason_registry = require("mason-registry")
    local lsps_install = {}

    count = 1
    for _, lsp in ipairs(lsps) do
        local mason_lsp = mason_convert_map[lsp]
        if not mason_lsp then
            goto continue
        end

        local spec = mason_registry.get_package(mason_lsp).spec
        if include and count <= #include then
            lsps_install[#lsps_install + 1] = lsp
        else
            if #spec.languages ~= 1 then
                goto continue
            end
            local category = spec.categories
            if #category == 1 and category[1] == "LSP" then
                lsps_install[#lsps_install + 1] = lsp
            end
        end

        if count >= opts["limit"] then
            break
        end

        count = count + 1

        ::continue::
    end
    require("mason-lspconfig").setup({
        automatic_enable = lsps_install,
        ensure_installed = lsps_install
    })


end

return function(opts)
    link(opts):lsp_setup()
end
