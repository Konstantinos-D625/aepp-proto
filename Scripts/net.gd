extends Node

# ═══════════════════════════════════════════════════════════════════════════
# Net (Autoload) — wrapper του HTTPRequest για το PocketBase backend
# ═══════════════════════════════════════════════════════════════════════════
# Φάση 2 της online επέκτασης. ΚΑΘΑΡΟ επίπεδο δικτύου — ΚΑΜΙΑ γνώση UI ή
# gameplay. Απλώς μιλάει στο REST API του server (βλ. server/README.md):
#
#   POST /api/collections/users/records            → register (username+password)
#   POST /api/collections/users/auth-with-password → login  (επιστρέφει token)
#   POST /api/collections/users/auth-refresh       → ανανέωση/έλεγχος token
#   POST|PATCH /api/collections/profiles/records   → ανέβασμα δημόσιου προφίλ
#   GET  /api/collections/profiles/records         → ανάγνωση προφίλ
#
# ΣΧΕΔΙΑΣΜΟΣ:
#   • Κάθε κλήση φτιάχνει ΝΕΟ HTTPRequest node (ένα HTTPRequest = ένα αίτημα τη
#     φορά· έτσι αποφεύγουμε τον περιορισμό και μπορούν να τρέξουν και παράλληλα).
#   • Όλες οι public μέθοδοι είναι coroutines: `var res = await Net.login(...)`.
#     Επιστρέφουν πάντα το ίδιο σχήμα: {ok:bool, status:int, data:Dictionary, error:String}.
#   • Το session (token/user_id/username + base_url) αποθηκεύεται σε ΞΕΧΩΡΙΣΤΟ
#     user://net.cfg — ΔΕΝ μπλέκεται με το game save (GameData -> game_data.cfg).
#
# ΤΙ ΔΕΝ κάνει εδώ (επόμενες φάσεις): οθόνες auth (Φ3), το ΠΟΤΕ γίνεται sync (Φ4),
# φίλοι/clans/chat (Φ5-7). Αυτό το autoload παρέχει μόνο τα «τούβλα».
#
# ΑΣΦΑΛΕΙΑ: το token μένει plaintext στο user://net.cfg — αποδεκτό για το υβριδικό,
# χαμηλού ρίσκου εκπαιδευτικό παιχνίδι (single-user desktop). Φ8 hardening: το token
# ΔΕΝ στέλνεται ΠΟΤΕ σε απομακρυσμένο host χωρίς HTTPS (_is_transport_secure_for_auth).

## Εκπέμπεται σε κάθε αλλαγή κατάστασης σύνδεσης (για το UI της Φάσης 3).
signal auth_changed(logged_in: bool)

## Εκπέμπεται όταν ολοκληρωθεί ο συγχρονισμός μετά τη σύνδεση (Φάση 4).
## applied_remote == true σημαίνει ότι επαναφέρθηκε το cloud save πάνω στο τοπικό.
signal sync_completed(applied_remote: bool)

const CONFIG_PATH := "user://net.cfg"
## Χρόνος «ηρεμίας» πριν το auto-push στο cloud — συγκεντρώνει πολλές διαδοχικές
## τοπικές αποθηκεύσεις (π.χ. αγορές) σε ένα αίτημα δικτύου.
const PUSH_DEBOUNCE := 4.0
## Ο τοπικός dev server. Άλλαξέ τον με set_base_url() για το Oracle (Φάση deploy).
const DEFAULT_BASE_URL := "http://127.0.0.1:8090"
## Χρονικό όριο κάθε κανονικού αιτήματος — να μην κρεμάει το UI αν πέσει ο server.
const REQUEST_TIMEOUT := 15.0
## Ανώτατο όριο αναμονής για το flush-on-quit: όσο κι αν αργεί το τελευταίο push,
## το παιχνίδι κλείνει το πολύ μέσα σε τόσο (Φάση 5 leftover από Φ4).
const FLUSH_TIMEOUT := 4.0

var base_url := DEFAULT_BASE_URL
var _token := ""
var _user_id := ""
var _username := ""
## Ο χρήστης διάλεξε ρητά «Παίξε offline» → μην ξαναδείχνεις το auth popup (Φάση 3).
var _offline_chosen := false
## Guard για το debounced auto-push (Φάση 4): true όσο εκκρεμεί ένα push.
var _push_pending := false


