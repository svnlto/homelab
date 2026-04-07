package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type Config struct {
	RemoteHost string `json:"remote_host"`
	RemoteUser string `json:"remote_user"`
	RemotePath string `json:"remote_path"`
	SSHKeyPath string `json:"ssh_key_path"`
	DumpDir    string `json:"dump_dir"`
	StateDir   string `json:"state_dir"`
	MaxStreams  int    `json:"max_streams"`
}

// Load reads config from a JSON file. If configPath is empty,
// it defaults to /var/lib/dumper/config.json.
func Load(configPath string) (Config, error) {
	if configPath == "" {
		configPath = "/var/lib/dumper/config.json"
	}

	data, err := os.ReadFile(configPath)
	if err != nil {
		return Config{}, fmt.Errorf("read config: %w", err)
	}

	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return Config{}, fmt.Errorf("parse config: %w", err)
	}

	// Apply defaults
	if cfg.DumpDir == "" {
		cfg.DumpDir = "/mnt/dump"
	}
	if cfg.StateDir == "" {
		cfg.StateDir = "/var/lib/dumper"
	}
	if cfg.SSHKeyPath == "" {
		cfg.SSHKeyPath = filepath.Join(cfg.StateDir, "id_ed25519")
	}
	if cfg.MaxStreams == 0 {
		cfg.MaxStreams = 8
	}

	var missing []string
	if cfg.RemoteHost == "" {
		missing = append(missing, "remote_host")
	}
	if cfg.RemoteUser == "" {
		missing = append(missing, "remote_user")
	}
	if cfg.RemotePath == "" {
		missing = append(missing, "remote_path")
	}
	if len(missing) > 0 {
		return Config{}, fmt.Errorf("missing required config fields: %v", missing)
	}

	return cfg, nil
}
