.PHONY: test lint format

test:
	nvim --headless --noplugin -u tests/minimal_init.lua -c "lua require('plenary.test_harness').test_directory('tests/marginalia', { minimal_init = 'tests/minimal_init.lua' })"

lint:
	luacheck lua/ tests/

format:
	stylua lua/ tests/

install-hooks:
	pre-commit install
