package support

import (
	"context"
	"fmt"
	"time"
)

// Hours is one opening window: Weekday 0 = Saturday … 6 = Friday, "HH:MM" in the configured timezone.
type Hours struct {
	Weekday int    `json:"weekday"`
	From    string `json:"from"`
	To      string `json:"to"`
}

// Config is the `support.*` part of the remote config.
type Config struct {
	Enabled         bool
	Hours           []Hours
	Timezone        string
	MaxMessageChars int
}

// DefaultConfig mirrors config-data/config/default.json (used when the config cannot be read).
func DefaultConfig() Config {
	h := make([]Hours, 0, 6)
	for w := 0; w <= 5; w++ {
		h = append(h, Hours{Weekday: w, From: "09:00", To: "21:00"})
	}
	return Config{Enabled: true, Hours: h, Timezone: "Asia/Tehran", MaxMessageChars: 2000}
}

// ConfigReader returns the current support config (active base config; kill switch lives here).
type ConfigReader interface {
	Support(ctx context.Context) Config
}

// StaticConfig is a fixed ConfigReader (tests, dev).
type StaticConfig struct{ C Config }

// Support implements ConfigReader.
func (s StaticConfig) Support(context.Context) Config { return s.C }

func parseHM(s string) (int, error) {
	var h, m int
	if _, err := fmt.Sscanf(s, "%d:%d", &h, &m); err != nil || h < 0 || h > 24 || m < 0 || m > 59 {
		return 0, fmt.Errorf("bad time %q", s)
	}
	return h*60 + m, nil
}

// weekdayIndex converts time.Weekday (Sunday=0) to the Saturday-first index used by config.
func weekdayIndex(w time.Weekday) int { return (int(w) + 1) % 7 }

// Status reports whether support is online at [now] and, when it is not, when it opens next
// (nil if no window is configured at all).
func (c Config) Status(now time.Time) (online bool, nextOnline *time.Time) {
	loc, err := time.LoadLocation(c.Timezone)
	if err != nil {
		loc = time.FixedZone("IRST", 3*3600+1800)
	}
	local := now.In(loc)
	for dayOff := 0; dayOff <= 7; dayOff++ {
		d := local.AddDate(0, 0, dayOff)
		for _, h := range c.Hours {
			if h.Weekday != weekdayIndex(d.Weekday()) {
				continue
			}
			from, e1 := parseHM(h.From)
			to, e2 := parseHM(h.To)
			if e1 != nil || e2 != nil {
				continue
			}
			start := time.Date(d.Year(), d.Month(), d.Day(), 0, 0, 0, 0, loc).Add(time.Duration(from) * time.Minute)
			end := time.Date(d.Year(), d.Month(), d.Day(), 0, 0, 0, 0, loc).Add(time.Duration(to) * time.Minute)
			if dayOff == 0 && !now.Before(start) && now.Before(end) {
				return true, nil
			}
			if start.After(now) && (nextOnline == nil || start.Before(*nextOnline)) {
				s := start
				nextOnline = &s
			}
		}
		if nextOnline != nil {
			break
		}
	}
	return false, nextOnline
}
