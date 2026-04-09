package photos_test

import (
	"database/sql"
	"os"
	"path/filepath"
	"testing"

	_ "modernc.org/sqlite"

	"github.com/svnlto/dumper/internal/photos"
)

func createTestDB(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "Photos.sqlite")

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	_, err = db.Exec(`
		CREATE TABLE ZASSET (
			Z_PK INTEGER PRIMARY KEY,
			ZDIRECTORY TEXT,
			ZFILENAME TEXT,
			ZTRASHEDSTATE INTEGER DEFAULT 0
		);
		INSERT INTO ZASSET (ZDIRECTORY, ZFILENAME, ZTRASHEDSTATE) VALUES ('ABCD', 'IMG_0001.HEIC', 0);
		INSERT INTO ZASSET (ZDIRECTORY, ZFILENAME, ZTRASHEDSTATE) VALUES ('ABCD', 'IMG_0002.HEIC', 0);
		INSERT INTO ZASSET (ZDIRECTORY, ZFILENAME, ZTRASHEDSTATE) VALUES ('EFGH', 'IMG_0003.HEIC', 0);
		INSERT INTO ZASSET (ZDIRECTORY, ZFILENAME, ZTRASHEDSTATE) VALUES ('IJKL', 'IMG_0004.HEIC', 1);
	`)
	if err != nil {
		t.Fatal(err)
	}
	return dbPath
}

func TestQueryOriginals(t *testing.T) {
	dbPath := createTestDB(t)

	originals, err := photos.QueryOriginals(dbPath)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(originals) != 3 {
		t.Fatalf("got %d originals, want 3 (trashed excluded)", len(originals))
	}

	// Verify deterministic ordering by directory then filename
	want := []string{
		"originals/ABCD/IMG_0001.HEIC",
		"originals/ABCD/IMG_0002.HEIC",
		"originals/EFGH/IMG_0003.HEIC",
	}
	for i, o := range originals {
		if o != want[i] {
			t.Errorf("originals[%d] = %q, want %q", i, o, want[i])
		}
	}
}

func TestCheckIntegrity_Valid(t *testing.T) {
	dbPath := createTestDB(t)
	err := photos.CheckIntegrity(dbPath)
	if err != nil {
		t.Errorf("expected valid DB, got error: %v", err)
	}
}

func TestCheckIntegrity_Corrupted(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "bad.sqlite")
	os.WriteFile(dbPath, []byte("not a database"), 0644)

	err := photos.CheckIntegrity(dbPath)
	if err == nil {
		t.Error("expected error for corrupted DB, got nil")
	}
}

func TestCheckpointWAL(t *testing.T) {
	dbPath := createTestDB(t)
	err := photos.CheckpointWAL(dbPath)
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}
