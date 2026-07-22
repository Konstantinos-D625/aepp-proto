/// <reference path="../pb_data/types.d.ts" />

// ═══════════════════════════════════════════════════════════════════════════
// Φάση 5 (Friends) — σχέσεις φιλίας μεταξύ παικτών.
// ═══════════════════════════════════════════════════════════════════════════
// Μοντέλο αίτημα → αποδοχή: ο `requester` στέλνει αίτημα (status="pending"), ο
// `addressee` το αποδέχεται (status="accepted") ή το απορρίπτει (delete). Και οι
// δύο πλευρές ΔΙΑΒΑΖΟΥΝ/ΣΒΗΝΟΥΝ τη σχέση· ΔΗΜΙΟΥΡΓΕΙ μόνο ο requester (πάντα
// pending), ΑΛΛΑΖΕΙ status (αποδοχή) μόνο ο addressee.
//
// Τα ΔΗΜΟΣΙΑ προφίλ (`profiles`) είναι ήδη ορατά σε κάθε συνδεδεμένο παίκτη — η
// φιλία είναι ουσιαστικά «λίστα αγαπημένων» για εύκολη σύγκριση προόδου. Κρατάμε
// denormalized usernames ώστε η λίστα να εμφανίζεται χωρίς επιπλέον lookups.
//
// ΣΗΜ. (ίδια παγίδα v0.39 με τα προηγούμενα migrations): typed fields ΜΟΝΟ με
// fields.add() — το `fields:[...]` array στον constructor αγνοείται σιωπηλά.
migrate((app) => {
	const users = app.findCollectionByNameOrId("users")

	const fr = new Collection({ type: "base", name: "friendships" })

	fr.fields.add(new RelationField({
		name: "requester",
		required: true,
		maxSelect: 1,
		collectionId: users.id,
		cascadeDelete: true,
	}))
	fr.fields.add(new RelationField({
		name: "addressee",
		required: true,
		maxSelect: 1,
		collectionId: users.id,
		cascadeDelete: true,
	}))
	// Denormalized ονόματα (ώστε η λίστα φίλων να μη χρειάζεται lookup ανά record).
	fr.fields.add(new TextField({ name: "requester_name", required: true, max: 20 }))
	fr.fields.add(new TextField({ name: "addressee_name", required: true, max: 20 }))
	fr.fields.add(new SelectField({
		name: "status",
		required: true,
		maxSelect: 1,
		values: ["pending", "accepted"],
	}))

	// Ένα αίτημα ανά κατεύθυνση· ο client ελέγχει ΚΑΙ τις δύο κατευθύνσεις πριν
	// στείλει (η αντίστροφη (B,A) δεν μπλοκάρεται από αυτό το index).
	fr.indexes = [
		"CREATE UNIQUE INDEX `idx_friend_pair` ON `friendships` (`requester`, `addressee`)",
	]

	// Και οι δύο εμπλεκόμενοι βλέπουν τη σχέση.
	fr.listRule = "@request.auth.id = requester || @request.auth.id = addressee"
	fr.viewRule = "@request.auth.id = requester || @request.auth.id = addressee"
	// Δημιουργεί μόνο ο ίδιος ο requester, πάντα ως pending, ποτέ με τον εαυτό του.
	fr.createRule = "@request.auth.id = requester && requester != addressee && status = 'pending'"
	// Αποδοχή αιτήματος: μόνο ο addressee αλλάζει την εγγραφή.
	fr.updateRule = "@request.auth.id = addressee"
	// Ακύρωση / απόρριψη / διαγραφή φιλίας: οποιοσδήποτε από τους δύο.
	fr.deleteRule = "@request.auth.id = requester || @request.auth.id = addressee"

	app.save(fr)

}, (app) => {
	// ── DOWN ────────────────────────────────────────────────────────────────
	try { app.delete(app.findCollectionByNameOrId("friendships")) } catch (_) {}
})
