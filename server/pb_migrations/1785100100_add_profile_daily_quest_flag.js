/// <reference path="../pb_data/types.d.ts" />

// ═══════════════════════════════════════════════════════════════════════════
// Φάση 9 (Κέρματα Φιλίας) — προσθέτει daily_quest_done_today στα profiles.
// ═══════════════════════════════════════════════════════════════════════════
// ⚠ ΞΕΠΕΡΑΣΜΕΝΟ: το πεδίο αυτό αφαιρέθηκε ξανά από το επόμενο migration
// (drop_profile_daily_quest_flag) — ο κανόνας του δώρου δεν εξαρτάται πλέον από
// το Daily Quest κανενός. Μένει εδώ αναλλοίωτο γιατί έχει ήδη εφαρμοστεί· η
// περιγραφή παρακάτω αφορά την τότε λογική.
// Το FriendsPopup χρειάζεται να ξέρει ΑΝ ένας φίλος έχει ολοκληρώσει το Daily
// Quest ΤΟΥ σήμερα, ώστε να ενεργοποιήσει το κουμπί δώρου Κέρματος Φιλίας μόνο
// όταν ισχύει και για τους δύο (βλ. PlayerProfile.build_public_profile() και
// friends_popup.gd). Ίδιο μοτίβο με τα υπόλοιπα πεδία του profiles (Φ1) — απλό
// στιγμιότυπο, ΧΩΡΙΣ φόρμουλα server-side.
migrate((app) => {
	const profiles = app.findCollectionByNameOrId("profiles")
	profiles.fields.add(new BoolField({ name: "daily_quest_done_today" }))
	app.save(profiles)

}, (app) => {
	// ── DOWN ────────────────────────────────────────────────────────────────
	const profiles = app.findCollectionByNameOrId("profiles")
	profiles.fields.removeByName("daily_quest_done_today")
	app.save(profiles)
})
