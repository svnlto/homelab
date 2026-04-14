package sync

import (
	"bufio"
	"context"
	"fmt"
	"log/slog"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

type RsyncOpts struct {
	SSHKeyPath string
	RemoteUser string
	RemoteHost string
	RemotePath string
	LocalPath  string
	FilesFrom  string
}

var sshFlags = []string{
	"-o", "StrictHostKeyChecking=no",
	"-o", "UserKnownHostsFile=/dev/null",
	"-o", "ConnectTimeout=30",
	"-o", "ServerAliveInterval=30",
	"-o", "ServerAliveCountMax=10",
	"-o", "Ciphers=aes128-gcm@openssh.com",
	"-o", "IPQoS=throughput",
}

var skipCompressExts = "jpg,jpeg,heic,heif,png,mp4,mov,gif,webp,cr2,nef,arw,dng"

func BuildRsyncArgs(opts RsyncOpts) []string {
	sshCmd := fmt.Sprintf("ssh -i '%s' %s", opts.SSHKeyPath, strings.Join(sshFlags, " "))
	args := []string{
		"-rlt", "--partial", "--inplace", "--omit-dir-times",
		"--skip-compress=" + skipCompressExts,
		"--timeout=300",
		"--chmod=D755,F644",
		"--itemize-changes",
		"--out-format=%i %l %n",
		"--rsync-path=sudo /usr/local/bin/rsync",
		"-e", sshCmd,
	}
	if opts.FilesFrom != "" {
		args = append(args, "--files-from="+opts.FilesFrom)
	}
	remoteSrc := fmt.Sprintf("%s@%s:%s", opts.RemoteUser, opts.RemoteHost, opts.RemotePath)
	args = append(args, remoteSrc, opts.LocalPath)
	return args
}

func BuildDatabaseRsyncArgs(opts RsyncOpts) []string {
	sshCmd := fmt.Sprintf("ssh -i '%s' %s", opts.SSHKeyPath, strings.Join(sshFlags, " "))
	remotePath := strings.TrimRight(opts.RemotePath, "/")
	localPath := strings.TrimRight(opts.LocalPath, "/")
	return []string{
		"-rlt", "--partial", "--inplace", "--omit-dir-times",
		"--stats",
		"--timeout=300",
		"--chmod=D755,F644",
		"--rsync-path=sudo /usr/local/bin/rsync",
		"-e", sshCmd,
		fmt.Sprintf("%s@%s:%s/database/", opts.RemoteUser, opts.RemoteHost, remotePath),
		localPath + "/database/",
	}
}

// ParseTransferLine parses an rsync --out-format="%i %l %n" line.
// Returns whether this is a transfer, the byte count, and the filename.
func ParseTransferLine(line string) (transferred bool, bytes int64, name string) {
	if len(line) == 0 {
		return false, 0, ""
	}
	parts := strings.SplitN(line, " ", 3)
	if len(parts) < 3 {
		return false, 0, ""
	}
	if !strings.HasPrefix(parts[0], ">") {
		return false, 0, ""
	}
	// Size may be unparseable on malformed lines; treat as 0 bytes but still count as transfer.
	n, err := strconv.ParseInt(strings.TrimSpace(parts[1]), 10, 64)
	if err != nil {
		return true, 0, parts[2]
	}
	return true, n, parts[2]
}

type RsyncResult struct {
	Transferred int
	Bytes       int64
	Err         error
}

// RunRsync executes rsync, parses output, and logs progress periodically.
// streamID identifies this stream in log output. streamFiles is the number
// of files assigned to this stream (for percentage calculation).
func RunRsync(ctx context.Context, args []string, streamID int, streamFiles int) RsyncResult {
	cmd := exec.CommandContext(ctx, "rsync", args...)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return RsyncResult{Err: fmt.Errorf("stdout pipe: %w", err)}
	}

	var stderrBuf strings.Builder
	cmd.Stderr = &stderrBuf

	if err := cmd.Start(); err != nil {
		return RsyncResult{Err: fmt.Errorf("start rsync: %w", err)}
	}

	var result RsyncResult
	var checked int
	var lastFile string
	start := time.Now()
	lastLog := start
	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		line := scanner.Text()
		checked++
		xfer, bytes, name := ParseTransferLine(line)
		if xfer {
			result.Transferred++
			result.Bytes += bytes
			lastFile = name
		}

		// Log progress every 30 seconds
		if time.Since(lastLog) >= 30*time.Second {
			elapsed := time.Since(start).Seconds()
			speed := float64(0)
			if elapsed > 0 {
				speed = float64(result.Bytes) / 1048576 / elapsed
			}
			attrs := []any{
				"stream", streamID,
				"transferred", result.Transferred,
				"bytes_mb", fmt.Sprintf("%.1f", float64(result.Bytes)/1048576),
				"speed_mbps", fmt.Sprintf("%.1f", speed),
			}
			if streamFiles > 0 {
				pct := checked * 100 / streamFiles
				attrs = append(attrs, "progress_pct", pct)
			}
			if lastFile != "" {
				attrs = append(attrs, "last_file", lastFile)
			}
			slog.Info("rsync progress", attrs...)
			lastLog = time.Now()
		}
	}

	if err := cmd.Wait(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok && exitErr.ExitCode() == 255 {
			result.Err = fmt.Errorf("connection lost (exit 255)")
		} else {
			stderr := TruncateStderr(stderrBuf.String(), 500)
			if stderr != "" {
				result.Err = fmt.Errorf("%w: %s", err, stderr)
			} else {
				result.Err = err
			}
		}
	}
	return result
}

// TruncateStderr trims stderr to maxLen bytes to avoid flooding logs
// when rsync dumps thousands of per-file errors on connection loss.
func TruncateStderr(s string, maxLen int) string {
	s = strings.TrimSpace(s)
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "... (truncated)"
}

func RunRsyncSimple(ctx context.Context, args []string) (string, error) {
	cmd := exec.CommandContext(ctx, "rsync", args...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}
