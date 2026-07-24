/// <reference path="../pb_data/types.d.ts" />

// ═══════════════════════════════════════════════════════════════════════════
// Φάση 9 (Κέρματα Φιλίας) — 1 δωρεάν Κέρμα Φιλίας τη μέρα σε ΚΑΘΕ φίλο.
// ═══════════════════════════════════════════════════════════════════════════
// Κάθε εγγραφή = «ο from_user έδωσε 1 Κέρμα Φιλίας στον to_user, τη μέρα date».
// ΚΑΜΙΑ προϋπόθεση πέρα από την ίδια τη φιλία: ο καθένας στέλνει ένα δώρο σε
// κάθε φίλο του τη μέρα, ανεξάρτητα από την πρόοδο του άλλου.
// Η επιβολή είναι ΕΞ ΟΛΟΚΛΗΡΟΥ server-side και δεν χρειάζεται τίποτα άλλο:
//   1) το UNIQUE index παρακάτω — ΕΝΑ δώρο ανά (from_user, to_user, date), ό,τι
//      κι αν ξαναπροσπαθήσει να κάνει ο client.
//   2) το createRule — ο αποστολέας πρέπει να είναι ο ίδιος, όχι ο εαυτός του,
//      ΚΑΙ να υπάρχει πραγματική ΑΠΟΔΕΚΤΗ φιλία (nested relation friendship.*)
//      ανάμεσα ακριβώς σε αυτούς τους δύο χρήστες.
//
// ΙΣΤΟΡΙΚΟ: αρχικά ο κανόνας απαιτούσε να έχουν ΚΑΙ ΟΙ ΔΥΟ ολοκληρώσει το Daily
// Quest τους εκείνη τη μέρα (client-side έλεγχος πάνω στο profiles.
// daily_quest_done_today). Καταργήθηκε — βλ. drop_profile_daily_quest_flag.
// ΜΟΝΟ ΣΧΟΛΙΑ άλλαξαν εδώ· ο ορισμός της συλλογής παρακάτω είναι ο αρχικός,
// αναλλοίωτος (το migration έχει ήδη εφαρμοστεί και ΔΕΝ ξανατρέχει).
//
// Ο ΠΑΡΑΛΗΠΤΗΣ (to_user) «μαζεύει» το κέρμα ΤΟΠΙΚΑ (Currency.add στο δικό του
// client) την επόμενη φορά που ανοίγει την καρτέλα «Φίλοι» — βλ.
// friends_popup.gd::_claim_incoming_gifts. Το GameData.friendship_gifts_claimed
// κρατάει ποια record ids έχουν ήδη μετρήσει, ώστε να μην πιστωθούν δύο φορές.
//
// ΣΗΜ. (ίδιες παγίδες PocketBase όπως στα προηγούμενα migrations):
//   1) typed fields ΜΟΝΟ με fields.add() — το `fields:[...]` στον constructor
//      αγνοείται σιωπηλά.
//   2) updateRule = **null** ⇒ κλειδωμένο (μόνο superuser)· "" (κενό string) θα
//      σήμαινε ΔΗΜΟΣΙΟ! Τα δώρα είναι αμετάβλητα μετά τη δημιουργία.
migrate((app) => {
	const users = app.findCollectionByNameOrId("users")
	const friendships = app.findCollectionByNameOrId("friendships")

	const g = new Collection({ type: "base", name: "friendship_gifts" })

	g.fields.add(new RelationField({
		name: "friendship",
		required: true,
		maxSelect: 1,
		collectionId: friendships.id,
		cascadeDelete: true,
	}))
	g.fields.add(new RelationField({
		name: "from_user",
		required: true,
		maxSelect: 1,
		collectionId: users.id,
		cascadeDelete: true,
	}))
	g.fields.add(new RelationField({
		name: "to_user",
		required: true,
		maxSelect: 1,
		collectionId: users.id,
		cascadeDelete: true,
	}))
	g.fields.add(new TextField({ name: "date", required: true, min: 10, max: 10 })) // "YYYY-MM-DD"
	g.fields.add(new AutodateField({ name: "created", onCreate: true }))

	// ΕΝΑ δώρο ανά κατεύθυνση/μέρα — ο server αρνείται (400, duplicate key) μια
	// δεύτερη προσπάθεια, ό,τι κι αν λέει το (ήδη ενημερωμένο) client UI.
	g.indexes = [
		"CREATE UNIQUE INDEX `idx_gift_per_day` ON `friendship_gifts` (`from_user`, `to_user`, `date`)",
	]

	// Και οι δύο πλευρές βλέπουν το δώρο (ο αποστολέας για επιβεβαίωση, ο
	// παραλήπτης για να το «μαζέψει»).
	g.listRule = "@request.auth.id = from_user || @request.auth.id = to_user"
	g.viewRule = "@request.auth.id = from_user || @request.auth.id = to_user"
	// Δημιουργεί ΜΟΝΟ ο αποστολέας, ΜΟΝΟ για πραγματική αποδεκτή φιλία του με
	// τον παραλήπτη — το nested relation friendship.* αποτρέπει δώρο σε άσχετο
	// ή μη-αποδεκτό ζευγάρι.
	g.createRule = "@request.auth.id = from_user && from_user != to_user && " +
		"friendship.status = 'accepted' && " +
		"(friendship.requester = from_user || friendship.addressee = from_user) && " +
		"(friendship.requester = to_user || friendship.addressee = to_user)"
	// Αμετάβλητα (μόνο superuser) — δεν χρειάζεται ποτέ ενημέρωση/διαγραφή από client.
	g.updateRule = null
	g.deleteRule = null

	app.save(g)

}, (app) => {
	// ── DOWN ────────────────────────────────────────────────────────────────
	try { app.delete(app.findCollectionByNameOrId("friendship_gifts")) } catch (_) {}
})
