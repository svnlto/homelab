package tailscale

import (
	"context"
	"log/slog"
	"os/exec"
	"strings"
)

func ParseStatusOutput(output string, exitCode int) bool {
	return exitCode == 0 && strings.TrimSpace(output) != ""
}

// ParsePingOutput returns true if the output contains "pong".
// tailscale ping exits 1 for peer-relayed connections even with a successful pong,
// so we only check the output, not the exit code.
func ParsePingOutput(output string, exitCode int) bool {
	return strings.Contains(output, "pong from")
}

func CheckConnected(ctx context.Context, remoteHost string) error {
	out, err := exec.CommandContext(ctx, "tailscale", "status").CombinedOutput()
	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			return err
		}
	}
	if !ParseStatusOutput(string(out), exitCode) {
		return &ConnError{msg: "tailscale is not connected"}
	}
	slog.Info("tailscale connected")

	out, err = exec.CommandContext(ctx, "tailscale", "ping", "--timeout=30s", "--c=1", remoteHost).CombinedOutput()
	exitCode = 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			return err
		}
	}
	if !ParsePingOutput(string(out), exitCode) {
		return &ConnError{msg: "remote host " + remoteHost + " unreachable"}
	}
	slog.Info("remote host reachable", "host", remoteHost, "ping", strings.TrimSpace(string(out)))
	return nil
}

type ConnError struct{ msg string }

func (e *ConnError) Error() string { return e.msg }
