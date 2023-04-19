.PHONY: build

build:
	cargo build --release
	mkdir -p ./lua/deps/
	rm -f ./lua/libgh_actions_rust.so
	cp ./target/release/libgh_actions_rust.dylib ./lua/libgh_actions_rust.so
	cp ./target/release/deps/*.rlib ./lua/deps/
