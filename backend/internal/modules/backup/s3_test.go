package backup

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// AWS's documented Signature V4 example ("GET Object" with a Range header) pins the signer.
func TestSignV4AWSVector(t *testing.T) {
	got := signV4("GET", "/test.txt", "", map[string]string{
		"host":                 "examplebucket.s3.amazonaws.com",
		"range":                "bytes=0-9",
		"x-amz-content-sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		"x-amz-date":           "20130524T000000Z",
	}, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "us-east-1", "s3",
		"AKIAIOSFODNN7EXAMPLE", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY", time.Date(2013, 5, 24, 0, 0, 0, 0, time.UTC))
	want := "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, " +
		"SignedHeaders=host;range;x-amz-content-sha256;x-amz-date, " +
		"Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41"
	if got != want {
		t.Fatalf("\n got %s\nwant %s", got, want)
	}
}

func TestS3ClientAgainstFakeServer(t *testing.T) {
	store := map[string][]byte{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.Header.Get("Authorization"), "AWS4-HMAC-SHA256 Credential=AK/") || r.Header.Get("x-amz-date") == "" {
			w.WriteHeader(403)
			return
		}
		switch r.Method {
		case http.MethodPut:
			b, _ := io.ReadAll(r.Body)
			store[r.URL.Path] = b
		case http.MethodGet:
			b, ok := store[r.URL.Path]
			if !ok {
				w.WriteHeader(404)
				return
			}
			_, _ = w.Write(b)
		case http.MethodDelete:
			delete(store, r.URL.Path)
			w.WriteHeader(204)
		}
	}))
	defer srv.Close()
	s := &S3{Endpoint: srv.URL, Region: "r", Bucket: "b", AccessKey: "AK", SecretKey: "SK"}
	ctx := context.Background()
	if err := s.Put(ctx, "u/1", []byte("blob")); err != nil {
		t.Fatal(err)
	}
	if got, err := s.Get(ctx, "u/1"); err != nil || string(got) != "blob" {
		t.Fatalf("%q %v", got, err)
	}
	if err := s.Delete(ctx, "u/1"); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Get(ctx, "u/1"); err != ErrNotFound {
		t.Fatalf("want ErrNotFound, got %v", err)
	}
	if err := s.Delete(ctx, "u/1"); err != nil {
		t.Fatalf("deleting a missing object is fine: %v", err)
	}
}
