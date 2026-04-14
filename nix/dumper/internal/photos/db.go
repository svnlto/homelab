package photos

import (
	"database/sql"
	"fmt"
	"log/slog"

	_ "modernc.org/sqlite"
)

func QueryOriginals(dbPath string) ([]string, error) {
	db, err := sql.Open("sqlite", dbPath+"?mode=ro")
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}
	defer db.Close()

	rows, err := db.Query(`
		SELECT 'originals/' || ZDIRECTORY || '/' || ZFILENAME
		FROM ZASSET
		WHERE ZTRASHEDSTATE = 0
		  AND ZDIRECTORY IS NOT NULL
		  AND ZFILENAME IS NOT NULL
		ORDER BY ZDIRECTORY, ZFILENAME
	`)
	if err != nil {
		return nil, fmt.Errorf("query originals: %w", err)
	}
	defer rows.Close()

	var originals []string
	for rows.Next() {
		var path string
		if err := rows.Scan(&path); err != nil {
			return nil, fmt.Errorf("scan row: %w", err)
		}
		originals = append(originals, path)
	}
	slog.Info("queried originals", "count", len(originals))
	return originals, rows.Err()
}

func CheckIntegrity(dbPath string) error {
	db, err := sql.Open("sqlite", dbPath+"?mode=ro")
	if err != nil {
		return fmt.Errorf("open db: %w", err)
	}
	defer db.Close()

	var result string
	if err := db.QueryRow("PRAGMA integrity_check;").Scan(&result); err != nil {
		return fmt.Errorf("integrity check: %w", err)
	}
	if result != "ok" {
		return fmt.Errorf("integrity check failed: %s", result)
	}
	slog.Info("integrity check passed", "db", dbPath)
	return nil
}

func CheckpointWAL(dbPath string) error {
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return fmt.Errorf("open db: %w", err)
	}
	defer db.Close()

	_, err = db.Exec("PRAGMA wal_checkpoint(TRUNCATE);")
	if err != nil {
		return fmt.Errorf("wal checkpoint: %w", err)
	}
	slog.Info("WAL checkpoint complete", "db", dbPath)
	return nil
}
