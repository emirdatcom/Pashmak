// Package metrics exposes Prometheus collectors.
package metrics

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Metrics bundles the shared collectors.
type Metrics struct {
	Registry       *prometheus.Registry
	HTTPRequests   *prometheus.CounterVec
	HTTPDuration   *prometheus.HistogramVec
	MarketVerify   *prometheus.CounterVec
	EventsIngested prometheus.Counter
	EventsRejected *prometheus.CounterVec

	SupportFirstResponse prometheus.Histogram
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
	m.MarketVerify = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "market_verify_total", Help: "Market purchase verifications by market and result.",
	}, []string{"market", "result"})
	m.EventsIngested = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "events_ingested_total", Help: "Analytics events accepted."})
	m.EventsRejected = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "events_rejected_total", Help: "Analytics events rejected by reason."}, []string{"reason"})
	m.SupportFirstResponse = prometheus.NewHistogram(prometheus.HistogramOpts{
		Name: "support_first_response_seconds", Help: "Time from a user's message to the first operator reply.",
		Buckets: []float64{30, 60, 120, 300, 600, 1800, 3600, 4 * 3600, 12 * 3600, 24 * 3600}})
	reg.MustRegister(m.SupportFirstResponse)
	reg.MustRegister(m.HTTPRequests, m.HTTPDuration, m.MarketVerify, m.EventsIngested, m.EventsRejected)
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

// RegisterGauge exports a gauge computed on every scrape (support queue depth etc.).
func (m *Metrics) RegisterGauge(name, help string, f func() float64) {
	m.Registry.MustRegister(prometheus.NewGaugeFunc(prometheus.GaugeOpts{Name: name, Help: help}, f))
}
