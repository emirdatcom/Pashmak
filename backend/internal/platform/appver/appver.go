// Package appver compares dotted app versions such as "1.2.3".
package appver

import (
	"strconv"
	"strings"
)

// Parse converts "1.2.3" (up to 3 numeric parts; missing parts are 0) into a comparable triple.
func Parse(v string) ([3]int, bool) {
	var out [3]int
	v = strings.TrimSpace(v)
	if v == "" {
		return out, false
	}
	// ignore build suffixes such as "1.2.3+45" or "1.2.3-beta"
	if i := strings.IndexAny(v, "+-"); i >= 0 {
		v = v[:i]
	}
	parts := strings.Split(v, ".")
	if len(parts) > 3 {
		return out, false
	}
	for i, p := range parts {
		n, err := strconv.Atoi(p)
		if err != nil || n < 0 {
			return out, false
		}
		out[i] = n
	}
	return out, true
}

// Compare returns -1, 0 or 1. Unparseable versions compare as 0.0.0.
func Compare(a, b string) int {
	x, _ := Parse(a)
	y, _ := Parse(b)
	for i := 0; i < 3; i++ {
		switch {
		case x[i] < y[i]:
			return -1
		case x[i] > y[i]:
			return 1
		}
	}
	return 0
}

// AtLeast reports whether v >= minVersion. An empty minVersion always passes; an empty/invalid v only passes an empty minVersion.
func AtLeast(v, minVersion string) bool {
	if strings.TrimSpace(minVersion) == "" {
		return true
	}
	if _, ok := Parse(v); !ok {
		return false
	}
	return Compare(v, minVersion) >= 0
}
