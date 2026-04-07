package config_test

import (
	"os"
	"testing"

	"github.com/svnlto/dumper/internal/config"
)

func TestLoad_AllRequired(t *testing.T) {
	t.Setenv("REMOTE_HOST", "100.64.0.1")
	t.Setenv("REMOTE_USER", "admin")
	t.Setenv("REMOTE_PATH", "/Users/admin/Photos/Photos Library.photoslibrary/")
	t.Setenv("SSH_KEY_PATH", "/tmp/test_key")

	cfg, err := config.Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.RemoteHost != "100.64.0.1" {
		t.Errorf("RemoteHost = %q, want %q", cfg.RemoteHost, "100.64.0.1")
	}
	if cfg.DumpDir != "/mnt/dump" {
		t.Errorf("DumpDir = %q, want default %q", cfg.DumpDir, "/mnt/dump")
	}
	if cfg.StateDir != "/var/lib/dumper" {
		t.Errorf("StateDir = %q, want default %q", cfg.StateDir, "/var/lib/dumper")
	}
	if cfg.MaxStreams != 8 {
		t.Errorf("MaxStreams = %d, want default %d", cfg.MaxStreams, 8)
	}
}

func TestLoad_MissingRequired(t *testing.T) {
	os.Clearenv()
	_, err := config.Load()
	if err == nil {
		t.Fatal("expected error for missing required env vars, got nil")
	}
}
