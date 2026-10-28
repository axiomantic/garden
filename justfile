import? 'justfile.local'

default:
    @just --list

# 1. Dependency Setup
setup:
    nimble install --depsOnly -y
    npm install

# 2. Test Suite Execution
test:
    @just test-nim
    @just test-riders

test-nim:
    nimble test

test-riders:
    node tests/test_riders.js

# 3. Linter Execution
lint:
    @just lint-nim

lint-nim:
    nimble check

# 5. Build Artifacts
build:
    mkdir -p bin
    nim c -d:release -o:bin/garden src/garden.nim

# 8. Clean Build Artifacts
clean:
    rm -rf nimcache htmldocs site docs/dist docs/.astro tools/docgen dist .venv
    find . -name '*.exe' -delete

# 9. Secret Scanning
check-secrets:
    @if command -v gitleaks >/dev/null 2>&1; then \
        gitleaks detect -v; \
    elif command -v pre-commit >/dev/null 2>&1; then \
        pre-commit run gitleaks --all-files; \
    else \
        echo "Error: neither gitleaks nor pre-commit found. Install gitleaks or pre-commit." >&2; exit 1; \
    fi

# 10. Upstream Template Synchronization
update-template:
    uvx copier update --trust
