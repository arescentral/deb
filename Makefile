DEBIAN=bullseye buster stretch
UBUNTU=focal bionic xenial trusty

all: $(DEBIAN) $(UBUNTU)
.PHONY: $(DEBIAN) $(UBUNTU)

$(UBUNTU): %:
	./build.sh $@
$(DEBIAN): %:
	./build.sh $@
