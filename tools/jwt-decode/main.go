package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"strings"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: jwt-decode <token>")
		os.Exit(2)
	}
	parts := strings.Split(os.Args[1], ".")
	if len(parts) < 2 {
		fmt.Fprintln(os.Stderr, "not a JWT (expected at least header.payload)")
		os.Exit(2)
	}
	for i, name := range []string{"header", "payload"} {
		raw, err := base64.RawURLEncoding.DecodeString(parts[i])
		if err != nil {
			fmt.Fprintf(os.Stderr, "%s: %v\n", name, err)
			os.Exit(1)
		}
		var v any
		if err := json.Unmarshal(raw, &v); err != nil {
			fmt.Fprintf(os.Stderr, "%s: %v\n", name, err)
			os.Exit(1)
		}
		out, err := json.MarshalIndent(v, "", "  ")
		if err != nil {
			fmt.Fprintf(os.Stderr, "%s: %v\n", name, err)
			os.Exit(1)
		}
		fmt.Printf("--- %s ---\n%s\n", name, string(out))
	}
}
