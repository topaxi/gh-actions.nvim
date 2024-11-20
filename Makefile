.PHONY: all build clean

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
