// Package telemetry configures OpenTelemetry tracing for dumper. Tracing is
// best-effort: an unreachable collector must never crash the sync loop.
package telemetry

import (
	"context"
	"fmt"
	"os"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.41.0"
	"go.opentelemetry.io/otel/trace"
)

const defaultEndpoint = "http://localhost:4318"

// InitTracer sets up a global TracerProvider that batches spans to the
// node-local OTel collector over OTLP/HTTP. The returned shutdown func
// flushes buffered spans and stops the provider; callers should defer it.
func InitTracer(ctx context.Context) (func(context.Context) error, error) {
	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		endpoint = defaultEndpoint
	}

	exporter, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpointURL(endpoint),
		otlptracehttp.WithInsecure(),
	)
	if err != nil {
		return nil, fmt.Errorf("create otlp exporter: %w", err)
	}

	hostname, err := os.Hostname()
	if err != nil {
		hostname = "unknown"
	}

	res, err := resource.Merge(resource.Default(), resource.NewSchemaless(
		semconv.ServiceName("dumper"),
		semconv.HostName(hostname),
	))
	if err != nil {
		return nil, fmt.Errorf("build resource: %w", err)
	}

	// BatchSpanProcessor exports in the background; a dead collector just
	// means dropped batches after export timeouts, never a blocked caller.
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)

	return tp.Shutdown, nil
}

// End closes span, recording err on it when non-nil. Call via defer with a
// named return so the final error value is captured:
//
//	ctx, span := tracer.Start(ctx, "phase")
//	defer func() { telemetry.End(span, err) }()
func End(span trace.Span, err error) {
	if err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
	} else {
		span.SetStatus(codes.Ok, "")
	}
	span.End()
}
