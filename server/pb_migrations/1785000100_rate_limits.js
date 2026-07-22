/// <reference path="../pb_data/types.d.ts" />

// ═══════════════════════════════════════════════════════════════════════════
// Φάση 8 (hardening) — rate limiting: anti-spam chat + anti brute-force auth.
// ═══════════════════════════════════════════════════════════════════════════
// Ενεργοποιεί τον ενσωματωμένο rate limiter του PocketBase και ορίζει «ισορροπημένα»
// όρια: σταματούν κατάχρηση χωρίς να ενοχλούν την κανονική χρήση. Το όριο μετριέται
// ΑΝΑ client (IP για guests, auth id για συνδεδεμένους) σε κυλιόμενο παράθυρο.
//
// Labels (βλ. types.d.ts RateLimitRule): δέχονται `collection:action` ή `METHOD /path`.
// Πιο συγκεκριμένο label υπερισχύει. audience: ""=όλοι, "@guest", "@auth".
//
// ΣΗΜ.: αν αργότερα αλλάξει το binary/έκδοση και τα plain-object rules αγνοηθούν
// σιωπηλά (όπως τα collection fields στη v0.39), το verify θα το πιάσει — δοκιμάζουμε
// εμπειρικά ότι όντως γυρίζει 429 (Too Many Requests).
migrate((app) => {
	const settings = app.settings()
	settings.rateLimits.enabled = true
	settings.rateLimits.rules = [
		// Chat anti-spam: 10 μηνύματα / 10s ανά χρήστη (balanced — αρκεί για ζωηρή
		// συνομιλία, κόβει flood).
		{ label: "messages:create", audience: "@auth", duration: 10, maxRequests: 10 },
		// Anti brute-force login: 10 προσπάθειες / 30s ανά IP (guests).
		{ label: "POST /api/collections/users/auth-with-password", audience: "", duration: 30, maxRequests: 10 },
		// Anti mass-registration: 5 νέοι λογαριασμοί / 60s ανά IP.
		{ label: "POST /api/collections/users/records", audience: "@guest", duration: 60, maxRequests: 5 },
		// Γενικό δίχτυ ασφαλείας για ΟΛΟ το REST API (γενναιόδωρο — μόνο anti-abuse).
		{ label: "/api/", audience: "", duration: 10, maxRequests: 300 },
	]
	app.save(settings)

}, (app) => {
	// ── DOWN: απενεργοποίηση rate limiting ──────────────────────────────────
	const settings = app.settings()
	settings.rateLimits.enabled = false
	settings.rateLimits.rules = []
	app.save(settings)
})
