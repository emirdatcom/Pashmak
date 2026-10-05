package billing

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
)

type seedFile struct {
	Products []struct {
		ID           string            `json:"id"`
		Kind         string            `json:"kind"`
		Entitlement  string            `json:"entitlement"`
		DurationDays int32             `json:"duration_days"`
		CoinsAmount  int32             `json:"coins_amount"`
		MarketSKU    map[string]string `json:"market_sku"`
	} `json:"products"`
}

// SeedProducts upserts products from config-data/products.json content. It returns the row count.
func SeedProducts(ctx context.Context, db dbgen.DBTX, data []byte) (int, error) {
	var f seedFile
	if err := json.Unmarshal(data, &f); err != nil {
		return 0, fmt.Errorf("parse products: %w", err)
	}
	q := dbgen.New(db)
	n := 0
	for _, p := range f.Products {
		for market, sku := range p.MarketSKU {
			arg := dbgen.UpsertProductParams{ID: p.ID, Market: market, Kind: p.Kind, MarketSku: sku, Active: true}
			if p.Entitlement != "" {
				arg.Entitlement = &p.Entitlement
			}
			if p.DurationDays > 0 {
				d := p.DurationDays
				arg.DurationDays = &d
			}
			if p.CoinsAmount > 0 {
				c := p.CoinsAmount
				arg.CoinsAmount = &c
			}
			if err := q.UpsertProduct(ctx, arg); err != nil {
				return n, fmt.Errorf("upsert %s/%s: %w", p.ID, market, err)
			}
			n++
		}
	}
	return n, nil
}

// OnUserMerged implements auth.MergeHook: purchases (and the grants they created) move to the
// surviving account; trial grants stay with the retired one (docs/10 §7, prompt 05).
func (s *Service) OnUserMerged(ctx context.Context, q *dbgen.Queries, from, to uuid.UUID) error {
	if err := q.TransferUserPurchases(ctx, dbgen.TransferUserPurchasesParams{UserID: from, UserID_2: to}); err != nil {
		return fmt.Errorf("transfer purchases: %w", err)
	}
	if err := q.TransferPurchaseGrants(ctx, dbgen.TransferPurchaseGrantsParams{UserID: from, UserID_2: to}); err != nil {
		return fmt.Errorf("transfer grants: %w", err)
	}
	return nil
}
