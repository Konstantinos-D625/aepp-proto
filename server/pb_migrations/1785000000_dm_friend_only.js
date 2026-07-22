/// <reference path="../pb_data/types.d.ts" />

// ═══════════════════════════════════════════════════════════════════════════
// Φάση 8 (hardening) — friend-only DM: κλείνει τον γνωστό περιορισμό της Φ7.
// ═══════════════════════════════════════════════════════════════════════════
// Μέχρι τώρα το createRule των μηνυμάτων άφηνε ΟΠΟΙΟΝΔΗΠΟΤΕ συνδεδεμένο να στείλει
// DM σε οποιονδήποτε (ο περιορισμός «μόνο φίλοι» ήταν μόνο client-side). Η ΑΝΑΓΝΩΣΗ
// ήταν ήδη πλήρως κλειδωμένη στα δύο μέρη — άρα καμία διαρροή — αλλά ένας κακόβουλος
// client μπορούσε να «σπρώξει» ανεπιθύμητο DM. Εδώ επιβάλλουμε server-side ότι
// υπάρχει ΑΠΟΔΕΚΤΗ (`accepted`) φιλία μεταξύ αποστολέα και παραλήπτη.
//
// ΣΥΣΧΕΤΙΣΗ (το κρίσιμο σημείο): θέλουμε «υπάρχει ΜΙΑ friendship row F όπου
//   status='accepted' ΚΑΙ ( (requester=sender ΚΑΙ addressee=recipient)
//                            Ή (requester=recipient ΚΑΙ addressee=sender) )».
// Στο PocketBase, πολλαπλές συνθήκες πάνω στο ΙΔΙΟ `@collection.friendships`
// (χωρίς alias, ή με το ΙΔΙΟ alias) συγχωνεύονται σε ΕΝΑ join → συσχετίζονται στην
// ΙΔΙΑ row. Για τις δύο ΚΑΤΕΥΘΥΝΣΕΙΣ (που είναι διαφορετικές rows) χρησιμοποιούμε
// ΔΙΑΦΟΡΕΤΙΚΑ aliases (:fa, :fb). Ο τελεστής `?=` = «τουλάχιστον μία row ταιριάζει».
// Επαληθεύεται με ΑΡΝΗΤΙΚΑ REST tests (μη-φίλος 400, pending 400, φίλος-με-άλλον 400).
//
// Η ανάγνωση/ενημέρωση/διαγραφή μένουν ΑΚΡΙΒΩΣ όπως στη Φ7 (δεν τα ξαναγράφουμε).
migrate((app) => {
	const msg = app.findCollectionByNameOrId("messages")

	msg.createRule =
		"@request.auth.id = sender && (" +
		"  (scope = 'dm' && recipient != '' && recipient != sender && (" +
		"     (@collection.friendships:fa.status ?= 'accepted'" +
		"      && @collection.friendships:fa.requester ?= sender" +
		"      && @collection.friendships:fa.addressee ?= recipient)" +
		"     || (@collection.friendships:fb.status ?= 'accepted'" +
		"      && @collection.friendships:fb.requester ?= recipient" +
		"      && @collection.friendships:fb.addressee ?= sender)" +
		"  ))" +
		"  || (scope = 'clan' && clan.clan_members_via_clan.user ?= @request.auth.id)" +
		")"

	app.save(msg)

}, (app) => {
	// ── DOWN: επαναφορά του createRule της Φ7 (DM χωρίς friend-only έλεγχο) ────
	const msg = app.findCollectionByNameOrId("messages")
	msg.createRule =
		"@request.auth.id = sender && (" +
		"  (scope = 'dm' && recipient != '' && recipient != sender)" +
		"  || (scope = 'clan' && clan.clan_members_via_clan.user ?= @request.auth.id)" +
		")"
	app.save(msg)
})
