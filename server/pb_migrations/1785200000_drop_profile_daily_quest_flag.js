/// <reference path="../pb_data/types.d.ts" />

// ═══════════════════════════════════════════════════════════════════════════
// Κέρματα Φιλίας — νέος (απλούστερος) κανόνας δώρου: αφαιρεί το πλέον άχρηστο
// daily_quest_done_today από τα profiles.
// ═══════════════════════════════════════════════════════════════════════════
// ΠΑΛΙΟΣ κανόνας: δώρο ΜΟΝΟ αν ΚΑΙ οι δύο φίλοι είχαν ολοκληρώσει το Daily Quest
// τους εκείνη τη μέρα — γι' αυτό ο καθένας δημοσίευε τη σημαία στο προφίλ του
// (migration add_profile_daily_quest_flag) και ο άλλος την διάβαζε.
//
// ΝΕΟΣ κανόνας: ο καθένας στέλνει 1 δώρο σε ΚΑΘΕ φίλο του τη μέρα, ΧΩΡΙΣ καμία
// άλλη προϋπόθεση. Το όριο «1/μέρα ανά κατεύθυνση» το επιβάλλει ήδη ΜΟΝΟ του το
// UNIQUE index της friendship_gifts (from_user, to_user, date) — δεν χρειάζεται
// να ξέρει κανείς τι έκανε ο άλλος, οπότε η σημαία δεν διαβάζεται πουθενά πια
// (βλ. PlayerProfile.build_public_profile + friends_popup.gd).
//
// ΣΗΜ. συμβατότητας: ήδη εγκατεστημένοι ΠΑΛΙΟΙ clients στέλνουν ακόμα το πεδίο
// στο PATCH του προφίλ τους — το PocketBase αγνοεί άγνωστα πεδία, οπότε δεν
// σπάει τίποτα. Θα βλέπουν όμως πάντα «ο φίλος δεν έκανε την αποστολή» και δεν
// θα μπορούν να δωρίσουν μέχρι να ενημερωθούν στη νέα έκδοση.
migrate((app) => {
	const profiles = app.findCollectionByNameOrId("profiles")
	profiles.fields.removeByName("daily_quest_done_today")
	app.save(profiles)

}, (app) => {
	// ── DOWN: επαναφορά της σημαίας (ίδιος ορισμός με το add migration) ─────
	const profiles = app.findCollectionByNameOrId("profiles")
	profiles.fields.add(new BoolField({ name: "daily_quest_done_today" }))
	app.save(profiles)
})
