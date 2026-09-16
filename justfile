# Recipes contain no shell pipelines; orchestration belongs to the Go CLI.
set shell := ["sh", "-cu"]
set windows-shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]
export GOTOOLCHAIN := "go1.26.6"

_default:
    @just --list

[private]
bootstrap:
    go run ./tool/bootstrap.go bootstrap

[private]
doctor:
    go run ./tool/bootstrap.go doctor

[private]
security:
    go run ./tool/bootstrap.go security

[private]
security-secrets:
    go run ./tool/bootstrap.go security-secrets

[private]
security-dependencies:
    go run ./tool/bootstrap.go security-dependencies

[private]
commit-check title:
    go run ./tool/bootstrap.go commit-check {{if os() == "windows" { "'" + replace(title, "'", "''") + "'" } else { quote(title) }}}

[private]
generate:
    go run ./tool/bootstrap.go generate

fmt:
    go run ./tool/bootstrap.go format

lint:
    go run ./tool/bootstrap.go lint

arch:
    go run ./tool/bootstrap.go arch

test:
    go run ./tool/bootstrap.go test

[private]
property:
    go run ./tool/bootstrap.go property

check:
    go run ./tool/bootstrap.go check

[private]
coverage base="":
    go run ./tool/bootstrap.go coverage-check {{if base == "" { "" } else { "--base " + if os() == "windows" { "'" + replace(base, "'", "''") + "'" } else { quote(base) } }}}

changes base="":
    go run ./tool/bootstrap.go changes {{if base == "" { "" } else { "--base " + if os() == "windows" { "'" + replace(base, "'", "''") + "'" } else { quote(base) } }}}

[private]
review-check file=".governance/review.json":
    go run ./tool/bootstrap.go review-check --file {{if os() == "windows" { "'" + replace(file, "'", "''") + "'" } else { quote(file) }}}

[private]
debug-start case:
    go run ./tool/bootstrap.go debug-start  {{if os() == "windows" { "'" + replace(case, "'", "''") + "'" } else { quote(case) }}}

[private]
debug-run session profile:
    go run ./tool/bootstrap.go debug-run  {{if os() == "windows" { "'" + replace(session, "'", "''") + "'" } else { quote(session) }}} {{if os() == "windows" { "'" + replace(profile, "'", "''") + "'" } else { quote(profile) }}}

[private]
debug-verify session profile:
    go run ./tool/bootstrap.go debug-verify  {{if os() == "windows" { "'" + replace(session, "'", "''") + "'" } else { quote(session) }}} {{if os() == "windows" { "'" + replace(profile, "'", "''") + "'" } else { quote(profile) }}}

[private]
debug-report session:
    go run ./tool/bootstrap.go debug-report  {{if os() == "windows" { "'" + replace(session, "'", "''") + "'" } else { quote(session) }}}

[private]
ui-report manifest=".governance/ui.json":
    go run ./tool/bootstrap.go ui-report --manifest {{if os() == "windows" { "'" + replace(manifest, "'", "''") + "'" } else { quote(manifest) }}}

# Native targets deliberately require an explicit device.
[private]
test-device target device:
    go run ./tool/bootstrap.go test-device {{if os() == "windows" { "'" + replace(target, "'", "''") + "'" } else { quote(target) }}} -d {{if os() == "windows" { "'" + replace(device, "'", "''") + "'" } else { quote(device) }}}

[private]
capture-ui target device:
    go run ./tool/bootstrap.go capture-ui --target={{if os() == "windows" { "'" + replace(target, "'", "''") + "'" } else { quote(target) }}} -d {{if os() == "windows" { "'" + replace(device, "'", "''") + "'" } else { quote(device) }}}

[private]
fuzz: property

[private]
skills-check:
    go run ./tool/bootstrap.go skills-check

[private]
recipes-check:
    go run ./tool/bootstrap.go recipes-check

[private]
generate-check:
    go run ./tool/bootstrap.go generate-check --output lib/l10n/generated -- flutter gen-l10n

[private]
ios-smoke:
    go run ./tool/bootstrap.go ios-smoke

# Native smoke on an emulator that is already running; pass its serial.
[private]
android-smoke serial="emulator-5554":
    go run ./tool/bootstrap.go android-smoke -d {{if os() == "windows" { "'" + replace(serial, "'", "''") + "'" } else { quote(serial) }}}

