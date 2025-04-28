return {
  {
    "williamboman/mason.nvim",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      {
        "folke/lazydev.nvim",
        ft = "lua",
        opts = {
          library = {
            { path = "${3rd}/luv/library", words = { "vim%.uv" } },
          },
        },
      },
    },
    config = function()
      local mason = require("mason")
      local mason_lspconfig = require("mason-lspconfig")

      mason.setup({
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      })

      mason_lspconfig.setup({
        ensure_installed = {
          "tailwindcss",
          "ts_ls",
          "html",
          "cssls",
          "harper_ls",
          "jsonls",
          "dockerls",
          "docker_compose_language_service",
          "clangd",
          "bashls",
          "yamlls",
          "eslint",
          "gopls",
          "pyright",
          "volar",
          "solang",
          "solidity",
          "prismals",
          "graphql",
          "rust_analyzer",
        },
        automatic_installation = true,
      })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      { "antosha417/nvim-lsp-file-operations", config = true },
    },
    config = function()
      local lspconfig = require("lspconfig")
      local cmp_nvim_lsp = require("cmp_nvim_lsp")

      local list_lsp = {
		 "lua_ls",
        "tailwindcss",
        "ts_ls",
        "html",
        "cssls",
        "harper_ls",
        "jsonls",
        "dockerls",
        "docker_compose_language_service",
        "clangd",
        "bashls",
        "yamlls",
        "eslint",
        "gopls",
        "pyright",
        "volar",
        "solang",
        "solidity",
        "prismals",
        "graphql",
        "rust_analyzer",
      }

      local keymap = vim.keymap -- for conciseness

      local on_attach = function(client, bufnr)
        local opts = { buffer = bufnr }

        opts.desc = "Show LSP references"
        keymap.set("n", "gD", "<cmd>Lspsaga finder<CR>", opts)

        opts.desc = "Go to declaration"
        keymap.set("n", "gR", vim.lsp.buf.declaration, opts)

        opts.desc = "Show LSP implementations"
        keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts)

        opts.desc = "Show LSP type definitions"
        keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts)

        opts.desc = "Smart rename"
        keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

        opts.desc = "Show buffer diagnostics"
        keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts)

        opts.desc = "Show line diagnostics"
        keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

        opts.desc = "Show documentation for what is under cursor"
        keymap.set("n", "K", vim.lsp.buf.hover, opts)

        opts.desc = "Restart LSP"
        keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts)
      end

      local capabilities = cmp_nvim_lsp.default_capabilities()

      local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        -- You might want to enable this if you want custom sign icons
        vim.diagnostic.config({virtual_text=true,signs= signs})
      end

      for _, lsp in ipairs(list_lsp) do
        lspconfig[lsp].setup({
          capabilities = capabilities,
          on_attach = on_attach,
        })
      end
    end,
  },
}
