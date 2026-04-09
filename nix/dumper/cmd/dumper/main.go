package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"time"

	"github.com/svnlto/dumper/internal/config"
	"github.com/svnlto/dumper/internal/diff"
	"github.com/svnlto/dumper/internal/photos"
	"github.com/svnlto/dumper/internal/sync"
	"github.com/svnlto/dumper/internal/tailscale"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	configPath := ""
	if len(os.Args) > 1 {
		configPath = os.Args[1]
	}

	cfg, err := config.Load(configPath)
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()

	slog.Info("dumper starting",
		"remote_host", cfg.RemoteHost,
		"dump_dir", cfg.DumpDir,
		"max_streams", cfg.MaxStreams,
		"sync_interval", cfg.SyncInterval,
		"retry_interval", cfg.RetryInterval,
	)

	for {
		err := runSync(ctx, cfg)
		if err != nil {
			slog.Error("sync failed, retrying",
				"error", err,
				"retry_in", cfg.RetryInterval,
			)
			if !sleep(ctx, time.Duration(cfg.RetryInterval)*time.Second) {
				break
			}
			continue
		}

		slog.Info("sync complete, next sync",
			"next_in", cfg.SyncInterval,
		)
		if !sleep(ctx, time.Duration(cfg.SyncInterval)*time.Second) {
			break
		}
	}

	slog.Info("dumper shutting down")
}

// sleep returns false if the context was cancelled during the wait.
func sleep(ctx context.Context, d time.Duration) bool {
	timer := time.NewTimer(d)
	defer timer.Stop()
	select {
	case <-timer.C:
		return true
	case <-ctx.Done():
		return false
	}
}

func runSync(ctx context.Context, cfg config.Config) error {
	// Phase 1: Tailscale connectivity
	slog.Info("phase 1: checking tailscale connectivity")
	if err := tailscale.CheckConnected(ctx, cfg.RemoteHost); err != nil {
		return fmt.Errorf("tailscale check: %w", err)
	}

	// Derive local library path: DUMP_DIR + REMOTE_PATH
	remotePath := strings.TrimRight(cfg.RemotePath, "/") + "/"
	localLib := filepath.Join(cfg.DumpDir, remotePath)

	rsyncOpts := sync.RsyncOpts{
		SSHKeyPath: cfg.SSHKeyPath,
		RemoteUser: cfg.RemoteUser,
		RemoteHost: cfg.RemoteHost,
		RemotePath: remotePath,
		LocalPath:  localLib,
	}

	// Phase 2: Database sync
	slog.Info("phase 2: syncing database")
	dbArgs := sync.BuildDatabaseRsyncArgs(rsyncOpts)
	output, err := sync.RunRsyncSimple(ctx, dbArgs)
	if err != nil {
		return fmt.Errorf("database sync failed: %w\noutput: %s", err, output)
	}
	slog.Info("database sync complete")

	// SQLite integrity check + WAL checkpoint
	dbPath := filepath.Join(localLib, "database", "Photos.sqlite")
	if err := photos.CheckIntegrity(dbPath); err != nil {
		return fmt.Errorf("database integrity check: %w", err)
	}
	if err := photos.CheckpointWAL(dbPath); err != nil {
		slog.Warn("WAL checkpoint failed", "error", err)
	}

	// Phase 3: Diff computation
	slog.Info("phase 3: computing diff")
	originals, err := photos.QueryOriginals(dbPath)
	if err != nil {
		return fmt.Errorf("query originals: %w", err)
	}

	missing, err := diff.ComputeMissing(originals, localLib)
	if err != nil {
		return fmt.Errorf("compute missing: %w", err)
	}

	if len(missing) == 0 {
		slog.Info("all originals present, nothing to sync")
		return nil
	}

	slog.Info("phase 4: syncing missing originals",
		"missing", len(missing),
		"total", len(originals),
	)

	// Phase 4: Parallel rsync
	return runParallelSync(ctx, cfg, rsyncOpts, missing)
}

func runParallelSync(ctx context.Context, cfg config.Config, opts sync.RsyncOpts, missing []string) error {
	streams := cfg.MaxStreams
	if streams > len(missing) {
		streams = len(missing)
	}

	start := time.Now()
	chunks := sync.SplitFileList(missing, streams)

	// Write file lists to state dir
	var fileListPaths []string
	for i, chunk := range chunks {
		listPath := filepath.Join(cfg.StateDir, fmt.Sprintf("chunk-%d.txt", i))
		if err := writeFileList(listPath, chunk); err != nil {
			return fmt.Errorf("write chunk file list: %w", err)
		}
		fileListPaths = append(fileListPaths, listPath)
	}
	defer func() {
		for _, p := range fileListPaths {
			os.Remove(p)
		}
	}()

	// Launch rsync streams
	type streamResult struct {
		result sync.RsyncResult
		index  int
	}
	results := make(chan streamResult, len(chunks))

	for i, listPath := range fileListPaths {
		streamOpts := opts
		streamOpts.FilesFrom = listPath
		chunkSize := len(chunks[i])
		go func(idx int, o sync.RsyncOpts, nFiles int) {
			r := sync.RunRsync(ctx, sync.BuildRsyncArgs(o), idx, nFiles)
			results <- streamResult{result: r, index: idx}
		}(i, streamOpts, chunkSize)

		// Stagger stream starts
		if i < len(fileListPaths)-1 {
			if !sleep(ctx, 2*time.Second) {
				break
			}
		}
	}

	// Collect results
	var totalTransferred int
	var totalBytes int64
	var windowErrors int
	for range chunks {
		sr := <-results
		totalTransferred += sr.result.Transferred
		totalBytes += sr.result.Bytes
		if sr.result.Err != nil {
			windowErrors++
			slog.Warn("rsync stream error", "stream", sr.index, "error", sr.result.Err)
		}
	}

	totalDuration := time.Since(start)
	avgSpeed := float64(0)
	if totalDuration.Seconds() > 0 {
		avgSpeed = float64(totalBytes) / 1048576 / totalDuration.Seconds()
	}

	slog.Info("sync complete",
		"transferred", totalTransferred,
		"bytes", totalBytes,
		"duration", totalDuration.Round(time.Second),
		"avg_mbps", fmt.Sprintf("%.1f", avgSpeed),
		"streams", streams,
	)

	if windowErrors > 0 {
		return fmt.Errorf("%d rsync streams failed", windowErrors)
	}
	return nil
}

func writeFileList(path string, files []string) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	for _, file := range files {
		if _, err := fmt.Fprintln(f, file); err != nil {
			f.Close()
			return err
		}
	}
	return f.Close()
}
