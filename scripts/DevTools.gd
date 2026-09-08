class_name DevTools
extends RefCounted
## The ONE gate for everything a developer may see and a player may not.
##
## =====================================================================
## WHY THIS REPLACED A HOSTNAME TEST
##
## The carte-blanche branch gated its preview tools -- the perf overlay,
## the weather forcing row, the save-reset button -- on
## `Auth.is_untrusted_preview_domain()`: "any *.vercel.app host that is
## neither keepy-staging nor keepy-ten". That test was written for a
## throwaway alias (keepy-cozy) and it is wrong in both directions the
## moment that alias stops existing:
##
##   * it is a DENY-LIST. Every host not explicitly named is a developer
##     host, so the day a fourth alias appears -- a Vercel preview URL for
##     a pull request, a renamed project -- the tools turn themselves ON
##     for whoever opens that link, with nothing to say they did.
##   * it can never be true on staging or production, which is precisely
##     where a perf overlay is worth having. Measuring the shipped build
##     is the entire reason the overlay is not throwaway.
##
## This is the ALLOW-LIST version of the same idea: nothing is shown
## unless something explicitly asks for it, and what asks for it is not a
## hostname.
##
## =====================================================================
## THE FOUR WAYS IN, AND WHY EACH ONE
##
## 1. OFF-WEB -- the editor, a headless probe, an xvfb capture. Unchanged
##    from the branch (`or not OS.has_feature("web")` was already there),
##    and load-bearing: CozyCapture renders the HUD it is asked to render
##    only because these controls are visible off-web.
##
## 2. A DEBUG WEB EXPORT. CI exports `--export-release`, so the .pck a
##    player ever downloads answers false here. A debug export is
##    something a developer made on purpose.
##
## 3. AN EXPLICIT URL FLAG on a release web build: "keepydev" anywhere in
##    the query string or the fragment, e.g.
##        https://keepy-ten.vercel.app/?keepydev=1
##    This is the one that makes the overlay useful rather than
##    ceremonial -- it works on staging AND on production, on the real
##    device, against the exact build that shipped, and a player who never
##    types it cannot reach any of it. It is read fresh on every call from
##    the REAL browser location, so no build-time flag decides it and the
##    same .pck behaves correctly wherever it is served.
##
## 4. THE STAGING HOST, by default, with no flag needed. Repeated manual
##    navigation to append "?keepydev=1" on every page load was the actual
##    complaint this default closes. `keepy-staging.vercel.app` is read
##    from `window.location.hostname` -- an ALLOW-LIST of one exact host,
##    the same shape as rule 3, never a deny-list of "everything that is
##    not production". Production (`keepy-ten.vercel.app`) is untouched:
##    it still answers false unless rule 3 fires. "keepydev=0" in the URL
##    overrides this default OFF on staging, for the one time Mathieu wants
##    to see the screen without the overlay; it is checked before the
##    staging default and before rule 3, so it also silences an explicit
##    "keepydev=1" if both were ever present together.
##
## NOT a build-time constant, and NOT an export preset feature tag: there
## is ONE "Web" preset and CI exports it once for both staging and
## production, so a build-time answer could not tell those two apart even
## if we wanted it to. The staging default in rule 4 is a runtime hostname
## read for the same reason rule 3 reads the URL at call time.
##
## =====================================================================
## WHAT THIS IS NOT
##
## It is NOT an authorisation boundary, and nothing behind it may ever be
## treated as one. Anyone can type the flag. It gates VISIBILITY of
## developer affordances, so a normal player cannot trip over them -- it
## does not protect data. Everything that touches Firestore stays gated on
## `Auth.is_signed_in()` / `get_id_token()`, which this file never reads
## and never influences.

## The token looked for in the URL. Deliberately not a bare word like
## "debug": query strings collect other people's parameters, and a
## collision here would turn the tools on by accident -- the exact failure
## the hostname deny-list had.
const URL_FLAG: String = "keepydev"

## The explicit override that turns rule 4 (staging default-on) back off.
## Checked as its own substring, never derived from URL_FLAG by parsing --
## a player-supplied "keepydev=0" still contains "keepydev", so the two
## checks have to be independent tokens, not one flag with a value pulled
## out of it.
const URL_FLAG_OFF: String = "keepydev=0"

## The one host that defaults developer affordances on without a flag.
## An exact allow-listed hostname, not a suffix/prefix guess: production is
## `keepy-ten.vercel.app`, a different string entirely, so there is no
## partial match to worry about between the two.
const STAGING_HOST: String = "keepy-staging.vercel.app"

## True where developer affordances may be shown. See the header for the
## four ways this becomes true; every one of them is deliberate.
static func enabled() -> bool:
	if not OS.has_feature("web"):
		return true
	if OS.is_debug_build():
		return true
	# Reading location on every call rather than caching it once: this is
	# three calls in one _ready(), the cost is nothing, and a cached
	# answer is one more piece of state that can be stale in a way nobody
	# would notice until the overlay refused to appear on device.
	var raw = JavaScriptBridge.eval("window.location.search + window.location.hash", true)
	var query := ("" if raw == null else str(raw)).to_lower()
	if query.contains(URL_FLAG_OFF):
		return false
	if query.contains(URL_FLAG):
		return true
	var host_raw = JavaScriptBridge.eval("window.location.hostname", true)
	var host := ("" if host_raw == null else str(host_raw)).to_lower()
	return host == STAGING_HOST
