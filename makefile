all: ubuntu seed.iso

ubuntu: main.swift main.entitlements
	swiftc main.swift -o ubuntu -framework Virtualization
	codesign --entitlements main.entitlements -s - ubuntu

seed.iso:
	./gen-seed.sh

clean:
	rm -f ubuntu
