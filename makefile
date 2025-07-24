all: ubuntu seed.iso gpt

ubuntu: main.swift main.entitlements
	swiftc main.swift -o ubuntu -framework Virtualization
	codesign --entitlements main.entitlements -s - ubuntu

gpt: gpt.swift main.entitlements
	swiftc gpt.swift -o gpt -framework Virtualization
	codesign --entitlements main.entitlements -s - gpt

seed.iso:
	./gen-seed.sh

clean:
	rm -f ubuntu
