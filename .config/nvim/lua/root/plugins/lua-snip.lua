return {
	"L3MON4D3/LuaSnip",
	version = "v2.*", -- Follow the latest release.
	build = "make install_jsregexp",
	config = function()
		local ls = require("luasnip")
		local s = ls.snippet
		local i = ls.insert_node
		local t = ls.text_node

		-- Define snippets for Lua
		ls.add_snippets("lua", {
			s("func", {
				t("function "),
				i(1, "function_name"),
				t("("),
				i(2, "args"),
				t(")"),
				t({ "", "    " }),
				i(0),
				t({ "", "end" }),
			}),
			s("print", {
				t("print("),
				i(1, "value"),
				t(")"),
			}),
		})

		-- Define snippets for JavaScript/TypeScript
		ls.add_snippets("javascript", {
			s("imr", {
				t('import React from "react";'),
			}),
			s("conl", {
				t("console.log("),
				i(1),
				t(")"),
			}),
		})

		local typescript_snip = {
			s("st", {
				t("style={ `"),
				i(1),
				t("` }"),
			}),
			s("sto", {
				t("style={{ "),
				i(1),
				t(" }}"),
			}),
			s("ci", {
				t("console.info("),
				i(1),
				t(")"),
			}),
			s("cg", {
				t("console.log("),
				i(1),
				t(")"),
			}),
			s("cw", {
				t("console.warn("),
				i(1),
				t(")"),
			}),
			s("ce", {
				t("console.error("),
				i(1),
				t(")"),
			}),
			s("fu", {
				t("function "),
				i(1),
				t("("),
				i(2),
				t(")"),
			}),
			s("afu", {
				t("async function "),
				i(1),
				t("("),
				i(2),
				t(")"),
			}),
			s("imr", {
				t('import React from "react";'),
			}),
			s("clg", {
				t("console.log("),
				i(1),
				t(")"),
			}),
			s("li", {
				t("logger.info({"),
				t({ "", "  component: '" }),
				i(1, "ComponentName"),
				t("',"),
				t({ "", "  function: '" }),
				i(2, "functionName"),
				t("',"),
				t({ "", "  message: '" }),
				i(3, "message"),
				t("',"),
				t({ "", "  data: " }),
				i(4, "data"),
				t({ "", "})" }),
			}),
			s("le", {
				t("logger.error({"),
				t({ "", "  component: '" }),
				i(1, "ComponentName"),
				t("',"),
				t({ "", "  function: '" }),
				i(2, "functionName"),
				t("',"),
				t({ "", "  message: '" }),
				i(3, "message"),
				t("',"),
				t({ "", "  data: " }),
				i(4, "data"),
				t({ "", "})" }),
			}),
			s("lw", {
				t("logger.warn({"),
				t({ "", "  component: '" }),
				i(1, "ComponentName"),
				t("',"),
				t({ "", "  function: '" }),
				i(2, "functionName"),
				t("',"),
				t({ "", "  message: '" }),
				i(3, "message"),
				t("',"),
				t({ "", "  data: " }),
				i(4, "data"),
				t({ "", "})" }),
			}),
			s("ld", {
				t("logger.debug({"),
				t({ "", "  component: '" }),
				i(1, "ComponentName"),
				t("',"),
				t({ "", "  function: '" }),
				i(2, "functionName"),
				t("',"),
				t({ "", "  message: '" }),
				i(3, "message"),
				t("',"),
				t({ "", "  data: " }),
				i(4, "data"),
				t({ "", "})" }),
			}),
			s("usee", {
				t("useEffect(() => {"),
				t({ "", "  " }),
				i(1, "// effect code here"),
				t({ "", "}, [" }),
				i(2, "dependencies"),
				t("])"),
			}),
			s("uses", {
				t("const ["),
				i(1, "state"),
				t(", set"),
				i(2, "State"),
				t("] = useState("),
				i(3, "initialState"),
				t(")"),
			}),
			s("irnt", {
				t({ "import React from 'react'; ", "" }),
				t({ "import { render, screen } from '@testing-library/react-native'", "", "" }),
			}),
			s("desc", {
				t("describe('"),
				i(1),
				t({ "', () => {", "" }),
				i(2),
				t("})"),
			}),
			s("it", {
				t("it('"),
				i(1),
				t({ "', () => {", "" }),
				i(2),
				t("})"),
			}),
			s("ren", {
				t("render(<"),
				i(1),
				t({ "/>);", "" }),
			}),
		}

		ls.add_snippets("typescript", typescript_snip)
		ls.add_snippets("typescriptreact", typescript_snip)

		-- Define snippets for Go
		ls.add_snippets("go", {
			s("genSuite", {

				t("package "),
				i(1),
				t(
					'\n\nimport (\n    "testing"\n    "github.com/stretchr/testify/suite"\n    "github.com/stretchr/testify/assert"\n)\n\n'
				),
				t("type "),
				i(2),
				t("TestSuite struct {\n    suite.Suite\n}\n\n"),
				t("func (suite *"),
				i(2),
				t("TestSuite) Test"),
				i(3),
				t("() {\n    "),
				i(0),
				t("\n}\n\n"),
				t("func Test"),
				i(2),
				t("TestSuite(t *testing.T) {\n    suite.Run(t, new("),
				i(2),
				t("TestSuite))\n}\n"),
			}),
			s("tests", {
				t("func (suite *"),
				i(1),
				t("TestSuite) Test"),
				i(1),
				t("() {\n    "),
				i(0),
				t("\n}"),
			}),
			s("ts", {
				t("func (suite *"),
				i(1),
				t(") Test"),
				i(2),
				t("() {\n    "),
				i(0),
				t("\n}"),
			}),
			s("ut", {
				t("func Test"),
				i(1),
				t("(t *testing.T) {\n    "),
				i(0),
				t("\n}"),
			}),
			s("tss", {
				t("func (suite *"),
				i(1),
				t(") setupTest"),
				i(2),
				t("() {\n    "),
				i(0),
				t("\n}\n\n"),
				t("func (suite *"),
				i(1),
				t(") Test"),
				i(2),
				t("() {\n    suite.setupTest"),
				i(2),
				t("()\n}"),
			}),
			s("ifer", {
				t("if err != nil {\n    "),
				i(0),
				t("\n}"),
			}),
			s("ifel", {
				t("if "),
				i(1),
				t(" {\n    "),
				i(0),
				t("\n} else {\n\n}"),
			}),
			s("uni", {
				t('panic("unimplemented")'),
			}),
			s("sf", {
				t("func ("),
				i(1, "structFrom"),
				t(") "),
				i(2, "Name"),
				t("("),
				i(3, "parameter"),
				t(") {\n    "),
				i(0),
				t("\n}"),
			}),
			s("sfr", {
				t("func ("),
				i(1, "structFrom"),
				t(") "),
				i(2, "Name"),
				t("("),
				i(3, "parameter"),
				t(") ("),
				i(4, "returnValue"),
				t(") {\n    "),
				i(0),
				t("\n}"),
			}),
			s("vs", {
				t("var (\n    "),
				i(0),
				t("\n)"),
			}),
			s("rn", {
				t("return nil"),
			}),
			s("re", {
				t("return err"),
			}),
			s("r", {
				t("return "),
				i(0),
			}),
			s("rqn", {
				t("require.Nil(t, err)"),
			}),
			s("ern", {
				t("err != nil {\n    "),
				i(0),
				t("\n}\n    require.Nil(t, err)"),
			}),
			s("lp", {
				t("log.Println("),
				i(1),
				t(")"),
			}),
			s("lpa", {
				t('log.Println("'),
				i(1),
				t('", '),
				i(1),
				t(")"),
			}),
		})
		-- Define snippets for JSON
		ls.add_snippets("json", {
			s("kv", {
				t('"'),
				i(1),
				t('": "'),
				i(0),
				t('",'),
			}),
			s("ko", {
				t('"'),
				i(1),
				t('": {\n'),
				i(0),
				t("\n},"),
			}),
		})

		-- Define snippets for Markdown
		ls.add_snippets("markdown", {
			s("nl", {
				t("1. "),
			}),
			s("el", { -- external link
				t("["),
				i(1),
				t("]("),
				i(2),
				t(")"),
			}),
			s("bold", {
				t("**"),
				i(1),
				t("**"),
			}),
			s("italic", {
				t("*"),
				i(1),
				t("*"),
			}),
			s("note", {
				t({ ">[!Note]", "> " }),
			}),
			s("warn", {
				t({ ">[!Warning]", "> " }),
			}),
			s("Important", {
				t({ ">[!Important]", "> " }),
			}),
			s("h1", {
				t("# "),
				i(1),
			}),
			s("h2", {
				t("## "),
				i(1),
			}),
			s("h3", {
				t("### "),
				i(1),
			}),
			s("h4", {
				t("#### "),
				i(1),
			}),
			s("link", {
				t("[["),
				i(0),
				t("]]"),
			}),
			s("check", {
				t("- [ ] "),
			}),
			s(">", {
				t(" "),
			}),
		})

		-- Define snippets for Rust
		ls.add_snippets("rust", {
			s("match", {
				t("match "),
				i(1, "value"),
				t(" {"),
				t({ "", "    " }),
				i(2, "pattern => {"),
				t({ "", "        " }),
				i(3),
				t({ "", "    }," }),
				t({ "", "}" }),
			}),
		})

		-- Define snippets for Ansible
		ls.add_snippets("yaml", {
			s("install_arc", {
				t("---\n"),
				t("- name: Install arc\n"),
				t("  community.general.homebrew_cask:\n"),
				t("    name: arc\n"),
				t("    state: present\n"),
				t("    update_homebrew: yes\n"),
				t("  ignore_errors: true\n"),
			}),
		})

		-- Key mappings (as defined previously)
		vim.api.nvim_set_keymap(
			"i",
			"<Tab>",
			[[luasnip#expand_or_jumpable() ? '<Plug>luasnip-expand-or-jump' : '<Tab>']],
			{ expr = true, silent = true }
		)
		vim.api.nvim_set_keymap("i", "<S-Tab>", '<cmd>lua require("luasnip").jump(-1)<CR>', { silent = true })
		vim.api.nvim_set_keymap("s", "<Tab>", '<cmd>lua require("luasnip").jump(1)<CR>', { silent = true })
		vim.api.nvim_set_keymap("s", "<S-Tab>", '<cmd>lua require("luasnip").jump(-1)<CR>', { silent = true })
		vim.api.nvim_set_keymap(
			"i",
			"<C-E>",
			[[luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-E>']],
			{ expr = true, silent = true }
		)
		vim.api.nvim_set_keymap(
			"s",
			"<C-E>",
			[[luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-E>']],
			{ expr = true, silent = true }
		)
	end,
}
