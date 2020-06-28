package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

type settings struct {
	source        string
	version       string
	sourceVersion string
	dir           string
	archive       string
	arch          string
	sources       []string
	keyserver     string
	recvKeys      []string
}

const (
	dirSetting       = "PLUGIN_DIR"
	archiveSetting   = "PLUGIN_ARCHIVE"
	archSetting      = "PLUGIN_ARCH"
	sourcesSetting   = "PLUGIN_SOURCES"
	keyserverSetting = "PLUGIN_KEYSERVER"
	recvKeysSetting  = "PLUGIN_RECV_KEYS"
)

func loadSettings() settings {
	return settings{
		source:        source(),
		version:       version(),
		sourceVersion: sourceVersion(),
		dir:           dir(),
		archive:       archive(),
		arch:          arch(),
		sources:       sources(),
		keyserver:     keyserver(),
		recvKeys:      recvKeys(),
	}
}

func dir() string        { return getenv(dirSetting, "debian") }
func archive() string    { return getenv(archiveSetting, "dist/*") }
func arch() string       { return getenv(archSetting, runtime.GOARCH) }
func source() string     { return parseChangelog("Source") }
func version() string    { return parseChangelog("Version") }
func sources() []string  { return splitenv(sourcesSetting) }
func keyserver() string  { return getenv(keyserverSetting, "keyserver.ubuntu.com") }
func recvKeys() []string { return splitenv(recvKeysSetting) }

func sourceVersion() string {
	v := version()
	if sourceVersion, sep, _ := rpartition(v, "-"); sep != "" {
		return sourceVersion
	}
	fmt.Fprintf(os.Stderr, "version %s: no hyphen\n", v)
	os.Exit(1)
	return ""
}

func getenv(key, def string) string {
	s := os.Getenv(key)
	if s == "" {
		return def
	}
	return s
}

func splitenv(key string) []string {
	s := os.Getenv(key)
	if s == "" {
		return nil
	}
	return strings.Split(s, ",")
}

func parseChangelog(setting string) string {
	cmd := exec.Command(
		"dpkg-parsechangelog",
		"-l", filepath.Join(dir(), "changelog"), "-S", setting,
	)
	cmd.Stderr = os.Stderr
	output, err := cmd.Output()
	if err != nil {
		fmt.Fprintf(os.Stderr, "dpkg-parsechangelog: %s\n", err)
		os.Exit(1)
	}
	return strings.Trim(string(output), " \t\n")
}

func rpartition(str, sep string) (pre, sepOut, post string) {
	idx := strings.LastIndex(str, sep)
	if idx == -1 {
		return "", "", str
	}
	return str[:idx], sep, str[idx+len(sep):]
}
