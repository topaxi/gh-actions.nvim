.PHONY: all build clean

all: build

clean:
	rm -rf ./lua/libgh_actions_rust.so ./lua/deps

build: clean
	cargo build --release
	mkdir -p ./lua/deps/
	cp ./target/release/libgh_actions_rust.dylib ./lua/libgh_actions_rust.so || true
	cp ./target/release/libgh_actions_rust.so ./lua/libgh_actions_rust.so || true
	cp ./target/release/deps/*.rlib ./lua/deps/
