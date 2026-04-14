package sync

// SplitFileList distributes files across n chunks using round-robin.
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