func _ready() -> void:
	_load_session()
	# Φάση 4: κάθε τοπική αποθήκευση προγραμματίζει (debounced) auto-push στο cloud.
	GameData.saved.connect(_on_local_saved)
	# Φάση 5 (flush-on-quit): παρεμβαίνουμε στο κλείσιμο του παραθύρου ώστε να
	# προλάβει να ανέβει η τελευταία αποθήκευση πριν τερματίσει το παιχνίδι.
	# Δες _notification / _flush_and_quit.
	get_tree().set_auto_accept_quit(false)


## Φάση 5: όταν ο χρήστης κλείσει το παράθυρο, κάνε ΣΥΓΧΡΟΝΟ flush της τελευταίας
## αποθήκευσης πριν τον τερματισμό (αλλιώς μια αγορά μέσα στα 4s του debounce
## θα χανόταν). Δουλεύει και ως autoload — το NOTIFICATION φτάνει στο root.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush_and_quit()


## Ανεβάζει την τελευταία κατάσταση και μετά κλείνει. Δίχτυ ασφαλείας: ό,τι κι αν
## συμβεί (server down/αργός), το παιχνίδι κλείνει το πολύ μέσα σε FLUSH_TIMEOUT.
func _flush_and_quit() -> void:
	# Force-quit safety net — τρέχει παράλληλα με το push· όποιο τελειώσει πρώτο.
	get_tree().create_timer(FLUSH_TIMEOUT).timeout.connect(get_tree().quit)
	if is_logged_in():
		await push_save()
	get_tree().quit()


# ═══════════════════════════════════════════════════════════════════════════
# ΚΑΤΑΣΤΑΣΗ ΣΥΝΔΕΣΗΣ
# ═══════════════════════════════════════════════════════════════════════════

func is_logged_in() -> bool:
	return _token != "" and _user_id != ""

## Υπάρχει αποθηκευμένο token από προηγούμενη συνεδρία (πριν την επικύρωση);
## Το UI της Φάσης 3 το χρησιμοποιεί για να αποφασίσει αν θα κάνει σιωπηλό
## refresh_auth() στην εκκίνηση αντί να δείξει την οθόνη σύνδεσης.
func has_saved_session() -> bool:
	return _token != ""

## Ο παίκτης πάτησε «Παίξε offline» — το θυμόμαστε ώστε το popup να μην ενοχλεί
## ξανά. Η σύνδεση παραμένει διαθέσιμη αργότερα μέσα από την οθόνη προφίλ.
func choose_offline() -> void:
	_offline_chosen = true
	_save_session()

## Έχει διαλέξει ρητά offline ο παίκτης;
func has_chosen_offline() -> bool:
	return _offline_chosen

## Πρέπει η εκκίνηση να δείξει το auth popup; (ούτε συνδεδεμένος ούτε επέλεξε offline)
func should_prompt_auth() -> bool:
	return not is_logged_in() and not _offline_chosen

func get_user_id() -> String:
	return _user_id

func get_username() -> String:
	return _username

## Αλλαγή διεύθυνσης server (π.χ. στο production URL του Oracle). Διατηρείται.
func set_base_url(url: String) -> void:
	base_url = url.strip_edges().trim_suffix("/")
	_save_session()


# ═══════════════════════════════════════════════════════════════════════════
# AUTH
# ═══════════════════════════════════════════════════════════════════════════

## Δημιουργία λογαριασμού (χωρίς email). ΔΕΝ συνδέει αυτόματα — κάλεσε login μετά.
func register(username: String, password: String) -> Dictionary:
	var body := {
		"username": username,
		"password": password,
		"passwordConfirm": password,
	}
	return await _request(HTTPClient.METHOD_POST, "/api/collections/users/records", body, false)

## Σύνδεση με username+password. Σε επιτυχία κρατά+αποθηκεύει το token.
func login(username: String, password: String) -> Dictionary:
	var body := {"identity": username, "password": password}
	var res := await _request(HTTPClient.METHOD_POST, "/api/collections/users/auth-with-password", body, false)
	if res["ok"]:
		_apply_auth(res["data"])
	return res

## Ανανέωση/επικύρωση αποθηκευμένου token κατά την εκκίνηση. Αν είναι άκυρο
## (π.χ. έληξε), αποσυνδέει καθαρά.
func refresh_auth() -> Dictionary:
	if _token == "":
		return _fail("not_logged_in")
	var res := await _request(HTTPClient.METHOD_POST, "/api/collections/users/auth-refresh", null, true)
	if res["ok"]:
		_apply_auth(res["data"])
	else:
		# Άκυρο token Ή προσωρινά offline server: καθάρισε μόνο το session — ΜΗΝ
		# κάνεις flush (θα 401) και ΜΗΝ σβήσεις την τοπική πρόοδο (reset_local=false).
		logout(false, false)
	return res

