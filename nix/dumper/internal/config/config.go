package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	RemoteHost string
	RemoteUser string
	RemotePath string
	SSHKeyPath string
	DumpDir    string
	StateDir   string
	MaxStreams  int
}

func Load() (Config, error) {
	cfg := Config{
		DumpDir:   envOr("DUMP_DIR", "/mnt/dump"),
		StateDir:  envOr("STATE_DIR", "/var/lib/dumper"),
		MaxStreams: envOrInt("MAX_STREAMS", 8),
	}

	var missing []string
	for _, req := range []struct {
		name string
		dest *string
	}{
		{"REMOTE_HOST", &cfg.RemoteHost},
		{"REMOTE_USER", &cfg.RemoteUser},
		{"REMOTE_PATH", &cfg.RemotePath},
		{"SSH_KEY_PATH", &cfg.SSHKeyPath},
	} {
		v := os.Getenv(req.name)
		if v == "" {
			missing = append(missing, req.name)
		}
		*req.dest = v
	}

	if len(missing) > 0 {
		return Config{}, fmt.Errorf("missing required environment variables: %v", missing)
	}
	return cfg, nil
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func envOrInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}
