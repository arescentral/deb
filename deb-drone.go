package main

import (
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/mholt/archiver/v3"
)

func main() {
	s := loadSettings()
	archive := globSingle(s.archive)

	workDir := tmpdir()
	extension := unarchive(archive, workDir)

	buildDir := globSingle(filepath.Join(workDir, "*"))
	orig := fmt.Sprintf("%s_%s.orig%s", s.source, s.sourceVersion, extension)
	cp(archive, filepath.Join(workDir, orig))
	cpR(s.dir, filepath.Join(buildDir, "debian"))

	os.Setenv("DEBIAN_FRONTEND", "noninteractive")
	buildDeps := fmt.Sprintf("%s-build-deps_%s_all.deb", s.source, s.version)
	run("mk-build-deps", filepath.Join(s.dir, "control"))
	for _, key := range s.recvKeys {
		run("apt-key", "adv", "--keyserver", s.keyserver, "--recv", key)
	}
	for _, source := range s.sources {
		run("apt-add-repository", source)
	}
	run("apt-get", "update")
	run(
		"apt-get", "install", "-y", "--no-install-recommends",
		"devscripts",
		"./"+buildDeps,
	)

	runIn(buildDir, "dpkg-buildpackage")
	changes := globSingle(filepath.Join(workDir, "*.changes"))
	run("lintian", "--no-tag-display-limit", changes)
	for _, src := range outputs(buildDir) {
		cp(src, filepath.Base(src))
	}
}

// Runs command; exits on failure.
func run(name string, args ...string) {
	fmt.Printf("RUN %s %v\n", name, args)
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: %s\n", name, err)
		os.Exit(1)
	}
}

// Runs command in given dir; exits on failure.
func runIn(dir, name string, args ...string) {
	origDir := pwd()
	cd(dir)
	defer cd(origDir)
	run(name, args...)
}

func cd(dir string) {
	fmt.Printf("CD %s\n", dir)
	err := os.Chdir(dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "cd %s: %s\n", dir, err)
		os.Exit(1)
	}
}

func pwd() string {
	dir, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "getwd %s: %s\n", dir, err)
		os.Exit(1)
	}
	return dir
}

// Globs for files matching pattern; exits on failure.
func glob(pattern string) []string {
	paths, err := filepath.Glob(pattern)
	if err != nil {
		fmt.Fprintf(os.Stderr, "glob %s: %s\n", pattern, err)
		os.Exit(1)
	}
	return paths
}

// Globs for single file matching pattern; exits on failure or not single match.
func globSingle(pattern string) string {
	matches := glob(pattern)
	if len(matches) == 0 {
		fmt.Fprintf(os.Stderr, "glob %s: no matches\n", pattern)
		os.Exit(1)
	} else if len(matches) > 1 {
		fmt.Fprintf(os.Stderr, "glob %s: multiple matches:\n", matches)
		for _, path := range matches {
			fmt.Fprintf(os.Stderr, "  - %s\n", path)
		}
		os.Exit(1)
	}
	return matches[0]
}

func unarchive(source, destination string) (extension string) {
	archive, err := archiver.ByExtension(source)
	if err != nil {
		fmt.Fprintf(os.Stderr, "unarchive %s: %s\n", source, err.Error())
		os.Exit(1)
	}

	var u archiver.Unarchiver
	switch unarchiver := archive.(type) {
	case *archiver.TarBz2:
		u, extension = unarchiver, ".tar.bz2"
	case *archiver.TarGz:
		u, extension = unarchiver, ".tar.gz"
	case *archiver.TarXz:
		u, extension = unarchiver, ".tar.xz"
	default:
		fmt.Fprintf(os.Stderr, "unarchive %s: not a supported archive: %T\n", source, archive)
		os.Exit(1)
	}

	err = u.Unarchive(source, destination)
	if err != nil {
		fmt.Fprintf(os.Stderr, "unarchive %s: %s\n", source, err.Error())
		os.Exit(1)
	}
	return extension
}

func tmpdir() string {
	path, err := ioutil.TempDir("", "deb")
	if err != nil {
		fmt.Fprintf(os.Stderr, "tmpdir %s: %s\n", path, err)
		os.Exit(1)
	}
	fmt.Printf("MKDIR %s\n", path)
	return path
}

func makedirs(components ...string) {
	path := filepath.Join(components...)
	err := os.MkdirAll(path, 0755)
	if err != nil {
		fmt.Fprintf(os.Stderr, "makedirs %s: %s\n", path, err)
		os.Exit(1)
	}
}

func cp(src, dst string) {
	fmt.Printf("COPY %s %s\n", src, dst)
	srcFile, err := os.Open(src)
	if err != nil {
		fmt.Fprintf(os.Stderr, "open %s: %s\n", src, err)
		os.Exit(1)
	}
	defer closeOrDie(src, srcFile)

	dstFile, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "open %s: %s\n", dst, err)
		os.Exit(1)
	}
	defer closeOrDie(dst, dstFile)

	_, err = io.Copy(dstFile, srcFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "copy %s: %s\n", dst, err)
	}
}

func cpR(src, dst string) {
	root := src
	err := filepath.Walk(root, func(src string, info os.FileInfo, err error) error {
		rel, err := filepath.Rel(root, src)
		if err != nil {
			return err
		}

		dst := filepath.Join(dst, rel)
		if info.IsDir() {
			makedirs(dst)
			return nil
		}
		cp(src, dst)
		return nil
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "copy %s: %s\n", src, err)
		os.Exit(1)
	}
}

// Lists all files in parent of buildDir, except buildDir.
func outputs(buildDir string) []string {
	outputs := []string{}
	for _, path := range glob(filepath.Join(filepath.Dir(buildDir), "*")) {
		if path != buildDir {
			outputs = append(outputs, path)
		}
	}
	return outputs
}

// Closes f; exits on error.
func closeOrDie(path string, f *os.File) {
	err := f.Close()
	if err != nil {
		fmt.Fprintf(os.Stderr, "close %s: %s\n", path, err)
		os.Exit(1)
	}
}
