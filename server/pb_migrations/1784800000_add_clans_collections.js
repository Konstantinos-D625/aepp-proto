/// <reference path="../pb_data/types.d.ts" />

// ═══════════════════════════════════════════════════════════════════════════
// Φάση 6 (Clans) — συντεχνίες παικτών με μοντέλο αίτημα → έγκριση.
// ═══════════════════════════════════════════════════════════════════════════
// Δύο collections:
//   • `clans`         — η ίδια η συντεχνία (όνομα/περιγραφή + αρχηγός/owner).
//   • `clan_members`  — μέλη ΚΑΙ αιτήματα συμμετοχής (status "pending"|"member").
//
// Μοντέλο (αντικατοπτρίζει το friendships): ο παίκτης ζητά να μπει σε μια clan →
// δημιουργεί clan_members με status="pending"· ο ΑΡΧΗΓΟΣ (clans.owner) εγκρίνει
// (status="member") ή απορρίπτει (delete). Η δύναμη πηγάζει ΠΑΝΤΑ από το
// `clans.owner` — το `role` είναι μόνο για εμφάνιση.
//
// ΕΝΑ clan ανά παίκτη: unique index στο `user` του clan_members ⇒ δεν μπορείς να
// έχεις δεύτερη σχέση (ούτε δεύτερο εκκρεμές αίτημα) ενώ ανήκεις/ζητάς αλλού.
//
// ΣΗΜ. (ίδιες παγίδες v0.39 από τα προηγούμενα migrations):
//   1) typed fields ΜΟΝΟ με fields.add() — το `fields:[...]` στον constructor
//      αγνοείται σιωπηλά.
//   2) τα base collections ΔΕΝ έχουν αυτόματα `created`/`updated` — τα προσθέτουμε
//      ρητά ως AutodateField, ώστε το sort=-created να ΜΗΝ γυρίζει 400 (το bug
//      που χάλασε τη λίστα φίλων στη Φ5).
//
// ΚΑΝΟΝΕΣ ΑΣΦΑΛΕΙΑΣ (clan_members) — χρησιμοποιούν nested relation `clan.owner`:
//   • create: ο ίδιος ο χρήστης, ΚΑΙ είτε ζητά (status='pending') είτε είναι ο
//     αρχηγός (leader self-add στη δημιουργία). Έτσι κανείς δεν αυτο-εγκρίνεται
//     ως 'member' σε ξένη clan.
//   • update: μόνο ο αρχηγός (έγκριση pending→member).
//   • delete: ο ίδιος (αποχώρηση) Ή ο αρχηγός (kick / disband μέσω cascade).
migrate((app) => {
	const users = app.findCollectionByNameOrId("users")

	// ── 1) clans ────────────────────────────────────────────────────────────
	const clans = new Collection({ type: "base", name: "clans" })

	clans.fields.add(new TextField({
		name: "name",
		required: true,
		min: 3,
		max: 24,
	}))
	clans.fields.add(new TextField({ name: "description", max: 120 }))
	clans.fields.add(new RelationField({
		name: "owner",
		required: true,
		maxSelect: 1,
		collectionId: users.id,
		cascadeDelete: true,   // σβήνεται ο λογαριασμός του αρχηγού → σβήνει η clan
	}))
	// Denormalized όνομα αρχηγού (εμφάνιση χωρίς lookup στο κλειδωμένο users).
	clans.fields.add(new TextField({ name: "owner_name", required: true, max: 20 }))
	clans.fields.add(new AutodateField({ name: "created", onCreate: true }))
	clans.fields.add(new AutodateField({ name: "updated", onCreate: true, onUpdate: true }))

	// Μοναδικό όνομα clan (case-insensitive).
	clans.indexes = [
		"CREATE UNIQUE INDEX `idx_clans_name` ON `clans` (`name` COLLATE NOCASE)",
	]

	// Κάθε συνδεδεμένος βλέπει/ψάχνει clans· δημιουργεί/αλλάζει/σβήνει μόνο ο owner.
	clans.listRule   = "@request.auth.id != ''"
	clans.viewRule   = "@request.auth.id != ''"
	clans.createRule = "@request.auth.id != '' && owner = @request.auth.id"
	clans.updateRule = "owner = @request.auth.id"
	clans.deleteRule = "owner = @request.auth.id"

	app.save(clans)

	// ── 2) clan_members ─────────────────────────────────────────────────────
	const members = new Collection({ type: "base", name: "clan_members" })

	members.fields.add(new RelationField({
		name: "clan",
		required: true,
		maxSelect: 1,
		collectionId: clans.id,
		cascadeDelete: true,   // disband clan → σβήνουν όλα τα μέλη
	}))
	members.fields.add(new RelationField({
		name: "user",
		required: true,
		maxSelect: 1,
		collectionId: users.id,
		cascadeDelete: true,
	}))
	// Denormalized ονόματα (λίστα μελών & αιτημάτων χωρίς επιπλέον lookups).
	members.fields.add(new TextField({ name: "username", required: true, max: 20 }))
	members.fields.add(new TextField({ name: "clan_name", required: true, max: 24 }))
	members.fields.add(new SelectField({
		name: "role",
		required: true,
		maxSelect: 1,
		values: ["leader", "member"],
	}))
	members.fields.add(new SelectField({
		name: "status",
		required: true,
		maxSelect: 1,
		values: ["pending", "member"],
	}))
	members.fields.add(new AutodateField({ name: "created", onCreate: true }))

	// ΕΝΑ membership ανά χρήστη ⇒ ένα clan (ή ένα εκκρεμές αίτημα) τη φορά.
	members.indexes = [
		"CREATE UNIQUE INDEX `idx_clan_member_user` ON `clan_members` (`user`)",
	]

	// Οποιοσδήποτε συνδεδεμένος διαβάζει μέλη/αιτήματα (roster & έγκριση από αρχηγό).
	members.listRule   = "@request.auth.id != ''"
	members.viewRule   = "@request.auth.id != ''"
	// Ο ίδιος ο χρήστης, ΚΑΙ (ζητά ως pending) Ή (είναι ο αρχηγός της clan).
	members.createRule = "@request.auth.id = user && (status = 'pending' || clan.owner = @request.auth.id)"
	// Έγκριση pending→member: μόνο ο αρχηγός.
	members.updateRule = "clan.owner = @request.auth.id"
	// Αποχώρηση (ο ίδιος) ή kick (ο αρχηγός).
	members.deleteRule = "@request.auth.id = user || clan.owner = @request.auth.id"

	app.save(members)

}, (app) => {
	// ── DOWN (σβήσε πρώτα τα μέλη — έχουν relation προς τα clans) ─────────────
	try { app.delete(app.findCollectionByNameOrId("clan_members")) } catch (_) {}
	try { app.delete(app.findCollectionByNameOrId("clans")) } catch (_) {}
})
