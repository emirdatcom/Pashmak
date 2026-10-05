package auth

import "testing"

func TestNormalizePhone(t *testing.T) {
	ok := map[string]string{
		"09121234567":           "+989121234567",
		"9121234567":            "+989121234567",
		"+989121234567":         "+989121234567",
		"989121234567":          "+989121234567",
		"00989121234567":        "+989121234567",
		"۰۹۱۲۱۲۳۴۵۶۷":           "+989121234567", // Persian digits
		"٠٩١٢١٢٣٤٥٦٧":           "+989121234567", // Arabic-Indic digits
		"0912 123 4567":         "+989121234567",
		"0912-123-4567":         "+989121234567",
		" +98 (912) 123 45 67 ": "+989121234567",
		"۰۹۳۵۱۲۳۴۵۶۷":           "+989351234567",
	}
	for in, want := range ok {
		got, err := NormalizePhone(in)
		if err != nil || got != want {
			t.Errorf("NormalizePhone(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	bad := []string{"", "abc", "0912123456", "091212345678", "02112345678", "+14155550123", "0812345678", "09121234567x", "1+9121234567", "+98+9121234567"}
	for _, in := range bad {
		if got, err := NormalizePhone(in); err == nil {
			t.Errorf("NormalizePhone(%q) = %q; want error", in, got)
		}
	}
}

func TestMaskPhone(t *testing.T) {
	if got := MaskPhone("+989121234567"); got != "+98****4567" {
		t.Fatal(got)
	}
	if MaskPhone("") != "****" {
		t.Fatal("short input")
	}
}
