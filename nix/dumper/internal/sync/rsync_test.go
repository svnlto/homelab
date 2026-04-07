package sync_test

import (
	"testing"

	"github.com/svnlto/dumper/internal/sync"
)

func TestBuildRsyncArgs(t *testing.T) {
	args := sync.BuildRsyncArgs(sync.RsyncOpts{
		SSHKeyPath: "/secrets/ssh/id_ed25519",
		RemoteUser: "admin",
		RemoteHost: "100.64.0.1",
		RemotePath: "/Users/admin/Photos/Photos Library.photoslibrary/",
		LocalPath:  "/mnt/dump/Users/admin/Photos/Photos Library.photoslibrary/",
		FilesFrom:  "/tmp/missing.txt",
	})

	hasFlag := func(flag string) bool {
		for _, a := range args {
			if a == flag {
				return true
			}
		}
		return false
	}

	if !hasFlag("--partial") {
		t.Error("missing --partial flag")
	}
	if !hasFlag("--inplace") {
		t.Error("missing --inplace flag")
	}
	if !hasFlag("--files-from=/tmp/missing.txt") {
		t.Error("missing --files-from flag")
	}
}

func TestBuildDatabaseRsyncArgs(t *testing.T) {
	args := sync.BuildDatabaseRsyncArgs(sync.RsyncOpts{
		SSHKeyPath: "/secrets/ssh/id_ed25519",
		RemoteUser: "admin",
		RemoteHost: "100.64.0.1",
		RemotePath: "/Users/admin/Photos/Photos Library.photoslibrary/",
		LocalPath:  "/mnt/dump/Users/admin/Photos/Photos Library.photoslibrary/",
	})

	src := args[len(args)-2]
	dst := args[len(args)-1]
	if len(src) < len("database/") || src[len(src)-len("database/"):] != "database/" {
		t.Errorf("source should end with database/, got %q", src)
	}
	if len(dst) < len("database/") || dst[len(dst)-len("database/"):] != "database/" {
		t.Errorf("dest should end with database/, got %q", dst)
	}
}

func TestParseTransferLine(t *testing.T) {
	tests := []struct {
		line      string
		wantXfer  bool
		wantBytes int64
	}{
		{">f+++++++++ 12345 originals/ABCD/IMG.HEIC", true, 12345},
		{".f          0 originals/ABCD/IMG.HEIC", false, 0},
		{"", false, 0},
	}

	for _, tt := range tests {
		xfer, bytes := sync.ParseTransferLine(tt.line)
		if xfer != tt.wantXfer {
			t.Errorf("ParseTransferLine(%q): xfer = %v, want %v", tt.line, xfer, tt.wantXfer)
		}
		if bytes != tt.wantBytes {
			t.Errorf("ParseTransferLine(%q): bytes = %d, want %d", tt.line, bytes, tt.wantBytes)
		}
	}
}
