package sync

import (
	"log/slog"
)

func SplitFileList(files []string, n int) [][]string {
	if n > len(files) {
		n = len(files)
	}
	if n <= 0 {
		return nil
	}

	chunks := make([][]string, n)
	for i, f := range files {
		chunks[i%n] = append(chunks[i%n], f)
	}
	return chunks
}

type StreamMetrics struct {
	CurrentStreams  int
	MaxStreams      int
	PrevThroughput int64
	CurrThroughput int64
}

type ScaleDecision struct {
	NewStreams int
	Reason    string
}

const minStreams = 1

func DecideStreams(m StreamMetrics) ScaleDecision {
	if m.PrevThroughput == 0 && m.CurrThroughput > 0 {
		newStreams := m.CurrentStreams + 1
		if newStreams > m.MaxStreams {
			newStreams = m.MaxStreams
		}
		d := ScaleDecision{NewStreams: newStreams, Reason: "first measurement, scaling up"}
		slog.Info("stream scaling", "decision", d.Reason, "from", m.CurrentStreams, "to", d.NewStreams)
		return d
	}

	threshold := int64(float64(m.PrevThroughput) * 0.8)
	if m.CurrThroughput < threshold {
		newStreams := m.CurrentStreams - 1
		if newStreams < minStreams {
			newStreams = minStreams
		}
		d := ScaleDecision{NewStreams: newStreams, Reason: "throughput dropped, scaling down"}
		slog.Info("stream scaling", "decision", d.Reason, "from", m.CurrentStreams, "to", d.NewStreams,
			"prev_throughput", m.PrevThroughput, "curr_throughput", m.CurrThroughput)
		return d
	}

	if m.CurrentStreams < m.MaxStreams {
		d := ScaleDecision{NewStreams: m.CurrentStreams + 1, Reason: "throughput steady, scaling up"}
		slog.Info("stream scaling", "decision", d.Reason, "from", m.CurrentStreams, "to", d.NewStreams)
		return d
	}

	d := ScaleDecision{NewStreams: m.CurrentStreams, Reason: "at max streams, holding"}
	slog.Info("stream scaling", "decision", d.Reason, "streams", d.NewStreams)
	return d
}
