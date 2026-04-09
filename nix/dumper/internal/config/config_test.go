package config_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/svnlto/dumper/internal/config"
)

func TestLoad_AllRequired(t *testing.T) {
	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "config.json")
	os.WriteFile(cfgPath, []byte(`{
		"remote_host": "100.64.0.1",
		"remote_user": "admin",
		"remote_path": "/Users/admin/Photos/Photos Library.photoslibrary/"
	}`), 0644)

	cfg, err := config.Load(cfgPath)
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
	if cfg.SSHKeyPath != "/var/lib/dumper/id_ed25519" {
		t.Errorf("SSHKeyPath = %q, want default derived from StateDir", cfg.SSHKeyPath)
	}
}

func TestLoad_WithOverrides(t *testing.T) {
	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "config.json")
	os.WriteFile(cfgPath, []byte(`{
		"remote_host": "100.64.0.1",
		"remote_user": "admin",
		"remote_path": "/photos/",
		"dump_dir": "/data/dump",
		"max_streams": 4,
		"ssh_key_path": "/custom/key"
	}`), 0644)

	cfg, err := config.Load(cfgPath)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.DumpDir != "/data/dump" {
		t.Errorf("DumpDir = %q, want %q", cfg.DumpDir, "/data/dump")
	}
	if cfg.MaxStreams != 4 {
		t.Errorf("MaxStreams = %d, want %d", cfg.MaxStreams, 4)
	}
	if cfg.SSHKeyPath != "/custom/key" {
		t.Errorf("SSHKeyPath = %q, want %q", cfg.SSHKeyPath, "/custom/key")
	}
}

func TestLoad_MissingRequired(t *testing.T) {
	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "config.json")
	os.WriteFile(cfgPath, []byte(`{}`), 0644)

	_, err := config.Load(cfgPath)
	if err == nil {
		t.Fatal("expected error for missing required fields, got nil")
	}
}

func TestLoad_FileNotFound(t *testing.T) {
	_, err := config.Load("/nonexistent/config.json")
	if err == nil {
		t.Fatal("expected error for missing file, got nil")
	}
}

func TestLoad_NegativeValues(t *testing.T) {
	dir := t.TempDir()
	cfgPath := filepath.Join(dir, "config.json")

	cases := []struct {
		name string
		json string
	}{
		{"negative max_streams", `{"remote_host":"h","remote_user":"u","remote_path":"/p","max_streams":-1}`},
		{"negative sync_interval", `{"remote_host":"h","remote_user":"u","remote_path":"/p","sync_interval":-5}`},
		{"negative retry_interval", `{"remote_host":"h","remote_user":"u","remote_path":"/p","retry_interval":-1}`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			os.WriteFile(cfgPath, []byte(tc.json), 0644)
			_, err := config.Load(cfgPath)
			if err == nil {
				t.Fatalf("expected error for %s, got nil", tc.name)
			}
		})
	}
}