## Αποσύνδεση — σβήνει το τοπικό session (το token του PocketBase είναι stateless).
##  • flush=true: ανεβάζει πρώτα την τελευταία αποθήκευση (πριν χαθεί το token),
##    ώστε μια αγορά μέσα στο παράθυρο debounce να μη χαθεί στην αποσύνδεση.
##  • reset_local=true (Φάση 5, anti-cheat): μηδενίζει το ΤΟΠΙΚΟ save και
##    ξαναφορτώνει το τρέχον scene από την αρχή, ώστε ο επόμενος παίκτης να ΜΗΝ
##    κληρονομεί τα δεδομένα του αποσυνδεδεμένου (βλ. GameData.reset_to_new_game).
## Το refresh-failure στην εκκίνηση καλεί logout(false, false): άκυρο token ή
## προσωρινά offline server ΔΕΝ πρέπει ΠΟΤΕ να σβήνει την τοπική πρόοδο.
func logout(flush := true, reset_local := true) -> void:
	if flush and is_logged_in():
		await push_save()
	_token = ""
	_user_id = ""
	_username = ""
	_save_session()
	auth_changed.emit(false)
	if reset_local:
		# Καθάρισε το save ΠΡΙΝ το reload· το token έχει ήδη σβηστεί, οπότε οι
		# `saved` εκπομπές του reset δεν θα κάνουν push (auto-push guard).
		GameData.reset_to_new_game()
		get_tree().reload_current_scene()


# ═══════════════════════════════════════════════════════════════════════════
# GDPR (Φάση 8) — «δικαίωμα στη λήθη»
# ═══════════════════════════════════════════════════════════════════════════

## Διαγράφει ΟΡΙΣΤΙΚΑ τον λογαριασμό του χρήστη από τον server. Το cascadeDelete σε
## όλα τα relations→users σβήνει αυτόματα ΚΑΙ τα εξαρτημένα δεδομένα: το δημόσιο
## profile, το cloud save, τις φιλίες, τη συμμετοχή/ιδιοκτησία clan, και όλα τα
## μηνύματα (sender/recipient). Σε επιτυχία αποσυνδέει και μηδενίζει το ΤΟΠΙΚΟ save
## (πλήρης «λήθη» — γυρνά στην οθόνη πρώτης εκκίνησης).
##
## ΠΡΟΣΟΧΗ (UI): μη ζητηθεί χωρίς ρητή επιβεβαίωση — είναι μη αναστρέψιμο.
func delete_account() -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var res := await _request(HTTPClient.METHOD_DELETE,
		"/api/collections/users/records/" + _user_id, null, true)
	if res["ok"]:
		# flush=false: ο λογαριασμός δεν υπάρχει πλέον — τυχόν push θα 404.
		# reset_local=true: καθάρισε την τοπική πρόοδο και γύρνα στην αρχή.
		logout(false, true)
	return res


# ═══════════════════════════════════════════════════════════════════════════
# PROFILES (δημόσιο στιγμιότυπο προόδου)
# ═══════════════════════════════════════════════════════════════════════════

## Ανεβάζει το PlayerProfile.build_public_profile() στον server (upsert: PATCH αν
## υπάρχει ήδη profile για τον χρήστη, αλλιώς POST). Το ΠΟΤΕ καλείται ορίζεται
## στη Φάση 4 (cloud sync).
func push_profile() -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var payload := PlayerProfile.build_public_profile()
	payload["user"] = _user_id
	payload["username"] = _username

	var existing := await _find_own_profile_id()
	if existing != "":
		return await _request(HTTPClient.METHOD_PATCH, "/api/collections/profiles/records/" + existing, payload, true)
	return await _request(HTTPClient.METHOD_POST, "/api/collections/profiles/records", payload, true)

## Το profile ενός συγκεκριμένου χρήστη (για μελλοντική προβολή φίλων).
func fetch_profile(user_id: String) -> Dictionary:
	var q := 'user="%s"' % user_id
	return await _request(HTTPClient.METHOD_GET, "/api/collections/profiles/records?perPage=1&filter=" + q.uri_encode(), null, true)

