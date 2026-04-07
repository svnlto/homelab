package tailscale_test

import (
	"testing"

	"github.com/svnlto/dumper/internal/tailscale"
)

func TestParseStatus_Connected(t *testing.T) {
	ok := tailscale.ParseStatusOutput("100.64.0.1 myhost   linux  -\n", 0)
	if !ok {
		t.Error("expected connected, got disconnected")
	}
}

func TestParseStatus_NotConnected(t *testing.T) {
	ok := tailscale.ParseStatusOutput("", 1)
	if ok {
		t.Error("expected disconnected, got connected")
	}
}

func TestParsePing_Pong(t *testing.T) {
	output := `pong from myhost (100.64.0.1) via DERP(sin) in 45ms`
	ok := tailscale.ParsePingOutput(output, 0)
	if !ok {
		t.Error("expected pong, got no pong")
	}
}

func TestParsePing_NoPong(t *testing.T) {
	ok := tailscale.ParsePingOutput("timeout waiting for pong", 1)
	if ok {
		t.Error("expected no pong, got pong")
	}
}
