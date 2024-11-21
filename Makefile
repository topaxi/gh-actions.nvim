.PHONY: all build clean prepare_test test

all: build copy

clean:
	rm -rf ./lua/pipeline_native/yaml.so ./lua/pipeline_native/deps

depsdir:
	mkdir -p ./lua/pipeline_native/deps

build:
	cargo build --release

copy: clean depsdir
	cp ./target/release/libpipeline_native.dylib ./lua/pipeline_native/yaml.so || true
	cp ./target/release/libpipeline_native.so ./lua/pipeline_native/yaml.so || true
	cp ./target/release/deps/*.rlib ./lua/pipeline_native/deps/

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