## Λίστα προφίλ (για μελλοντική κατάταξη/φίλους). Δέχεται προαιρετικά PocketBase
## query params (π.χ. "sort=-streak&perPage=20").
func fetch_profiles(query: String = "") -> Dictionary:
	var path := "/api/collections/profiles/records"
	if query != "":
		path += "?" + query
	return await _request(HTTPClient.METHOD_GET, path, null, true)


# ═══════════════════════════════════════════════════════════════════════════
# FRIENDS (Φάση 5) — αίτημα → αποδοχή, πάνω από τη συλλογή `friendships`
# ═══════════════════════════════════════════════════════════════════════════
# Το UI (FriendsPopup) κάθεται πάνω από αυτά· εδώ μόνο τα «τούβλα» δικτύου.

## Αναζήτηση παικτών με μερικό username (case-insensitive) μέσα στα ΔΗΜΟΣΙΑ
## profiles. Επιστρέφει το τυπικό σχήμα· τα items έχουν {user, username, region_
## label, streak, …}. Κενή αναζήτηση → κενή λίστα χωρίς αίτημα δικτύου.
func search_users(query: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var q := query.strip_edges().replace('"', "")
	if q == "":
		return {"ok": true, "status": 200, "data": {"items": []}, "error": ""}
	var filter := 'username ~ "%s"' % q
	var path := "/api/collections/profiles/records?perPage=25&filter=" + filter.uri_encode()
	return await _request(HTTPClient.METHOD_GET, path, null, true)

## Στέλνει αίτημα φιλίας (status=pending) προς έναν παίκτη (με βάση το user id του).
func send_friend_request(target_user_id: String, target_username: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	if target_user_id == "" or target_user_id == _user_id:
		return _fail("self_friend")
	var body := {
		"requester": _user_id,
		"addressee": target_user_id,
		"requester_name": _username,
		"addressee_name": target_username,
		"status": "pending",
	}
	return await _request(HTTPClient.METHOD_POST, "/api/collections/friendships/records", body, true)

## Όλες οι σχέσεις που με αφορούν (εισερχόμενα/εξερχόμενα pending + accepted).
## Το UI ξεχωρίζει κατεύθυνση/κατάσταση συγκρίνοντας με το get_user_id().
func list_friendships() -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var filter := 'requester="%s" || addressee="%s"' % [_user_id, _user_id]
	# ΣΗΜ.: ΟΧΙ sort=-created — η συλλογή friendships δεν έχει autodate πεδίο
	# `created`, οπότε το sort θα γύριζε 400 (και δεν θα φαινόταν κανένα αίτημα).
	var path := "/api/collections/friendships/records?perPage=200&filter=" + filter.uri_encode()
	return await _request(HTTPClient.METHOD_GET, path, null, true)

## Απάντηση σε εισερχόμενο αίτημα: accept → status=accepted, αλλιώς διαγραφή.
func respond_friend_request(friendship_id: String, accept: bool) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	if accept:
		return await _request(HTTPClient.METHOD_PATCH,
			"/api/collections/friendships/records/" + friendship_id, {"status": "accepted"}, true)
	return await _request(HTTPClient.METHOD_DELETE,
		"/api/collections/friendships/records/" + friendship_id, null, true)

## Διαγραφή φιλίας ή ακύρωση εξερχόμενου αιτήματος (και οι δύο πλευρές επιτρέπονται).
func remove_friend(friendship_id: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	return await _request(HTTPClient.METHOD_DELETE,
		"/api/collections/friendships/records/" + friendship_id, null, true)


# ═══════════════════════════════════════════════════════════════════════════
# CLANS (Φάση 6) — συντεχνίες, μοντέλο αίτημα → έγκριση από τον αρχηγό
# ═══════════════════════════════════════════════════════════════════════════
# Δύο collections (βλ. migration add_clans_collections): `clans` (owner) +
# `clan_members` (μέλη & εκκρεμή αιτήματα, status pending|member). Ένα clan ανά
# παίκτη (unique index στο user). Εδώ μόνο τα «τούβλα» δικτύου· το UI (ClansPopup)
# αποφασίζει τι δείχνει βάσει της κατάστασης της συμμετοχής.

## Η δική μου εγγραφή συμμετοχής (ένα clan/αίτημα ανά παίκτη), ή {} αν καμία.
## Πάνω στο τυπικό σχήμα επιστρέφει επιπλέον {membership: Dictionary}.
func my_membership() -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var q := 'user="%s"' % _user_id
	var res := await _request(HTTPClient.METHOD_GET,
		"/api/collections/clan_members/records?perPage=1&filter=" + q.uri_encode(), null, true)
	res["membership"] = {}
	if res["ok"]:
		var items: Array = res["data"].get("items", [])
		if not items.is_empty():
			res["membership"] = items[0]
	return res

## Δημιουργία clan: φτιάχνει το clan record ΚΑΙ την εγγραφή αρχηγού (leader/member).
## Αν αποτύχει το δεύτερο βήμα, κάνει rollback το clan ώστε να μη μείνει ορφανό.
func create_clan(clan_name: String, description: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var body := {
		"name": clan_name,
		"description": description,
		"owner": _user_id,
		"owner_name": _username,
	}
	var res := await _request(HTTPClient.METHOD_POST, "/api/collections/clans/records", body, true)
	if not res["ok"]:
		return res
	var clan_id := str(res["data"].get("id", ""))
	var mres := await _request(HTTPClient.METHOD_POST, "/api/collections/clan_members/records", {
		"clan": clan_id,
		"user": _user_id,
		"username": _username,
		"clan_name": clan_name,
		"role": "leader",
		"status": "member",
	}, true)
	if not mres["ok"]:
		# rollback — cascade σβήνει και τυχόν μέλος
		await _request(HTTPClient.METHOD_DELETE, "/api/collections/clans/records/" + clan_id, null, true)
		return mres
	res["clan_id"] = clan_id
	return res

## Αναζήτηση/περιήγηση clans με μερικό όνομα (case-insensitive). Κενή αναζήτηση →
## επιστρέφει τις πιο πρόσφατες clans (για περιήγηση).
func search_clans(query: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var q := query.strip_edges().replace('"', "")
	var path := "/api/collections/clans/records?perPage=25&sort=-created"
	if q != "":
		path += "&filter=" + ('name ~ "%s"' % q).uri_encode()
	return await _request(HTTPClient.METHOD_GET, path, null, true)

## Ένα συγκεκριμένο clan record (για την κεφαλίδα/περιγραφή).
func fetch_clan(clan_id: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	return await _request(HTTPClient.METHOD_GET,
		"/api/collections/clans/records/" + clan_id, null, true)

## Όλες οι εγγραφές συμμετοχής ενός clan (μέλη + εκκρεμή αιτήματα). Το UI ξεχωρίζει
## με το `status`/`role`. Ταξινομημένα κατά χρόνο ένταξης.
func clan_members(clan_id: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var filter := 'clan="%s"' % clan_id
	var path := "/api/collections/clan_members/records?perPage=200&sort=created&filter=" + filter.uri_encode()
	return await _request(HTTPClient.METHOD_GET, path, null, true)

## Αίτημα συμμετοχής σε clan (status=pending). Ο αρχηγός θα το εγκρίνει.
func request_join_clan(clan_id: String, clan_name: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var body := {
		"clan": clan_id,
		"user": _user_id,
		"username": _username,
		"clan_name": clan_name,
		"role": "member",
		"status": "pending",
	}
	return await _request(HTTPClient.METHOD_POST, "/api/collections/clan_members/records", body, true)

## Απάντηση αρχηγού σε αίτημα: accept → status=member, αλλιώς διαγραφή.
func respond_join_request(membership_id: String, accept: bool) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	if accept:
		return await _request(HTTPClient.METHOD_PATCH,
			"/api/collections/clan_members/records/" + membership_id, {"status": "member"}, true)
	return await _request(HTTPClient.METHOD_DELETE,
		"/api/collections/clan_members/records/" + membership_id, null, true)

## Αποχώρηση από clan / ακύρωση εκκρεμούς αιτήματος (ο ίδιος) ή kick (ο αρχηγός).
func leave_clan(membership_id: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	return await _request(HTTPClient.METHOD_DELETE,
		"/api/collections/clan_members/records/" + membership_id, null, true)

## Διάλυση clan (μόνο ο αρχηγός) — cascade σβήνει όλες τις συμμετοχές.
func disband_clan(clan_id: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	return await _request(HTTPClient.METHOD_DELETE,
		"/api/collections/clans/records/" + clan_id, null, true)


# ═══════════════════════════════════════════════════════════════════════════
# CHAT (Φάση 7) — clan chat + DM φίλων, πάνω από τη συλλογή `messages`
# ═══════════════════════════════════════════════════════════════════════════
# Ένα collection `messages` με `scope` ("clan"|"dm"). Οι κανόνες του server ήδη
# κλειδώνουν την πρόσβαση (μέλος συντεχνίας / τα δύο μέρη του DM — επαληθεύτηκε με
# αρνητικά tests). Εδώ μόνο τα «τούβλα». **Polling**: το ChatPopup ρωτά περιοδικά με
# `since` = το `created` του τελευταίου μηνύματος (realtime/SSE → Φ8).
#
# Οι fetch_* επιστρέφουν τα items σε ΑΥΞΟΥΣΑ χρονική σειρά (παλιό→νέο) ώστε το UI να
# τα προσθέτει κάτω-κάτω. Το ChatPopup κάνει και dedup ανά id (ασφάλεια σε ισόχρονα).

## Canonical κλειδί DM συνομιλίας: ίδιο ανεξάρτητα από τη φορά αποστολέα/παραλήπτη.
func dm_key(user_a: String, user_b: String) -> String:
	var pair := [user_a, user_b]
	pair.sort()
	return pair[0] + "_" + pair[1]

## Στέλνει μήνυμα στο clan chat (ο server ελέγχει ότι είμαι μέλος).
func send_clan_message(clan_id: String, text: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var body := {
		"sender": _user_id,
		"sender_name": _username,
		"text": text,
		"scope": "clan",
		"clan": clan_id,
	}
	return await _request(HTTPClient.METHOD_POST, "/api/collections/messages/records", body, true)

## Στέλνει DM σε έναν παίκτη (ο client το ανοίγει μόνο από τη λίστα φίλων).
func send_dm(recipient_id: String, recipient_name: String, text: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var body := {
		"sender": _user_id,
		"sender_name": _username,
		"text": text,
		"scope": "dm",
		"recipient": recipient_id,
		"dm_key": dm_key(_user_id, recipient_id),
	}
	# denormalized όνομα παραλήπτη δεν χρειάζεται (το UI ξέρει με ποιον μιλά)· το
	# recipient_name το αγνοούμε εδώ, μένει για συμμετρία με το UI.
	recipient_name = recipient_name
	return await _request(HTTPClient.METHOD_POST, "/api/collections/messages/records", body, true)

## Μηνύματα clan chat. `since`="" → τα πιο πρόσφατα (έως 50)· αλλιώς μόνο τα νεότερα
## του `since` (για polling). Πάντα σε αύξουσα χρονική σειρά.
func fetch_clan_messages(clan_id: String, since := "") -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var filter := 'scope="clan" && clan="%s"' % clan_id
	return await _fetch_messages(filter, since)

## Μηνύματα DM με έναν συγκεκριμένο παίκτη (ίδια λογική `since`).
func fetch_dm_messages(other_user_id: String, since := "") -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var filter := 'scope="dm" && dm_key="%s"' % dm_key(_user_id, other_user_id)
	return await _fetch_messages(filter, since)

## Κοινός πυρήνας fetch· επιστρέφει items σε αύξουσα σειρά.
func _fetch_messages(filter: String, since: String) -> Dictionary:
	var path: String
	if since != "":
		# Polling: μόνο τα νεότερα. `>=` + dedup(id) στο UI αποφεύγει χαμένα ισόχρονα.
		var f := filter + ' && created>="%s"' % since
		path = "/api/collections/messages/records?perPage=200&sort=created&filter=" + f.uri_encode()
		return await _request(HTTPClient.METHOD_GET, path, null, true)
	# Αρχικό φόρτωμα: τα πιο πρόσφατα 50 (φθίνουσα) → τα αναστρέφουμε σε αύξουσα.
	path = "/api/collections/messages/records?perPage=50&sort=-created&filter=" + filter.uri_encode()
	var res := await _request(HTTPClient.METHOD_GET, path, null, true)
	if res["ok"]:
		var items: Array = res["data"].get("items", [])
		items.reverse()
		res["data"]["items"] = items
	return res

## Διαγραφή δικού μου μηνύματος (deleteRule = sender).
func delete_message(message_id: String) -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	return await _request(HTTPClient.METHOD_DELETE,
		"/api/collections/messages/records/" + message_id, null, true)


# ═══════════════════════════════════════════════════════════════════════════
# CLOUD SAVE (Φάση 4) — ΙΔΙΩΤΙΚΟ πλήρες save για cross-device restore
# ═══════════════════════════════════════════════════════════════════════════
# Ξεχωριστό από το push_profile (δημόσιο στιγμιότυπο). Το blob = ολόκληρο το
# GameData.export_save(). Ένα record ανά χρήστη (upsert), προσβάσιμο μόνο από
# τον κάτοχο (βλ. server migration «saves»).

## Ανεβάζει (upsert) ΟΛΟΚΛΗΡΟ το τοπικό save στο cloud, μαζί με το progress score.
func push_save() -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var payload := {
		"user": _user_id,
		"blob": GameData.export_save(),
		"score": GameData.progress_score(),
	}
	var existing := await _find_own_save_id()
	if existing != "":
		return await _request(HTTPClient.METHOD_PATCH, "/api/collections/saves/records/" + existing, payload, true)
	return await _request(HTTPClient.METHOD_POST, "/api/collections/saves/records", payload, true)

## Κατεβάζει το cloud save του χρήστη. Επιστρέφει επιπλέον
## {has_save:bool, blob:Dictionary, score:int} πάνω στο τυπικό σχήμα.
func pull_save() -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var q := 'user="%s"' % _user_id
	var res := await _request(HTTPClient.METHOD_GET, "/api/collections/saves/records?perPage=1&filter=" + q.uri_encode(), null, true)
	res["has_save"] = false
	res["blob"] = {}
	res["score"] = 0
	if res["ok"]:
		var items: Array = res["data"].get("items", [])
		if not items.is_empty():
			var rec: Dictionary = items[0]
			res["has_save"] = true
			res["score"] = int(rec.get("score", 0))
			var b = rec.get("blob", {})
			res["blob"] = b if b is Dictionary else {}
	return res

## Καλείται αυτόματα μετά από κάθε επιτυχή σύνδεση (login/startup refresh).
## Απόφαση «ποιο κερδίζει»: κερδίζει το ΜΕΓΑΛΥΤΕΡΟ progress_score (ο παίκτης δεν
## χάνει ποτέ το πιο προχωρημένο του save). Ισοπαλία/τοπικό μπροστά → backup στο
## cloud· cloud μπροστά → restore στο τοπικό (import_save).
func sync_on_login() -> Dictionary:
	if not is_logged_in():
		return _fail("not_logged_in")
	var pull := await pull_save()
	if not pull["ok"]:
		return pull
	var applied := false
	if not pull["has_save"]:
		await push_save()                       # πρώτη φορά — ανέβασε το τοπικό
	elif GameData.score_of(pull["blob"]) > GameData.progress_score():
		GameData.import_save(pull["blob"])      # cloud πιο προχωρημένο → restore
		applied = true
	else:
		await push_save()                       # τοπικό ίσο/μπροστά → backup
	# Φάση 5: ανέβασε και το ΔΗΜΟΣΙΟ στιγμιότυπο (profiles) ώστε να μας βρίσκουν
	# στην αναζήτηση φίλων και να βλέπουν την τρέχουσα πρόοδό μας.
	await push_profile()
	sync_completed.emit(applied)
	return {"ok": true, "status": 200, "data": {}, "error": "", "applied_remote": applied}


# ═══════════════════════════════════════════════════════════════════════════
# ΕΣΩΤΕΡΙΚΑ
# ═══════════════════════════════════════════════════════════════════════════

## Debounced auto-push: μαζεύει διαδοχικές τοπικές αποθηκεύσεις σε ένα αίτημα.
func _on_local_saved() -> void:
	if not is_logged_in() or _push_pending:
		return
	_push_pending = true
	await get_tree().create_timer(PUSH_DEBOUNCE).timeout
	_push_pending = false
	if is_logged_in():
		await push_save()
		# Φάση 5: κράτα φρέσκο και το δημόσιο προφίλ (φίλοι/αναζήτηση/κατάταξη).
		await push_profile()

## Το id του δικού μας save record, ή "" αν δεν υπάρχει ακόμα.
func _find_own_save_id() -> String:
	var res := await pull_save()
	if res["ok"] and res["has_save"]:
		var items: Array = res["data"].get("items", [])
		if not items.is_empty():
			return str(items[0].get("id", ""))
	return ""

## Το id του δικού μας profile, ή "" αν δεν υπάρχει ακόμα.
func _find_own_profile_id() -> String:
	var res := await fetch_profile(_user_id)
	if res["ok"]:
		var items: Array = res["data"].get("items", [])
		if not items.is_empty():
			return str(items[0].get("id", ""))
	return ""

## Κρατά token+record από μια απάντηση auth-with-password / auth-refresh.
func _apply_auth(data: Dictionary) -> void:
	_token = str(data.get("token", ""))
	var rec: Dictionary = data.get("record", {})
	_user_id = str(rec.get("id", ""))
	_username = str(rec.get("username", ""))
	_save_session()
	auth_changed.emit(is_logged_in())
	# Φάση 4: μόλις συνδεθούμε (login ή startup refresh) συγχρονίζουμε το save.
	# Fire-and-forget — δεν μπλοκάρει την επιστροφή του login/refresh_auth.
	if is_logged_in():
		sync_on_login()

## Ο πυρήνας: στέλνει ένα HTTP αίτημα και επιστρέφει τυποποιημένο αποτέλεσμα.
## body == null => κενό σώμα (για GET). use_auth => βάζει το Authorization header.
func _request(method: int, path: String, body, use_auth: bool) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)

	var headers := PackedStringArray(["Content-Type: application/json"])
	if use_auth and _token != "":
		# Ασφάλεια μεταφοράς (Φ8): μη στέλνεις ΠΟΤΕ το token σε απομακρυσμένο host
		# χωρίς HTTPS — θα ταξίδευε σε καθαρό κείμενο και θα μπορούσε να υποκλαπεί.
		if not _is_transport_secure_for_auth():
			http.queue_free()
			push_warning("Net: μπλοκαρίστηκε authed αίτημα σε μη ασφαλή μεταφορά (%s)" % base_url)
			return _fail("insecure_transport")
		headers.append("Authorization: " + _token)

	var body_str := "" if body == null else JSON.stringify(body)
	var err := http.request(base_url + path, headers, method, body_str)
	if err != OK:
		http.queue_free()
		return _fail("request_failed:%d" % err)

	var result: Array = await http.request_completed
	http.queue_free()

	# result = [result_code, response_code, headers, body(PackedByteArray)]
	var response_code: int = result[1]
	var raw: String = result[3].get_string_from_utf8()
	var data: Dictionary = {}
	if raw != "":
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary:
			data = parsed
	var ok := response_code >= 200 and response_code < 300
	var error := ""
	if not ok:
		error = str(data.get("message", "http_%d" % response_code))
	return {"ok": ok, "status": response_code, "data": data, "error": error}

## Τυποποιημένη αποτυχία χωρίς δικτυακό αίτημα (validation κ.λπ.).
func _fail(msg: String) -> Dictionary:
	return {"ok": false, "status": 0, "data": {}, "error": msg}

## Ασφάλεια μεταφοράς (Φ8): το auth token επιτρέπεται να σταλεί μόνο μέσω HTTPS, ή
## μέσω http ΜΟΝΟ σε loopback (τοπικός dev server). Έτσι ένα λάθος στο production URL
## (http:// αντί για https://) δεν διαρρέει ποτέ το token σε καθαρό κείμενο στο δίκτυο.
func _is_transport_secure_for_auth() -> bool:
	if base_url.begins_with("https://"):
		return true
	# http:// επιτρέπεται ΜΟΝΟ σε loopback (τοπικός dev server).
	var host := base_url.trim_prefix("http://").split("/")[0].split(":")[0].to_lower()
	return host == "127.0.0.1" or host == "localhost"


# ═══════════════════════════════════════════════════════════════════════════
# SESSION PERSISTENCE (ConfigFile — ίδιο μοτίβο με GameData/OptionsMenu)
# ═══════════════════════════════════════════════════════════════════════════

func _load_session() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	base_url = cfg.get_value("server", "base_url", DEFAULT_BASE_URL)
	_token = cfg.get_value("auth", "token", "")
	_user_id = cfg.get_value("auth", "user_id", "")
	_username = cfg.get_value("auth", "username", "")
	_offline_chosen = cfg.get_value("prefs", "offline_chosen", false)

func _save_session() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH) # αγνόησε σφάλμα — μπορεί να μην υπάρχει ακόμα
	cfg.set_value("server", "base_url", base_url)
	cfg.set_value("auth", "token", _token)
	cfg.set_value("auth", "user_id", _user_id)
	cfg.set_value("auth", "username", _username)
	cfg.set_value("prefs", "offline_chosen", _offline_chosen)
	cfg.save(CONFIG_PATH)
