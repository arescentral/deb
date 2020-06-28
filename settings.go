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
}

const (
	dirSetting     = "PLUGIN_DIR"
	archiveSetting = "PLUGIN_ARCHIVE"
	archSetting    = "PLUGIN_ARCH"
)

func loadSettings() settings {
	return settings{
		source:        source(),
		version:       version(),
		sourceVersion: sourceVersion(),
		dir:           dir(),
		archive:       archive(),
		arch:          arch(),
	}
}

func dir() string     { return getenv(dirSetting, "debian") }
func archive() string { return getenv(archiveSetting, "dist/*") }
func arch() string    { return getenv(archSetting, runtime.GOARCH) }
func source() string  { return parseChangelog("Source") }
func version() string { return parseChangelog("Version") }

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
	if s := os.Getenv(key); s != "" {
		return s
	}
	return def
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
