package bazaar

import (
	"net/http"
	"testing"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/modules/billing"
)

// The JSON samples follow the documented Bazaar response shape as remembered by the author;
// they are NOT recorded from the live API (V1: [نیاز به راستی‌آزمایی]). Replace with recorded
// responses before enabling BILLING_BAZAAR_ENABLED in prod.
func TestParseResponse(t *testing.T) {
	t.Run("inapp purchased", func(t *testing.T) {
		mp, err := ParseResponse(200, []byte(`{"consumptionState":0,"purchaseState":0,"kind":"androidpublisher#inappPurchase","developerPayload":"","purchaseTime":1790000000000}`), false)
		if err != nil || mp.State != billing.MarketValid || !mp.PurchasedAt.Equal(time.UnixMilli(1790000000000).UTC()) {
			t.Fatalf("%+v %v", mp, err)
		}
	})
	t.Run("inapp refunded", func(t *testing.T) {
		mp, _ := ParseResponse(200, []byte(`{"purchaseState":1,"purchaseTime":1790000000000}`), false)
		if mp.State != billing.MarketRefunded {
			t.Fatalf("%+v", mp)
		}
	})
	t.Run("subscription", func(t *testing.T) {
		mp, err := ParseResponse(200, []byte(`{"autoRenewing":true,"initiationTimestampMsec":1790000000000,"validUntilTimestampMsec":1792592000000}`), true)
		if err != nil || !mp.AutoRenewing || !mp.ExpiresAt.Equal(time.UnixMilli(1792592000000).UTC()) {
			t.Fatalf("%+v %v", mp, err)
		}
	})
	t.Run("not found is invalid", func(t *testing.T) {
		mp, err := ParseResponse(http.StatusNotFound, []byte(`{"error":"not_found"}`), false)
		if err != nil || mp.State != billing.MarketInvalid {
			t.Fatalf("%+v %v", mp, err)
		}
	})
	t.Run("server errors are transient", func(t *testing.T) {
		for _, st := range []int{500, 502, 429, 401} {
			if _, err := ParseResponse(st, nil, false); err == nil {
				t.Fatalf("status %d must be an error", st)
			}
		}
		if _, err := ParseResponse(200, []byte(`not json`), false); err == nil {
			t.Fatal("garbage must be an error")
		}
	})
}
