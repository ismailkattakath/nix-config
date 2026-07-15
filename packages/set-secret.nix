# `set-secret <KEY> <VALUE>` — idempotently write an env-var export into the
# host-local ~/.secrets file that the shared home profile sources at login
# (modules/shared/home.nix, programs.{zsh,bash}.profileExtra). This is the
# convenience writer for the plaintext-token strategy: it keeps ~/.secrets
# chmod-600 and replaces any existing export of the same KEY in place, so
# re-running with a rotated value updates rather than duplicates.
#
# After writing it RE-SOURCES ~/.secrets in a clean subshell and echoes the
# first few characters of the resolved value, proving the export round-trips to
# a shell (login shells pick it up next start).
#
# NOT agenix and NOT committed: ~/.secrets is a host-local plaintext file. The
# VALUE is a positional arg, so it lands in shell history / `ps` — for a hidden
# entry, omit it and the app prompts (read -rs). Runs on both fleet systems.
{
  writeShellApplication,
  coreutils,
  gnugrep,
}:
writeShellApplication {
  name = "set-secret";
  runtimeInputs = [
    coreutils
    gnugrep
  ];
  text = ''
    file="$HOME/.secrets"

    if [ "''${1:-}" = "-h" ] || [ "''${1:-}" = "--help" ]; then
      echo "usage: set-secret <KEY> [VALUE]"
      echo "  Writes 'export KEY=VALUE' into ~/.secrets (chmod 600), replacing any"
      echo "  existing KEY. Omit VALUE to be prompted without echo. KEY must be a"
      echo "  valid shell env-var name."
      exit 0
    fi

    key="''${1:-}"
    if [ -z "$key" ]; then
      echo "set-secret: missing <KEY>. usage: set-secret <KEY> [VALUE]" >&2
      exit 1
    fi
    if ! printf '%s' "$key" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'; then
      echo "set-secret: invalid KEY '$key' (must match [A-Za-z_][A-Za-z0-9_]*)" >&2
      exit 1
    fi

    if [ "$#" -ge 2 ]; then
      value="$2"
    else
      # No value on the command line: read it hidden so it never hits history/ps.
      printf 'Value for %s: ' "$key" >&2
      IFS= read -rs value
      printf '\n' >&2
      if [ -z "$value" ]; then
        echo "set-secret: empty value; nothing written." >&2
        exit 1
      fi
    fi

    # Create the file private if it does not exist yet.
    if [ ! -e "$file" ]; then
      ( umask 077; : > "$file" )
    fi
    chmod 600 "$file"

    # Rewrite atomically in the same dir (preserves fs + perms): drop any prior
    # export of this KEY, then append the new one with %q-safe quoting.
    tmp="$(mktemp "$file.XXXXXX")"
    chmod 600 "$tmp"
    grep -vE "^export ''${key}=" "$file" > "$tmp" || true
    printf 'export %s=%q\n' "$key" "$value" >> "$tmp"
    mv "$tmp" "$file"

    # Prove it reached a shell: source the file fresh and read the var back by
    # indirect expansion, then show only the first few characters.
    got="$(
      # shellcheck disable=SC1090
      . "$file" >/dev/null 2>&1
      printf '%s' "''${!key}"
    )"
    if [ "$got" != "$value" ]; then
      echo "set-secret: WARNING — $key did not round-trip when sourcing $file." >&2
      exit 1
    fi
    echo "set-secret: wrote $key to $file — sourced OK (value starts with ''${got:0:4}…). Full value applies at next login."
  '';
}
