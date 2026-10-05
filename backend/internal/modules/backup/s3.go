package backup

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"
)

// S3 is a minimal S3-compatible client (path-style, AWS Signature V4) for PUT/GET/DELETE object.
// [نیاز به راستی‌آزمایی] V8: the signer is verified against AWS's published SigV4 test vector, but
// no Iranian provider (e.g. ArvanCloud) was reachable from the build environment.
type S3 struct {
	Endpoint  string // e.g. https://s3.example.ir
	Region    string
	Bucket    string
	AccessKey string
	SecretKey string
	HTTP      *http.Client
	Now       func() time.Time
}

func (s *S3) client() *http.Client {
	if s.HTTP != nil {
		return s.HTTP
	}
	return &http.Client{Timeout: 60 * time.Second}
}

func (s *S3) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

func sha256Hex(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

func hmacSHA256(key []byte, data string) []byte {
	m := hmac.New(sha256.New, key)
	_, _ = m.Write([]byte(data))
	return m.Sum(nil)
}

// signV4 returns the Authorization header value. headers must be lower-cased and contain every
// header to sign (host, x-amz-content-sha256, x-amz-date, ...). canonicalURI must already be URI-encoded.
func signV4(method, canonicalURI, canonicalQuery string, headers map[string]string, payloadHash, region, service, accessKey, secretKey string, t time.Time) string {
	t = t.UTC()
	amzDate := t.Format("20060102T150405Z")
	day := t.Format("20060102")
	names := make([]string, 0, len(headers))
	for k := range headers {
		names = append(names, k)
	}
	sort.Strings(names)
	var canonHeaders strings.Builder
	for _, k := range names {
		canonHeaders.WriteString(k + ":" + strings.TrimSpace(headers[k]) + "\n")
	}
	signed := strings.Join(names, ";")
	canonical := strings.Join([]string{method, canonicalURI, canonicalQuery, canonHeaders.String(), signed, payloadHash}, "\n")
	scope := day + "/" + region + "/" + service + "/aws4_request"
	toSign := "AWS4-HMAC-SHA256\n" + amzDate + "\n" + scope + "\n" + sha256Hex([]byte(canonical))
	k := hmacSHA256([]byte("AWS4"+secretKey), day)
	k = hmacSHA256(k, region)
	k = hmacSHA256(k, service)
	k = hmacSHA256(k, "aws4_request")
	sig := hex.EncodeToString(hmacSHA256(k, toSign))
	return fmt.Sprintf("AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s", accessKey, scope, signed, sig)
}

func (s *S3) do(ctx context.Context, method, key string, body []byte) (*http.Response, error) {
	u, err := url.Parse(s.Endpoint)
	if err != nil {
		return nil, fmt.Errorf("s3 endpoint: %w", err)
	}
	path := "/" + s.Bucket + "/" + key
	t := s.now().UTC()
	payloadHash := sha256Hex(body)
	headers := map[string]string{"host": u.Host, "x-amz-content-sha256": payloadHash, "x-amz-date": t.Format("20060102T150405Z")}
	auth := signV4(method, (&url.URL{Path: path}).EscapedPath(), "", headers, payloadHash, s.Region, "s3", s.AccessKey, s.SecretKey, t)
	req, err := http.NewRequestWithContext(ctx, method, strings.TrimRight(s.Endpoint, "/")+(&url.URL{Path: path}).EscapedPath(), bytes.NewReader(body)) // #nosec G704 -- operator-configured endpoint
	if err != nil {
		return nil, fmt.Errorf("s3 request: %w", err)
	}
	req.Header.Set("x-amz-content-sha256", payloadHash)
	req.Header.Set("x-amz-date", headers["x-amz-date"])
	req.Header.Set("Authorization", auth)
	resp, err := s.client().Do(req) // #nosec G107 G704 -- endpoint is operator config
	if err != nil {
		return nil, fmt.Errorf("s3 %s failed", method)
	}
	return resp, nil
}

// Put stores an object.
func (s *S3) Put(ctx context.Context, key string, data []byte) error {
	resp, err := s.do(ctx, http.MethodPut, key, data)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode/100 != 2 {
		return fmt.Errorf("s3 put: HTTP %d", resp.StatusCode)
	}
	return nil
}

// Get fetches an object; ErrNotFound if missing.
func (s *S3) Get(ctx context.Context, key string) ([]byte, error) {
	resp, err := s.do(ctx, http.MethodGet, key, nil)
	if err != nil {
		return nil, err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode == http.StatusNotFound {
		return nil, ErrNotFound
	}
	if resp.StatusCode/100 != 2 {
		return nil, fmt.Errorf("s3 get: HTTP %d", resp.StatusCode)
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, MaxBlobBytes+1))
	if err != nil {
		return nil, fmt.Errorf("s3 read: %w", err)
	}
	return b, nil
}

// Delete removes an object (missing objects are fine).
func (s *S3) Delete(ctx context.Context, key string) error {
	resp, err := s.do(ctx, http.MethodDelete, key, nil)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode/100 != 2 && resp.StatusCode != http.StatusNotFound {
		return fmt.Errorf("s3 delete: HTTP %d", resp.StatusCode)
	}
	return nil
}
