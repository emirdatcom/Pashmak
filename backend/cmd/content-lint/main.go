// Command content-lint validates config-data/ and enforces the copy style rules.
// Usage: content-lint [-dir ../config-data]. Exit status 1 when any issue is found.
package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/emirdatcom/pashmak/backend/internal/contentlint"
)

func main() {
	dir := flag.String("dir", "../config-data", "config-data directory")
	flag.Parse()
	issues, err := contentlint.Run(*dir)
	if err != nil {
		fmt.Fprintln(os.Stderr, "fatal:", err)
		os.Exit(2)
	}
	for _, i := range issues {
		fmt.Println(i)
	}
	if len(issues) > 0 {
		fmt.Fprintf(os.Stderr, "content-lint: %d issue(s)\n", len(issues))
		os.Exit(1)
	}
	fmt.Println("content-lint: ok")
}
