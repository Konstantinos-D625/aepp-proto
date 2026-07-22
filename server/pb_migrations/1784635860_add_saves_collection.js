/// <reference path="../pb_data/types.d.ts" />

// ═══════════════════════════════════════════════════════════════════════════
// Φάση 4 (cloud sync) — ΙΔΙΩΤΙΚΟ πλήρες save του παίκτη (cross-device restore).
// ═══════════════════════════════════════════════════════════════════════════
// ΞΕΧΩΡΙΣΤΟ από το `profiles` (που είναι ΔΗΜΟΣΙΟ στιγμιότυπο για φίλους/κατάταξη).
// Εδώ αποθηκεύεται ΟΛΟΚΛΗΡΟ το τοπικό save serialized (GameData.export_save())
// ώστε, αν ο παίκτης σβήσει/αλλάξει συσκευή, να το επαναφέρει με τη σύνδεση.
//
// ΑΠΟΡΡΗΤΟ: σε αντίθεση με τα profiles (τα διαβάζει κάθε συνδεδεμένος), το save
// είναι ΜΟΝΟ του κατόχου — όλοι οι κανόνες απαιτούν user == ο συνδεδεμένος.
//
// Σύγκρουση/«ποιο κερδίζει»: ο client συγκρίνει το `score` (GameData.progress_
// score) — κερδίζει η πιο προχωρημένη πρόοδος (ο παίκτης δεν χάνει ποτέ το
// καλύτερό του save). Ο χρόνος (updated_at) ζει ΜΕΣΑ στο blob, δεν χρειάζεται
// ξεχωριστό πεδίο για την απόφαση.
migrate((app) => {
	const users = app.findCollectionByNameOrId("users")

	// ΣΗΜ. (ίδια παγίδα v0.39 με το Φ1 migration): typed fields ΜΟΝΟ με
	// fields.add() — το `fields:[...]` στον constructor αγνοείται σιωπηλά.
	const saves = new Collection({ type: "base", name: "saves" })

	saves.fields.add(new RelationField({
		name: "user",
		required: true,
		maxSelect: 1,
		collectionId: users.id,
		cascadeDelete: true,
	}))
	// Ολόκληρο το serialized save (GameData.export_save() ως JSON string).
	saves.fields.add(new JSONField({ name: "blob", required: true, maxSize: 200000 }))
	// Δείκτης προόδου για την απόφαση σύγκρουσης (μεγαλύτερο = πιο προχωρημένο).
	saves.fields.add(new NumberField({ name: "score", onlyInt: true, min: 0 }))

	// Ένα save ανά χρήστη (upsert από τον client: PATCH αν υπάρχει, αλλιώς POST).
	saves.indexes = [
		"CREATE UNIQUE INDEX `idx_saves_user` ON `saves` (`user`)",
	]

	// ΜΟΝΟ ο κάτοχος — καμία πρόσβαση τρίτων στο πλήρες save.
	saves.listRule   = "user = @request.auth.id"
	saves.viewRule   = "user = @request.auth.id"
	saves.createRule = "@request.auth.id != '' && user = @request.auth.id"
	saves.updateRule = "user = @request.auth.id"
	saves.deleteRule = "user = @request.auth.id"

	app.save(saves)

}, (app) => {
	// ── DOWN ────────────────────────────────────────────────────────────────
	try { app.delete(app.findCollectionByNameOrId("saves")) } catch (_) {}
})
