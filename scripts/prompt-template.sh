#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: prompt-template.sh <mode>" >&2
  echo "Modes: debug, refactor, explain, review" >&2
  exit 1
fi

mode=$1

# Get clipboard content
if command -v wl-paste >/dev/null 2>&1; then
  context=$(wl-paste --type text/plain)
elif command -v xclip >/dev/null 2>&1; then
  context=$(xclip -selection clipboard -o)
elif command -v xsel >/dev/null 2>&1; then
  context=$(xsel --clipboard --output)
else
  echo "No clipboard tool found." >&2
  exit 1
fi

if [[ -z "$context" ]]; then
  echo "Clipboard is empty." >&2
  exit 1
fi

# Build template based on mode
case "$mode" in
  debug)
    template="You are a debugging expert. Analyze the following code context and help identify issues, bugs, or potential problems. Focus on:
- Logic errors and edge cases
- Performance issues
- Security vulnerabilities
- Unexpected behavior or unhandled states

Provide specific, actionable fixes with explanations."
    ;;
  refactor)
    template="You are a code refactoring expert. Review the following code context and suggest improvements for:
- Code readability and clarity
- DRY principles and eliminiting duplication
- Design patterns and best practices
- Performance optimizations
- Testability and maintainability

Provide concrete refactoring suggestions with explanations."
    ;;
  explain)
    template="You are a code explanation expert. Analyze the following code context and explain:
- What the code does and its purpose
- How different parts work together
- Key algorithms and data structures used
- Important design decisions
- Potential issues or limitations

Use clear, beginner-friendly language."
    ;;
  review)
    template="You are a code reviewer. Perform a thorough review of the following code context covering:
- Correctness and functionality
- Code quality and style
- Test coverage and edge cases
- Documentation and clarity
- Performance and scalability
- Security and error handling

Provide constructive feedback with priorities (critical, important, nice-to-have)."
    ;;
  *)
    echo "Unknown mode: $mode" >&2
    echo "Modes: debug, refactor, explain, review" >&2
    exit 1
    ;;
esac

# Combine template with context
result="$template"$'\n\n'"---"$'\n\n'"$context"

# Copy to clipboard
if command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$result" | wl-copy --type text/plain
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "$result" | xclip -selection clipboard
elif command -v xsel >/dev/null 2>&1; then
  printf '%s' "$result" | xsel --clipboard --input
else
  echo "No clipboard tool found." >&2
  exit 1
fi

echo "Applied $mode template to clipboard" >&2
