package httpx

import "net/http"

// Router wraps http.ServeMux (Go 1.22+ patterns, e.g. "GET /v1/me").
type Router struct {
	mux *http.ServeMux
}

// NewRouter creates a router with JSON 404/405 handling.
func NewRouter() *Router {
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		WriteError(w, r, CodeNotFound, "not found")
	})
	return &Router{mux: mux}
}

// Handle registers a handler for a method+path pattern.
func (r *Router) Handle(pattern string, h http.Handler, mw ...Middleware) {
	r.mux.Handle(pattern, Chain(h, mw...))
}

// HandleFunc is Handle for a function.
func (r *Router) HandleFunc(pattern string, h http.HandlerFunc, mw ...Middleware) {
	r.Handle(pattern, h, mw...)
}

// ServeHTTP implements http.Handler.
func (r *Router) ServeHTTP(w http.ResponseWriter, req *http.Request) { r.mux.ServeHTTP(w, req) }
