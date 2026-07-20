/// <reference path="../pb_data/types.d.ts" />

// ═══════════════════════════════════════════════════════════════════════════
// Φάση 1 (online social layer) — αρχικό σχήμα του PocketBase backend.
// ═══════════════════════════════════════════════════════════════════════════
// Δύο αλλαγές:
//   1) Το ενσωματωμένο `users` auth collection γίνεται username+password (ΧΩΡΙΣ
//      υποχρεωτικό email — ανήλικοι/GDPR, κλειδωμένη απόφαση 2026-07-20).
//   2) Νέο `profiles` base collection: το ΔΗΜΟΣΙΟ στιγμιότυπο προόδου που στέλνει
//      ο παίκτης (ακριβώς το payload του PlayerProfile.build_public_profile()).
//      Είναι ο στόχος του cloud sync (Φάση 4) και η πηγή για φίλους/κατάταξη.
//
// Friends/clans/chat collections προστίθενται σε επόμενες φάσεις (5-7).
migrate((app) => {
	// ── 1) users: username-based auth, email προαιρετικό ────────────────────
	const users = app.findCollectionByNameOrId("users")

	// Email δεν είναι πλέον υποχρεωτικό — signup μόνο με username.
	users.fields.getByName("email").required = false

	// Νέο πεδίο username = η ταυτότητα σύνδεσης.
	users.fields.add(new TextField({
		name: "username",
		required: true,
		min: 3,
		max: 20,
		pattern: "^[a-zA-Z0-9_]+$",
	}))

	// Μοναδικότητα username (case-insensitive). ΑΠΑΙΤΕΙΤΑΙ για identity login.
	users.indexes = [
		...users.indexes,
		"CREATE UNIQUE INDEX `idx_users_username` ON `users` (`username` COLLATE NOCASE)",
	]

	// Σύνδεση με username αντί για email.
	users.passwordAuth.identityFields = ["username"]

	app.save(users)

	// ── 2) profiles: δημόσιο στιγμιότυπο προόδου ────────────────────────────
	// ΣΗΜ.: στη v0.39 τα typed fields ΠΡΕΠΕΙ να μπαίνουν με fields.add() — ένα
	// `fields: [...]` array στον constructor αγνοείται σιωπηλά.
	const profiles = new Collection({ type: "base", name: "profiles" })

	profiles.fields.add(new RelationField({
		name: "user",
		required: true,
		maxSelect: 1,
		collectionId: users.id,
		cascadeDelete: true,
	}))
	// Denormalized username για αναζήτηση/εμφάνιση φίλων χωρίς να ανοίγουμε το
	// κλειδωμένο auth collection.
	profiles.fields.add(new TextField({ name: "username", required: true, max: 20 }))
	profiles.fields.add(new TextField({ name: "region_id", max: 40 }))
	profiles.fields.add(new TextField({ name: "region_label", max: 120 }))
	profiles.fields.add(new NumberField({ name: "streak", onlyInt: true, min: 0 }))
	profiles.fields.add(new JSONField({ name: "achievements", maxSize: 20000 }))
	profiles.fields.add(new NumberField({ name: "achievements_count", onlyInt: true, min: 0 }))
	profiles.fields.add(new NumberField({ name: "achievements_total", onlyInt: true, min: 0 }))
	profiles.fields.add(new NumberField({ name: "party_power" }))
	profiles.fields.add(new NumberField({ name: "roster_size", onlyInt: true, min: 0 }))
	profiles.fields.add(new NumberField({ name: "gear_owned", onlyInt: true, min: 0 }))
	profiles.fields.add(new BoolField({ name: "goblin_defeated" }))
	profiles.fields.add(new BoolField({ name: "tree_defeated" }))
	profiles.fields.add(new BoolField({ name: "morgana_defeated" }))
	profiles.fields.add(new TextField({ name: "last_active", max: 40 }))

	profiles.indexes = [
		"CREATE UNIQUE INDEX `idx_profiles_user` ON `profiles` (`user`)",
		"CREATE UNIQUE INDEX `idx_profiles_username` ON `profiles` (`username` COLLATE NOCASE)",
	]

	// Κάθε συνδεδεμένος παίκτης διαβάζει προφίλ (φίλοι/κατάταξη). Γράφει/σβήνει
	// μόνο ο κάτοχος το δικό του (user == ο συνδεδεμένος).
	profiles.listRule   = "@request.auth.id != ''"
	profiles.viewRule   = "@request.auth.id != ''"
	profiles.createRule = "@request.auth.id != '' && user = @request.auth.id"
	profiles.updateRule = "user = @request.auth.id"
	profiles.deleteRule = "user = @request.auth.id"

	app.save(profiles)

}, (app) => {
	// ── DOWN: αντιστροφή ────────────────────────────────────────────────────
	try { app.delete(app.findCollectionByNameOrId("profiles")) } catch (_) {}

	const users = app.findCollectionByNameOrId("users")
	users.fields.removeByName("username")
	users.indexes = users.indexes.filter((ix) => !ix.includes("idx_users_username"))
	users.fields.getByName("email").required = true
	users.passwordAuth.identityFields = ["email"]
	app.save(users)
})
