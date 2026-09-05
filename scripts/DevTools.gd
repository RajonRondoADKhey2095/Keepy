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
## THE THREE WAYS IN, AND WHY EACH ONE
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
##        https://keepy-staging.vercel.app/?keepydev=1
##    This is the one that makes the overlay useful rather than
##    ceremonial -- it works on staging AND on production, on the real
##    device, against the exact build that shipped, and a player who never
##    types it cannot reach any of it. It is read fresh on every call from
##    the REAL browser location, so no build-time flag decides it and the
##    same .pck behaves correctly wherever it is served.
##
## NOT a build-time constant, and NOT an export preset feature tag: there
## is ONE "Web" preset and CI exports it once for both staging and
## production, so a build-time answer could not tell those two apart even
## if we wanted it to.
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

## True where developer affordances may be shown. See the header for the
## three ways this becomes true; every one of them is deliberate.
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
	if raw == null:
		return false
	return str(raw).to_lower().contains(URL_FLAG)
