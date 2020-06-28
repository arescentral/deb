DEBIAN=sid \
       bullseye \
       buster \
       stretch \
       jessie

UBUNTU=focal \
       bionic \
       xenial \
       trusty

all: $(DEBIAN) $(UBUNTU)
.PHONY: $(DEBIAN) $(UBUNTU)

$(UBUNTU): %:
	./build.sh ubuntu $@
$(DEBIAN): %:
	./build.sh debian $@
