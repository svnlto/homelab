package diff

import (
	"log/slog"
	"os"
	"path/filepath"
)

func ComputeMissing(dbOriginals []string, localDir string) ([]string, error) {
	present := make(map[string]struct{})
	originalsDir := filepath.Join(localDir, "originals")

	if info, err := os.Stat(originalsDir); err == nil && info.IsDir() {
		err := filepath.WalkDir(originalsDir, func(path string, d os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() {
				return nil
			}
			rel, err := filepath.Rel(localDir, path)
			if err != nil {
				return err
			}
			present[rel] = struct{}{}
			return nil
		})
		if err != nil {
			return nil, err
		}
	}

	slog.Info("disk scan complete", "present", len(present))

	var missing []string
	for _, orig := range dbOriginals {
		if _, ok := present[orig]; !ok {
			missing = append(missing, orig)
		}
	}

	slog.Info("diff computed",
		"total_in_db", len(dbOriginals),
		"present_on_disk", len(present),
		"missing", len(missing),
	)
	return missing, nil
}
