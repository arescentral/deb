arescentral/deb .deb builder
============================

Examples
--------

Basic example, assuming distfile is the only file in ``dist/`` and the debian dir is ``debian/``::

    - name: deb
      image: arescentral/deb:focal

Fully-specified example::

    - name: deb
      image: arescentral/deb:focal-1.0.0
      settings:
        dir: pkg/debian/focal
        archive: foo-*.tgz
        keyserver: keyserver.ubuntu.com
        keys:
        - 5A4F5210FF46CEE4B799098BAC879AADD5B51AE9
        sources:
        - deb [arch=amd64] http://apt.arescentral.org focal contrib

Settings
--------

dir (default: ``debian``):
    The ``debian`` dir, containing control, changelog, and other required Debian files
archive (default: ``dist/*``):
    A glob matching a single distfile to use as the Debian source archive
keyserver (default: keyserver.ubuntu.com):
    The key server to fetch ``keys`` from
keys (default: none):
    A list of key fingerprints to fetch from the keyserver
sources (default: none):
    A list of lines to be added to the list of apt-sources with apt-add-repository
