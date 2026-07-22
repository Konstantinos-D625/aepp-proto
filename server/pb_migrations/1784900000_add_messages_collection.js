/// <reference path="../pb_data/types.d.ts" />

// ═══════════════════════════════════════════════════════════════════════════
// Φάση 7 (Chat) — μηνύματα: clan chat (ομαδικό) + DM φίλων (1-προς-1).
// ═══════════════════════════════════════════════════════════════════════════
// ΕΝΑ collection `messages` με `scope` ("clan" | "dm"). Οι κανόνες διακλαδώνονται
// ανά scope. Polling πρώτα (ο client ρωτά περιοδικά created > last)· realtime/SSE
// αργότερα (Φ8), χωρίς αλλαγή σχήματος.
//
//   • clan chat: `scope="clan"`, `clan`=relation. Διαβάζει/γράφει ΜΟΝΟ μέλος της
//     συντεχνίας — έλεγχος μέσω back-relation `clan.clan_members_via_clan.user`.
//   • DM:        `scope="dm"`, `recipient`=relation + `dm_key` (canonical "min_max"
//     των δύο user ids για γρήγορο fetch συνομιλίας). Διαβάζει ΜΟΝΟ ο αποστολέας ή
//     ο παραλήπτης (απλός, σίγουρα-σωστός κανόνας — καμία διαρροή σε τρίτους).
//
// ΠΑΓΙΔΕΣ PocketBase:
//   • v0.39: typed fields ΜΟΝΟ με fields.add() (το `fields:[...]` αγνοείται).
//   • updateRule = **null** ⇒ κλειδωμένο (μόνο superuser)· "" (κενό string) θα
//     σήμαινε ΔΗΜΟΣΙΟ! Τα μηνύματα είναι αμετάβλητα.
//   • Το `@collection`/back-relation correlation επαληθεύεται με ΑΡΝΗΤΙΚΑ REST
//     tests (outsider δεν διαβάζει clan chat· τρίτος δεν διαβάζει DM).
//
// ΓΝΩΣΤΟΣ ΠΕΡΙΟΡΙΣΜΟΣ (→ Φ8 hardening): το createRule του DM ΔΕΝ επιβάλλει ακόμη
// «πρέπει να είστε φίλοι» server-side (η ανάγνωση όμως είναι πλήρως κλειδωμένη στα
// δύο μέρη). Ο client ανοίγει DM μόνο από τη λίστα φίλων.
migrate((app) => {
	const users = app.findCollectionByNameOrId("users")
	const clans = app.findCollectionByNameOrId("clans")

	const msg = new Collection({ type: "base", name: "messages" })

	msg.fields.add(new RelationField({
		name: "sender",
		required: true,
		maxSelect: 1,
		collectionId: users.id,
		cascadeDelete: true,
	}))
	// Denormalized όνομα αποστολέα (εμφάνιση bubble χωρίς lookup).
	msg.fields.add(new TextField({ name: "sender_name", required: true, max: 20 }))
	msg.fields.add(new TextField({ name: "text", required: true, max: 500 }))
	msg.fields.add(new SelectField({
		name: "scope",
		required: true,
		maxSelect: 1,
		values: ["clan", "dm"],
	}))
	// clan chat: σε ποια συντεχνία ανήκει το μήνυμα.
	msg.fields.add(new RelationField({
		name: "clan",
		required: false,
		maxSelect: 1,
		collectionId: clans.id,
		cascadeDelete: true,
	}))
	// DM: ο άλλος συνομιλητής.
	msg.fields.add(new RelationField({
		name: "recipient",
		required: false,
		maxSelect: 1,
		collectionId: users.id,
		cascadeDelete: true,
	}))
	// DM: canonical "min_max" των δύο user ids ⇒ ένα κλειδί συνομιλίας ανεξ. φοράς.
	msg.fields.add(new TextField({ name: "dm_key", max: 60 }))
	msg.fields.add(new AutodateField({ name: "created", onCreate: true }))

	// Indexes για pagination/polling (μη μοναδικά).
	msg.indexes = [
		"CREATE INDEX `idx_msg_clan` ON `messages` (`clan`, `created`)",
		"CREATE INDEX `idx_msg_dm` ON `messages` (`dm_key`, `created`)",
	]

	// ── Κανόνες ──────────────────────────────────────────────────────────────
	// Ανάγνωση: DM → μόνο τα δύο μέρη· clan → μόνο μέλος της συντεχνίας.
	const readRule =
		"(scope = 'dm' && (sender = @request.auth.id || recipient = @request.auth.id))" +
		" || (scope = 'clan' && clan.clan_members_via_clan.user ?= @request.auth.id)"
	msg.listRule = readRule
	msg.viewRule = readRule

	// Δημιουργία: πάντα ως ο ίδιος ο αποστολέας· DM με έγκυρο παραλήπτη· clan μόνο
	// αν είσαι μέλος της συντεχνίας.
	msg.createRule =
		"@request.auth.id = sender && (" +
		"  (scope = 'dm' && recipient != '' && recipient != sender)" +
		"  || (scope = 'clan' && clan.clan_members_via_clan.user ?= @request.auth.id)" +
		")"

	// Αμετάβλητα (μόνο superuser). Ο αποστολέας μπορεί να σβήσει δικό του μήνυμα.
	msg.updateRule = null
	msg.deleteRule = "sender = @request.auth.id"

	app.save(msg)

}, (app) => {
	// ── DOWN ────────────────────────────────────────────────────────────────
	try { app.delete(app.findCollectionByNameOrId("messages")) } catch (_) {}
})
