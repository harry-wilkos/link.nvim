local util = require("link.util")
local link = util.class()
local append_unique = util.append_unique
local list_to_set = util.list_to_set

function link:init(opts)
    self.file_type = vim.bo.filetype
    self.opts = vim.tbl_deep_extend("keep", opts, util.default_opts)
    self.mason_registry = require("mason-registry")
    self.ensure_removed = {}
    self.installed = {}
end

function link:clean()
    if not self.opts["clean"] then return end
    local removed = false
    for _, lsp in ipairs(self.ensure_removed) do
        if self.mason_registry.has_package(lsp) then
            local pkg = self.mason_registry.get_package(lsp)
            if pkg:is_installed() then
                pkg:uninstall()
                removed = true
            end
        end
    end
    if removed then pcall(vim.cmd, "LspRestart") end
end

function link:formatter_setup()
    local opts = self.opts["formatters"]
    local all_formatters = require("conform.formatters").list_all_formatters()
    local mapping = require("mason-conform.mapping").conform_to_package

    local formatters = {}
    local count = 1
    for formatter in pairs(all_formatters) do
        local mason_formatter = mapping[formatter]
        if not mason_formatter then goto continue end

        local spec = self.mason_registry.get_package(mason_formatter).spec
        for _, lang in ipairs(spec["languages"] or {}) do
            if string.lower(lang) ~= self.file_type then
                goto continue
            elseif #spec.categories == 1 and spec.categories[1] == "Formatter" then
                formatters[#formatters + 1] = formatter
            end
        end
        count = count + 1

        if count > opts["limit"] then break end

        ::continue::
    end

    if not formatters then return end

    table.sort(formatters)
    require("conform").setup({
        formatters_by_ft = {[self.file_type] = formatters}
    })
    require("mason-conform").setup({})
end

function link:lsp_setup()
    local lspconfig = require("mason-lspconfig.mappings")
    local opts = self.opts["lsps"]
    local file_opts = opts[self.file_type] or {}

    local include = file_opts["include"] or {}
    local exclude = list_to_set(file_opts["exclude"])

    local lsps = append_unique(include,
                               lspconfig.get_filetype_map()[self.file_type])
    local lsps_install = {}
    local count = 1
    local mason_convert_map = lspconfig.get_mason_map()["lspconfig_to_package"]

    for _, lsp in ipairs(lsps) do
        if exclude[lsp] then goto continue end
        local mason_lsp = mason_convert_map[lsp]
        if not mason_lsp then goto continue end

        local spec = self.mason_registry.get_package(mason_lsp).spec
        if include[lsp] then
            lsps_install[#lsps_install + 1] = lsp
        elseif #(spec.langaues or {}) > 1 then
            goto continue
        elseif #spec.categories == 1 and spec.categories[1] == "LSP" then
            lsps_install[#lsps_install + 1] = lsp
        else
            goto continue
        end

        if count >= opts["limit"] then break end

        count = count + 1

        ::continue::
    end

    for _, lsp in ipairs(lsps) do
        if list_to_set(lsps_install)[lsp] then goto continue end
        table.insert(self.ensure_removed, mason_convert_map[lsp])
        ::continue::
    end
    require("mason-lspconfig").setup({
        automatic_enable = {exclude = self.ensure_removed},
        ensure_installed = lsps_install
    })
    return self
end

return function(opts) return link(opts) end
