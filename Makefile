.PHONY: all build clean prepare_test test

all: build copy

clean:
	rm -rf ./lua/gh_actions_native/yaml.so ./lua/gh_actions_native/deps

depsdir:
	mkdir -p ./lua/gh_actions_native/deps

build:
	cargo build --release

copy: clean depsdir
	cp ./target/release/libgh_actions_rust.dylib ./lua/gh_actions_native/yaml.so || true
	cp ./target/release/libgh_actions_rust.so ./lua/gh_actions_native/yaml.so || true
	cp ./target/release/deps/*.rlib ./lua/gh_actions_native/deps/

plugin_dir := ./.tests/site/pack/deps/start
plugins := $(plugin_dir)/plenary.nvim $(plugin_dir)/nui.nvim

$(plugin_dir)/plenary.nvim:
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(plugin_dir)/plenary.nvim

$(plugin_dir)/nui.nvim:
	git clone --depth 1 https://github.com/MunifTanjim/nui.nvim $(plugin_dir)/nui.nvim

prepare_test:
	mkdir -p $(plugin_dir)

test: prepare_test $(plugins)
	nvim --headless --noplugin -u tests/init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.lua'}"

clean-test:
	rm -rf ./.tests
