package sync_test

import (
	"testing"

	"github.com/svnlto/dumper/internal/sync"
)

func TestSplitFileList(t *testing.T) {
	files := []string{"a", "b", "c", "d", "e", "f", "g"}

	chunks := sync.SplitFileList(files, 3)
	if len(chunks) != 3 {
		t.Fatalf("got %d chunks, want 3", len(chunks))
	}

	total := 0
	for _, c := range chunks {
		total += len(c)
	}
	if total != 7 {
		t.Errorf("got %d total files across chunks, want 7", total)
	}
}

func TestSplitFileList_MoreChunksThanFiles(t *testing.T) {
	files := []string{"a", "b"}
	chunks := sync.SplitFileList(files, 5)
	if len(chunks) != 2 {
		t.Errorf("got %d chunks, want 2 (capped to file count)", len(chunks))
	}
}

func TestSplitFileList_ZeroChunks(t *testing.T) {
	files := []string{"a", "b"}
	chunks := sync.SplitFileList(files, 0)
	if chunks != nil {
		t.Errorf("got %v, want nil for 0 chunks", chunks)
	}
}

func TestSplitFileList_EmptyFiles(t *testing.T) {
	chunks := sync.SplitFileList(nil, 3)
	if chunks != nil {
		t.Errorf("got %v, want nil for empty file list", chunks)
	}
}
