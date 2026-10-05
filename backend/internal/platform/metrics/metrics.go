// Package metrics exposes Prometheus collectors.
package metrics

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Metrics bundles the shared collectors.
type Metrics struct {
	Registry     *prometheus.Registry
	HTTPRequests *prometheus.CounterVec
	HTTPDuration *prometheus.HistogramVec
}

// DBStats is the subset of pool statistics we export.
type DBStats interface {
	AcquiredConns() int32
	IdleConns() int32
	TotalConns() int32
	MaxConns() int32
}

// New creates a registry with the base collectors.
func New() *Metrics {
	reg := prometheus.NewRegistry()
	m := &Metrics{
		Registry: reg,
		HTTPRequests: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "http_requests_total", Help: "HTTP requests by route and status.",
		}, []string{"route", "status"}),
		HTTPDuration: prometheus.NewHistogramVec(prometheus.HistogramOpts{
			Name: "http_request_duration_seconds", Help: "HTTP request latency.",
			Buckets: prometheus.DefBuckets,
		}, []string{"route"}),
	}
	reg.MustRegister(m.HTTPRequests, m.HTTPDuration)
	return m
}

// RegisterDBPool exports db_pool_* gauges backed by stats().
func (m *Metrics) RegisterDBPool(stats func() DBStats) {
	g := func(name, help string, f func(DBStats) float64) {
		m.Registry.MustRegister(prometheus.NewGaugeFunc(prometheus.GaugeOpts{Name: name, Help: help},
			func() float64 { return f(stats()) }))
	}
	g("db_pool_acquired_conns", "Acquired connections.", func(s DBStats) float64 { return float64(s.AcquiredConns()) })
	g("db_pool_idle_conns", "Idle connections.", func(s DBStats) float64 { return float64(s.IdleConns()) })
	g("db_pool_total_conns", "Total connections.", func(s DBStats) float64 { return float64(s.TotalConns()) })
	g("db_pool_max_conns", "Max connections.", func(s DBStats) float64 { return float64(s.MaxConns()) })
}

// Handler serves /metrics.
func (m *Metrics) Handler() http.Handler {
	return promhttp.HandlerFor(m.Registry, promhttp.HandlerOpts{})
}
