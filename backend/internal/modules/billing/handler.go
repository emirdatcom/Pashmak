package billing

import (
	"net/http"

	"github.com/emirdatcom/pashmak/backend/internal/modules/entitlement"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// Register mounts /v1/purchases/*; verify is limited to 30 per hour per user (docs/10 §12).
func Register(r *httpx.Router, s *Service, requireAuth httpx.Middleware, clk clock.Clock) {
	limit := httpx.RateLimitUser(httpx.NewRateLimiter(clk, 30, 30))
	r.HandleFunc("POST /v1/purchases/verify", s.handleVerify, requireAuth, limit)
	r.HandleFunc("POST /v1/purchases/restore", s.handleRestore, requireAuth, limit)
}

type verifyResponse struct {
	PurchaseID       string            `json:"purchase_id"`
	PurchaseState    string            `json:"purchase_state"`
	EntitlementState entitlement.State `json:"entitlement_state"`
	CoinsGranted     int               `json:"coins_granted"`
}

func (s *Service) handleVerify(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
		return
	}
	var in PurchaseInput
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	out, st, err := s.Verify(r.Context(), p, in)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, verifyResponse{PurchaseID: out.PurchaseID.String(),
		PurchaseState: out.PurchaseState, EntitlementState: st, CoinsGranted: out.CoinsGranted})
}

func (s *Service) handleRestore(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
		return
	}
	var in struct {
		Market    string `json:"market"`
		Purchases []struct {
			ProductID     string `json:"product_id"`
			MarketSKU     string `json:"market_sku"`
			PurchaseToken string `json:"purchase_token"`
			OrderID       string `json:"order_id"`
		} `json:"purchases"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	items := make([]PurchaseInput, 0, len(in.Purchases))
	for _, it := range in.Purchases {
		items = append(items, PurchaseInput{Market: in.Market, ProductID: it.ProductID, MarketSKU: it.MarketSKU,
			PurchaseToken: it.PurchaseToken, OrderID: it.OrderID})
	}
	st, err := s.Restore(r.Context(), p, in.Market, items)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, st)
}
