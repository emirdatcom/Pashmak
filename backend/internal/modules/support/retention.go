package support

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
)

// RetentionMonths is how long a closed conversation is kept (docs/80 §4).
const RetentionMonths = 12

// Prune deletes conversations that were closed more than RetentionMonths ago (messages cascade).
func (s *Service) Prune(ctx context.Context) error {
	cutoff := s.clk.Now().AddDate(0, -RetentionMonths, 0)
	n, err := dbgen.New(s.pool).DeleteClosedConversationsBefore(ctx, &cutoff)
	if err != nil {
		return fmt.Errorf("prune support: %w", err)
	}
	if n > 0 {
		slog.Info("support conversations pruned", "count", n)
	}
	return nil
}
