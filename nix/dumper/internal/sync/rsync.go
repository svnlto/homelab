package sync

import (
	"bufio"
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
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
	"-o", "StrictHostKeyChecking=accept-new",
	"-o", "UserKnownHostsFile=/dev/null",
	"-o", "ConnectTimeout=30",
	"-o", "ServerAliveInterval=30",
	"-o", "ServerAliveCountMax=10",
	"-o", "Ciphers=aes128-gcm@openssh.com",
	"-o", "IPQoS=throughput",
}

var skipCompressExts = "jpg,jpeg,heic,heif,png,mp4,mov,gif,webp,cr2,nef,arw,dng"

func BuildRsyncArgs(opts RsyncOpts) []string {
	sshCmd := fmt.Sprintf("ssh -i %s %s", opts.SSHKeyPath, strings.Join(sshFlags, " "))
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
	sshCmd := fmt.Sprintf("ssh -i %s %s", opts.SSHKeyPath, strings.Join(sshFlags, " "))
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

func ParseTransferLine(line string) (transferred bool, bytes int64) {
	if len(line) == 0 {
		return false, 0
	}
	parts := strings.SplitN(line, " ", 3)
	if len(parts) < 3 {
		return false, 0
	}
	if !strings.HasPrefix(parts[0], ">") {
		return false, 0
	}
	n, err := strconv.ParseInt(strings.TrimSpace(parts[1]), 10, 64)
	if err != nil {
		return true, 0
	}
	return true, n
}

type RsyncResult struct {
	Checked     int
	Transferred int
	Bytes       int64
	Err         error
}

func RunRsync(ctx context.Context, args []string) RsyncResult {
	cmd := exec.CommandContext(ctx, "rsync", args...)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return RsyncResult{Err: fmt.Errorf("stdout pipe: %w", err)}
	}

	if err := cmd.Start(); err != nil {
		return RsyncResult{Err: fmt.Errorf("start rsync: %w", err)}
	}

	var result RsyncResult
	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		line := scanner.Text()
		result.Checked++
		xfer, bytes := ParseTransferLine(line)
		if xfer {
			result.Transferred++
			result.Bytes += bytes
		}
	}

	if err := cmd.Wait(); err != nil {
		result.Err = err
	}
	return result
}

func RunRsyncSimple(ctx context.Context, args []string) (string, error) {
	cmd := exec.CommandContext(ctx, "rsync", args...)
	out, err := cmd.CombinedOutput()
	return string(out), err
}
