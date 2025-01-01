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
				t("function "), i(1, "function_name"), t("("), i(2, "args"), t(")"),
				t({ "", "    " }), i(0), t({ "", "end" }),
			}),
			s("print", {
				t("print("), i(1, "value"), t(")"),
			}),
		})


		-- Define snippets for JavaScript/TypeScript
		ls.add_snippets("javascript", {
			s("imr", {
				t('import React from "react";')
			}),
			s("conl", {
				t("console.log("), i(1), t(")"),
			}),
		})

		ls.add_snippets("typescript", {
			s("imr", {
				t('import React from "react";')
			}),
			s("conl", {
				t("console.log("), i(1), t(")"),
			}),
		})

		-- Define snippets for Go
		ls.add_snippets("go", {
			s("genSuite", {
				t("package "), i(1), t(
				"\n\nimport (\n    \"testing\"\n    \"github.com/stretchr/testify/suite\"\n    \"github.com/stretchr/testify/assert\"\n)\n\n"),
				t("type "), i(2), t("TestSuite struct {\n    suite.Suite\n}\n\n"),
				t("func (suite *"), i(2), t("TestSuite) Test"), i(3), t("() {\n    "), i(0), t("\n}\n\n"),
				t("func Test"), i(2), t("TestSuite(t *testing.T) {\n    suite.Run(t, new("), i(2), t(
				"TestSuite))\n}\n"),
			}),
			s("tests", {
				t("func (suite *"), i(1), t("TestSuite) Test"), i(1), t("() {\n    "), i(0), t("\n}"),
			}),
			s("ts", {
				t("func (suite *"), i(1), t(") Test"), i(2), t("() {\n    "), i(0), t("\n}"),
			}),
			s("ut", {
				t("func Test"), i(1), t("(t *testing.T) {\n    "), i(0), t("\n}"),
			}),
			s("tss", {
				t("func (suite *"), i(1), t(") setupTest"), i(2), t("() {\n    "), i(0), t("\n}\n\n"),
				t("func (suite *"), i(1), t(") Test"), i(2), t("() {\n    suite.setupTest"), i(2), t("()\n}"),
			}),
			s("ifer", {
				t("if err != nil {\n    "), i(0), t("\n}"),
			}),
			s("ifel", {
				t("if "), i(1), t(" {\n    "), i(0), t("\n} else {\n\n}"),
			}),
			s("uni", {
				t("panic(\"unimplemented\")"),
			}),
			s("sf", {
				t("func ("), i(1, "structFrom"), t(") "), i(2, "Name"), t("("), i(3, "parameter"), t(") {\n    "), i(0),
				t("\n}"),
			}),
			s("sfr", {
				t("func ("), i(1, "structFrom"), t(") "), i(2, "Name"), t("("), i(3, "parameter"), t(") ("), i(4,
				"returnValue"), t(") {\n    "), i(0), t("\n}"),
			}),
			s("vs", {
				t("var (\n    "), i(0), t("\n)"),
			}),
			s("rn", {
				t("return nil"),
			}),
			s("re", {
				t("return err"),
			}),
			s("r", {
				t("return "), i(0),
			}),
			s("rqn", {
				t("require.Nil(t, err)"),
			}),
			s("ern", {
				t("err != nil {\n    "), i(0), t("\n}\n    require.Nil(t, err)"),
			}),
			s("lp", {
				t("log.Println("), i(1), t(")"),
			}),
			s("lpa", {
				t("log.Println(\""), i(1), t("\", "), i(1), t(")"),
			}),
		})
		-- Define snippets for JSON
		ls.add_snippets("json", {
			s("kv", {
				t("\""), i(1), t("\": \""), i(0), t("\","),
			}),
			s("ko", {
				t("\""), i(1), t("\": {\n"), i(0), t("\n},"),
			}),
		})

		-- Define snippets for Markdown
		ls.add_snippets("markdown", {
			s("genMakefile", {
				t("#Setting Color\n"),
				t("CCEND = \\033[0m\n"),
				t("CCYAN = \\033[34m\n"),
				t("CGREEN = \\033[33m\n"),
				t("CCRED = \\033[31m\n"),
				t("CCPURPLE = \\033[35m\n\n"),
				t("#Get arguments pass\n"),
				t("ARGV = $(filter-out $@,$(MAKECMDGOALS))\n"),
				t("NAME = ${1:Name}.a\n"),
				t("EXEC = $1\n"),
				t("CC = c++\n\n"),
				t("PATH_SRC = ./srcs/\n"),
				t("PATH_OBJ = ./objs/\n\n"),
				t("SRC = ${2:sources}\n\n"),
				t("OBJ_SRC = $(SRC:.cpp=.o)\n\n"),
				t("SRC_O = $(addprefix $(PATH_SRC), $(SRC))\n"),
				t("OBJ_S = $(addprefix $(PATH_OBJ), $(OBJ_SRC))\n\n"),
				t("HEADER = includes/${3:Include}\n"),
				t("MK = Makefile\n"),
				t("SAN = -g3 -fsanitize=address\n"),
				t("FLAGS = -Wall -Werror -Wextra -std=c++98\n\n"),
				t("$(PATH_OBJ)%.o : $(PATH_SRC)%.cpp $(MK)\n"),
				t("\t@mkdir $(PATH_OBJ) 2> /dev/null || true\n"),
				t("\t@-$(CC) -o $@ -c $<\n"),
				t("\t@printf \"\\r\\t\\033[K$(CCYAN)\\t$< $(CCPURPLE)--> $(CCYAN)$@ $(CCEND)\"\n"),
				t("\t@sleep 0.1\n\n"),
				t("all: $(NAME)\n\n"),
				t("$(NAM): $(OBJ_S)\n"),
				t("\t@printf \"\\r\\t\\033[K$(CCYAN)[✅]\\t$(EXEC) $(CCPURPLE)--> $(CCYAN) Gen Objs$(CCEND)\"\n"),
				t("\t@printf \"\\n$(CCYAN)[✅]\\t$(CCPURPLE)Creation of Objs $(EXEC)...$(CCEND)\\n\"\n"),
				t("\t@printf \"$(CCYAN)[✅]\\t$(CCPURPLE)Creation of $(NAME)...$(CCEND)\\n\"\n"),
				t("\t@ar rc $(PATH_OBJ)$(NAME) $(OBJ_S)\n"),
				t("\t@$(CC) $(PATH_OBJ)$(NAME) -o $(EXEC)\n"),
				t("\t@printf \"$(CCYAN)[✅]\\t$(CCPURPLE)Compilation ./$(EXEC)...$(CCEND)\\n\"\n\n"),
				t("clean:\n"),
				t("\t@printf \"$(CCYAN)[✅]\\t$(CCRED)Removal of $(EXEC) Object...$(CCEND)\\n\"\n"),
				t("\t@-/bin/rm -rf $(PATH_OBJ)*.o\n\n"),
				t("fclean: clean\n"),
				t("\t@printf \"$(CCYAN)[✅]\\t$(CCRED)Removal of $(NAME)...$(CCEND)\\n\"\n"),
				t("\t@-/bin/rm -f $(PATH_OBJ)*.a\n"),
				t("\t@-/bin/rm -rf $(PATH_OBJ)\n"),
				t("\t@-/bin/rm -f Tags\n"),
				t("\t@-/bin/rm -rf .ccls-cache\n"),
				t("\t@-/bin/rm -f $(EXEC)\n\n"),
				t("norme:\n"),
				t("\t@echo \"\\033[33mNorme ...\"\n"),
				t("\t@norminette $(SRC)\n"),
				t("\t@norminette $(HEADER)\n\n"),
				t("git: fclean\n"),
				t("\t@git add .\n"),
				t("\t@git commit -m \"$(filter-out $@,$(MAKECMDGOALS))\"\n"),
				t("\t@git push\n\n"),
				t("auto: fclean\n"),
				t("\t@git add .\n"),
				t("\t@git commit -m \"Autosave\"\n"),
				t("\t@git push\n\n"),
				t(".PHONY: all clean fclean re san\n"),
				t(".SILENT :\n"),
				t("re: fclean all\n"),
			}),
			s("makefile", {
				t("#Setting Color\n"),
				t("CCEND = \\033[0m\n"),
				t("CCYAN = \\033[34m\n"),
				t("CGREEN = \\033[33m\n"),
				t("CCRED = \\033[31m\n"),
				t("CCPURPLE = \\033[35m\n\n"),
				t("#Get arguments pass\n"),
				t("ARGV = $(filter-out $@,$(MAKECMDGOALS))\n"),
				t("NAME = ${1:Name}.a\n"),
				t("EXEC = $1\n"),
				t("CC = c++\n\n"),
				t("PATH_SRC = ./srcs/\n"),
				t("PATH_OBJ = ./objs/\n\n"),
				t("SRC = ${2:sources}\n\n"),
				t("OBJ_SRC = $(SRC:.cpp=.o)\n\n"),
				t("SRC_O = $(addprefix $(PATH_SRC), $(SRC))\n"),
				t("OBJ_S = $(addprefix $(PATH_OBJ), $(OBJ_SRC))\n\n"),
				t("HEADER = includes/${3:Include}\n"),
				t("MK = Makefile\n"),
				t("SAN = -g3 -fsanitize=address\n"),
				t("FLAGS = -Wall -Werror -Wextra -std=c++98\n\n"),
				t("$(PATH_OBJ)%.o : $(PATH_SRC)%.cpp $(MK)\n"),
				t("\t@mkdir $(PATH_OBJ) 2> /dev/null || true\n"),
				t("\t@-$(CC) -o $@ -c $<\n"),
				t("\t@printf \"\\r\\t\\033[K$(CCYAN)\\t$< $(CCPURPLE)--> $(CCYAN)$@ $(CCEND)\"\n"),
				t("\t@sleep 0.1\n\n"),
				t("all: $(NAME)\n\n"),
				t("$(NAM): $(OBJ_S)\n"),
				t("\t@printf \"\\r\\t\\033[K$(CCYAN)[✅]\\t$(EXEC) $(CCPURPLE)--> $(CCYAN) Gen Objs$(CCEND)\"\n"),
				t("\t@printf \"\\n$(CCYAN)[✅]\\t$(CCPURPLE)Creation of Objs $(EXEC)...$(CCEND)\\n\"\n"),
				t("\t@printf \"$(CCYAN)[✅]\\t$(CCPURPLE)Creation of $(NAME)...$(CCEND)\\n\"\n"),
				t("\t@ar rc $(PATH_OBJ)$(NAME) $(OBJ_S)\n"),
				t("\t@$(CC) $(PATH_OBJ)$(NAME) -o $(EXEC)\n"),
				t("\t@printf \"$(CCYAN)[✅]\\t$(CCPURPLE)Compilation ./$(EXEC)...$(CCEND)\\n\"\n\n"),
				t("clean:\n"),
				t("\t@printf \"$(CCYAN)[✅]\\t$(CCRED)Removal of $(EXEC) Object...$(CCEND)\\n\"\n"),
				t("\t@-/bin/rm -rf $(PATH_OBJ)*.o\n\n"),
				t("fclean: clean\n"),
				t("\t@printf \"$(CCYAN)[✅]\\t$(CCRED)Removal of $(NAME)...$(CCEND)\\n\"\n"),
				t("\t@-/bin/rm -f $(PATH_OBJ)*.a\n"),
				t("\t@-/bin/rm -rf $(PATH_OBJ)\n"),
				t("\t@-/bin/rm -f Tags\n"),
				t("\t@-/bin/rm -rf .ccls-cache\n"),
				t("\t@-/bin/rm -f $(EXEC)\n\n"),
				t("norme:\n"),
				t("\t@echo \"\\033[33mNorme ...\"\n"),
				t("\t@norminette $(SRC)\n"),
				t("\t@norminette $(HEADER)\n\n"),
				t("git: fclean\n"),
				t("\t@git add .\n"),
				t("\t@git commit -m \"$(filter-out $@,$(MAKECMDGOALS))\"\n"),
				t("\t@git push\n\n"),
				t("auto: fclean\n"),
				t("\t@git add .\n"),
				t("\t@git commit -m \"Autosave\"\n"),
				t("\t@git push\n\n"),
				t(".PHONY: all clean fclean re san\n"),
				t(".SILENT :\n"),
				t("re: fclean all\n"),
			}),
		})

		-- Define snippets for Rust
		ls.add_snippets("rust", {
			s("match", {
				t("match "), i(1, "value"), t(" {"),
				t({ "", "    " }), i(2, "pattern => {"), t({ "", "        " }), i(3), t({ "", "    }," }),
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
		vim.api.nvim_set_keymap('i', '<Tab>',
			[[luasnip#expand_or_jumpable() ? '<Plug>luasnip-expand-or-jump' : '<Tab>']],
			{ expr = true, silent = true })
		vim.api.nvim_set_keymap('i', '<S-Tab>', '<cmd>lua require("luasnip").jump(-1)<CR>', { silent = true })
		vim.api.nvim_set_keymap('s', '<Tab>', '<cmd>lua require("luasnip").jump(1)<CR>', { silent = true })
		vim.api.nvim_set_keymap('s', '<S-Tab>', '<cmd>lua require("luasnip").jump(-1)<CR>', { silent = true })
		vim.api.nvim_set_keymap('i', '<C-E>', [[luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-E>']],
			{ expr = true, silent = true })
		vim.api.nvim_set_keymap('s', '<C-E>', [[luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<C-E>']],
			{ expr = true, silent = true })
	end
}
