package appver

import "testing"

func TestCompare(t *testing.T) {
	cases := []struct {
		a, b string
		want int
	}{{"1.0.0", "1.0.0", 0}, {"1.2", "1.2.0", 0}, {"1.10.0", "1.9.9", 1}, {"0.9.9", "1.0.0", -1}, {"1.2.3+45", "1.2.3", 0}}
	for _, c := range cases {
		if got := Compare(c.a, c.b); got != c.want {
			t.Errorf("Compare(%q,%q)=%d want %d", c.a, c.b, got, c.want)
		}
	}
	if !AtLeast("1.0.0", "") || AtLeast("", "1.0.0") || AtLeast("x", "1.0.0") || !AtLeast("2.0.0", "1.9.0") {
		t.Fatal("AtLeast")
	}
}
