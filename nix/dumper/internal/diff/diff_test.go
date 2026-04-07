package diff_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/svnlto/dumper/internal/diff"
)

func TestComputeMissing_AllMissing(t *testing.T) {
	localDir := t.TempDir()
	dbOriginals := []string{
		"originals/ABCD/IMG_0001.HEIC",
		"originals/ABCD/IMG_0002.HEIC",
		"originals/EFGH/IMG_0003.HEIC",
	}

	missing, err := diff.ComputeMissing(dbOriginals, localDir)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(missing) != 3 {
		t.Errorf("got %d missing, want 3", len(missing))
	}
}

func TestComputeMissing_SomePresent(t *testing.T) {
	localDir := t.TempDir()

	dir := filepath.Join(localDir, "originals", "ABCD")
	os.MkdirAll(dir, 0755)
	os.WriteFile(filepath.Join(dir, "IMG_0001.HEIC"), []byte("data"), 0644)

	dbOriginals := []string{
		"originals/ABCD/IMG_0001.HEIC",
		"originals/ABCD/IMG_0002.HEIC",
		"originals/EFGH/IMG_0003.HEIC",
	}

	missing, err := diff.ComputeMissing(dbOriginals, localDir)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(missing) != 2 {
		t.Errorf("got %d missing, want 2", len(missing))
	}

	expected := map[string]bool{
		"originals/ABCD/IMG_0002.HEIC": true,
		"originals/EFGH/IMG_0003.HEIC": true,
	}
	for _, m := range missing {
		if !expected[m] {
			t.Errorf("unexpected missing file: %q", m)
		}
	}
}

func TestComputeMissing_AllPresent(t *testing.T) {
	localDir := t.TempDir()

	for _, rel := range []string{
		"originals/ABCD/IMG_0001.HEIC",
		"originals/EFGH/IMG_0002.HEIC",
	} {
		full := filepath.Join(localDir, rel)
		os.MkdirAll(filepath.Dir(full), 0755)
		os.WriteFile(full, []byte("data"), 0644)
	}

	dbOriginals := []string{
		"originals/ABCD/IMG_0001.HEIC",
		"originals/EFGH/IMG_0002.HEIC",
	}

	missing, err := diff.ComputeMissing(dbOriginals, localDir)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(missing) != 0 {
		t.Errorf("got %d missing, want 0", len(missing))
	}
}
