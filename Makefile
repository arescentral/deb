DEBIAN=bookworm bullseye buster
UBUNTU=jammy focal bionic xenial

all: $(DEBIAN) $(UBUNTU)
.PHONY: $(DEBIAN) $(UBUNTU)

$(UBUNTU): %:
	./build.sh $@
$(DEBIAN): %:
	./build.sh $@
