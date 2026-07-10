# gh-wrapper.sh — env-hygiene wrapper around the gh CLI.
#
# Source this from any hook or script that invokes gh:
#   . "$(dirname "$0")/../lib/gh-wrapper.sh"
#
# Provides:
#   _gh <args...>       — invokes gh with namespaced-token translation and
#                         pager disabled. Use instead of bare `gh`.
#
# Why: the user's shell may have a stale GH_TOKEN, GITHUB_TOKEN, or
# GH_PAGER set from an earlier login, CI workflow, or shell rc file.
# `gh` respects those over the keyring, which silently breaks plugin-
# initiated calls (wrong account, hung pager, exit-code conflation on
# auth checks). This wrapper picks the plugin's namespaced token if
# present, falls back to the user's GH_TOKEN/GITHUB_TOKEN for CI
# environments, scrubs GH_PAGER, and runs gh fresh.
#
# Configure the plugin's namespaced token variable name here. The default
# is intentionally unmemorable so authors notice and customize it.
: "${GH_WRAPPER_TOKEN_VAR:=UNCONFIGURED_PLUGIN_GH_TOKEN}"

# Preflight: warn loudly if the placeholder name is unchanged.
if [ "$GH_WRAPPER_TOKEN_VAR" = "UNCONFIGURED_PLUGIN_GH_TOKEN" ]; then
	echo "gh-wrapper.sh: GH_WRAPPER_TOKEN_VAR is the default placeholder. Edit the lib file and set it to your plugin's namespaced token var (e.g., MYPLUGIN_GH_TOKEN)." >&2
fi

# Preflight: warn if gh is not installed; don't fail at source time
# because not every hook that sources lib helpers needs gh.
if ! command -v gh >/dev/null 2>&1; then
	echo "gh-wrapper.sh: gh CLI not found on PATH. _gh calls will exit 127." >&2
fi

_gh() {
	local resolved_token=""
	if [ -n "${!GH_WRAPPER_TOKEN_VAR:-}" ]; then
		resolved_token="${!GH_WRAPPER_TOKEN_VAR}"
	elif [ -n "${GH_TOKEN:-}" ]; then
		resolved_token="$GH_TOKEN"
	elif [ -n "${GITHUB_TOKEN:-}" ]; then
		resolved_token="$GITHUB_TOKEN"
	fi

	if [ -n "$resolved_token" ]; then
		GH_TOKEN="$resolved_token" \
		GITHUB_TOKEN="$resolved_token" \
		GH_PAGER=cat \
		gh "$@"
	else
		# No token resolved. Unset GH_TOKEN/GITHUB_TOKEN entirely so gh
		# falls through to keyring auth — passing an empty string is
		# treated by gh as "use this empty token" and fails auth with
		# a confusing error instead of using the keyring.
		env -u GH_TOKEN -u GITHUB_TOKEN GH_PAGER=cat gh "$@"
	fi
}

# _gh_auth_ok — returns 0 if `gh auth status` succeeds with the resolved
# token. Differs from a bare `gh auth status` check in that it disambiguates
# env-token failures from keyring-success failures by controlling the env
# at the check site.
_gh_auth_ok() {
	_gh auth status >/dev/null 2>&1
}
