local util = require("link.util")
local link = util.class()

function link:init(opts)
	self.file_type = vim.bo.filetype
	self.opts = vim.tbl_deep_extend("keep", opts, {
        clean = true,
        lsps = {limit = 1},
        formatters = {limit = 2},
        linters = {limit = 1}
    })

	self.mason_registry = require("mason-registry")

	self.lsps = {}
	self.formatters = {}
	self.linters = {}
	self.remove = {}
	self.removed = false

	self.find_lsps(self)
	self.find_formatters(self)
    self.find_linters(self)

	self.uninstall(self)
	self.install(self)

	if self.removed and self.opts["clean"] then
		vim.defer_fn(function()
			pcall(vim.cmd, "LspRestart")
			self.remove = false
		end, 1000)
	end
end

function link:find_linters()
    local function find_all_linters()
        local file_paths = vim.api.nvim_get_runtime_file("lua/lint/linters/*.lua", true)
          local names = {}
          local seen = {}
          for _, file_path in ipairs(file_paths) do
            local file = file_path:match("([^/\\]+)%.lua$")
            if file and not seen[file] then
              table.insert(names, file)
              seen[file] = true
            end
          end
          table.sort(names)
        return names
    end

    local opts = self.opts["linters"]
	local file_opts = opts[self.file_type] or {}

    local convert_map = require("mason-nvim-lint.mapping")["nvimlint_to_package"]
    local all_linters = find_all_linters()

	local exclude = util.list_to_set(file_opts["exclude"])

	local categorize_linters = { {}, {}, {}, {} }
    for _, linter in ipairs(all_linters) do
        local mason_linter = convert_map[linter]
        if not mason_linter then
            goto continue
        end

        if exclude[linter] then
            self.remove[#self.remove+1] = mason_linter
            goto continue
        end

		local spec = self.mason_registry.get_package(mason_linter).spec
		local lang_match = false
		for _, lang in ipairs(spec["languages"] or {}) do
			if string.lower(lang) == self.file_type then
				lang_match = true
				break
			end
		end
		if not lang_match then
			goto continue
		end

		local categories = util.list_to_set(spec.categories or {})
		if not categories["Linter"] then
			goto continue
		end
		if #spec.categories == 1 then
			if #spec.languages == 1 then
				categorize_linters[1][#categorize_linters[1] + 1] = linter
			else
				categorize_linters[3][#categorize_linters[3] + 1] = linter
			end
		else
			if #spec.languages == 1 then
				categorize_linters[2][#categorize_linters[2] + 1] = linter
			else
				categorize_linters[4][#categorize_linters[4] + 1] = linter
			end
		end
        ::continue::
    end

	local flatterned_order = {}
	for _, catagory in ipairs(categorize_linters) do
		for _, linter in ipairs(catagory) do
			flatterned_order[#flatterned_order + 1] = linter
		end
	end

	local result = util.append_unique(file_opts["include"], flatterned_order)
	for count, linter in ipairs(result) do
		if count <= opts["limit"] then
			self.linters[#self.linters + 1] = linter
		else
			self.remove[#self.remove + 1] = convert_map[linter]
		end
	end


end

function link:find_formatters()
	local opts = self.opts["formatters"]
	local file_opts = opts[self.file_type] or {}

	local convert_map = require("mason-conform.mapping").conform_to_package
	local all_formatters = require("conform.formatters").list_all_formatters()

	local exclude = util.list_to_set(file_opts["exclude"])

	local categorize_formatters = { {}, {}, {}, {} }
	for formatter in pairs(all_formatters) do
		local mason_formatter = convert_map[formatter]
		if not mason_formatter then
			goto continue
		end

		if exclude[formatter] then
			self.remove[#self.remove + 1] = mason_formatter
			goto continue
		end

		local spec = self.mason_registry.get_package(mason_formatter).spec
		local lang_match = false
		for _, lang in ipairs(spec["languages"] or {}) do
			if string.lower(lang) == self.file_type then
				lang_match = true
				break
			end
		end
		if not lang_match then
			goto continue
		end

		local categories = util.list_to_set(spec.categories or {})
		if not categories["Formatter"] then
			goto continue
		end
		if #spec.categories == 1 then
			if #spec.languages == 1 then
				categorize_formatters[1][#categorize_formatters[1] + 1] = formatter
			else
				categorize_formatters[3][#categorize_formatters[3] + 1] = formatter
			end
		else
			if #spec.languages == 1 then
				categorize_formatters[2][#categorize_formatters[2] + 1] = formatter
			else
				categorize_formatters[4][#categorize_formatters[4] + 1] = formatter
			end
		end
		::continue::
	end

	local flatterned_order = {}
	for _, catagory in ipairs(categorize_formatters) do
		table.sort(catagory)
		for _, formatter in ipairs(catagory) do
			flatterned_order[#flatterned_order + 1] = formatter
		end
	end

	local result = util.append_unique(file_opts["include"], flatterned_order)
	for count, formatter in ipairs(result) do
		if count <= opts["limit"] then
			self.formatters[#self.formatters + 1] = formatter
		else
			self.remove[#self.remove + 1] = convert_map[formatter]
		end
	end
end

function link:find_lsps()
	local opts = self.opts["lsps"]
	local file_opts = opts[self.file_type] or {}

	local mappings = require("mason-lspconfig.mappings")
	local convert_map = mappings.get_mason_map()["lspconfig_to_package"]
	local all_lsps = mappings.get_filetype_map()[self.file_type]
	if not all_lsps then return end

	table.sort(all_lsps)

	local exclude = util.list_to_set(file_opts["exclude"])

	local categorize_lsps = { {}, {}, {}, {} }
	for _, lsp in ipairs(all_lsps) do
		local mason_lsp = convert_map[lsp]
		if not mason_lsp then
			goto continue
		end

		if exclude[lsp] then
			self.remove[#self.remove + 1] = mason_lsp
			goto continue
		end

		local spec = self.mason_registry.get_package(mason_lsp).spec
		local categories = util.list_to_set(spec.categories or {})

		if not categories["LSP"] then
			goto continue
		end

		if #spec.categories == 1 then
			if #spec.languages == 1 then
				categorize_lsps[1][#categorize_lsps[1] + 1] = lsp
			else
				categorize_lsps[3][#categorize_lsps[3] + 1] = lsp
			end
		else
			if #spec.languages == 1 then
				categorize_lsps[2][#categorize_lsps[2] + 1] = lsp
			else
				categorize_lsps[4][#categorize_lsps[4] + 1] = lsp
			end
		end

		::continue::
	end
    
	local flatterned_order = {}
	for _, catagory in ipairs(categorize_lsps) do
		for _, lsp in ipairs(catagory) do
			flatterned_order[#flatterned_order + 1] = lsp
		end
	end

	local result = util.append_unique(file_opts["include"], flatterned_order)
	for count, lsp in ipairs(result) do
		if count <= opts["limit"] then
			self.lsps[#self.lsps + 1] = lsp
		else
			self.remove[#self.remove + 1] = convert_map[lsp]
		end
	end
end

function link:uninstall()
	if not self.opts["clean"] then
		return
	end
	for _, lsp in ipairs(self.remove) do
		if not self.mason_registry.has_package(lsp) then
			goto continue
		end
		local pkg = self.mason_registry.get_package(lsp)
		if pkg:is_installed() then
			pkg:uninstall()
			self.removed = true
		end
		::continue::
	end
	self.remove = {}
end

function link:install()
	require("mason-lspconfig").setup({
		automatic_enable = { exclude = self.remove },
		ensure_installed = self.lsps,
	})

	require("conform").setup({
		formatters_by_ft = { [self.file_type] = self.formatters },
	})
	require("mason-conform").setup({})

    require("lint").linters_by_ft = {
        [self.file_type] = self.linters
    }
    require("mason-nvim-lint").setup({
        automatic_installation = true,
    })
end

return function(opts)
	return link(opts)
end
