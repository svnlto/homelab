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

func TestDecideStreams_ScaleUp(t *testing.T) {
	decision := sync.DecideStreams(sync.StreamMetrics{
		CurrentStreams:  2,
		MaxStreams:      8,
		PrevThroughput: 100_000_000,
		CurrThroughput: 95_000_000,
	})
	if decision.NewStreams != 3 {
		t.Errorf("got %d streams, want 3 (scale up)", decision.NewStreams)
	}
}

func TestDecideStreams_ScaleDown(t *testing.T) {
	decision := sync.DecideStreams(sync.StreamMetrics{
		CurrentStreams:  4,
		MaxStreams:      8,
		PrevThroughput: 100_000_000,
		CurrThroughput: 70_000_000,
	})
	if decision.NewStreams != 3 {
		t.Errorf("got %d streams, want 3 (scale down)", decision.NewStreams)
	}
}

func TestDecideStreams_AtMax(t *testing.T) {
	decision := sync.DecideStreams(sync.StreamMetrics{
		CurrentStreams:  8,
		MaxStreams:      8,
		PrevThroughput: 100_000_000,
		CurrThroughput: 95_000_000,
	})
	if decision.NewStreams != 8 {
		t.Errorf("got %d streams, want 8 (hold at max)", decision.NewStreams)
	}
}

func TestDecideStreams_AtMin(t *testing.T) {
	decision := sync.DecideStreams(sync.StreamMetrics{
		CurrentStreams:  1,
		MaxStreams:      8,
		PrevThroughput: 100_000_000,
		CurrThroughput: 50_000_000,
	})
	if decision.NewStreams != 1 {
		t.Errorf("got %d streams, want 1 (hold at min)", decision.NewStreams)
	}
}

func TestDecideStreams_FirstMeasurement(t *testing.T) {
	decision := sync.DecideStreams(sync.StreamMetrics{
		CurrentStreams:  2,
		MaxStreams:      8,
		PrevThroughput: 0,
		CurrThroughput: 50_000_000,
	})
	if decision.NewStreams != 3 {
		t.Errorf("got %d streams, want 3 (scale up from initial)", decision.NewStreams)
	}
}
