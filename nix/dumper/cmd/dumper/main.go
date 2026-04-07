package main

import (
	"log/slog"
	"os"

	"github.com/svnlto/dumper/internal/config"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	cfg, err := config.Load()
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	slog.Info("dumper starting",
		"remote_host", cfg.RemoteHost,
		"dump_dir", cfg.DumpDir,
		"max_streams", cfg.MaxStreams,
	)

	slog.Info("dumper finished")
}
