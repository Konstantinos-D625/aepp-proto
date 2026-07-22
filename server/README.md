# Server (PocketBase) — online social layer

Backend για τα online χαρακτηριστικά του παιχνιδιού (accounts / profiles / φίλοι /
clans / chat). **Υβριδικό μοντέλο**: το παιχνίδι παίζεται 100% offline· ο server
είναι προαιρετικός και κρατά μόνο το *δημόσιο* στιγμιότυπο προόδου.

- **Engine:** [PocketBase](https://pocketbase.io) v0.39.8 (single binary: auth + DB + REST + realtime + admin UI)
- **Auth:** username + password **χωρίς email** (ανήλικοι/GDPR)
- Το binary & το `pb_data/` **δεν** μπαίνουν στο git — μόνο τα `pb_migrations/`.

## Τοπικό development (Windows)

```powershell
# 1. Κατέβασε το binary (μία φορά μετά από clone)
.\download-pocketbase.ps1

# 2. Φτιάξε τον admin του dashboard (μόνο τοπικά)
.\pocketbase.exe superuser upsert dev@local.test devadminpass123

# 3. Τρέξε τον server (εφαρμόζει αυτόματα τα pending migrations)
.\pocketbase.exe serve --http=127.0.0.1:8090
```

- REST API: <http://127.0.0.1:8090/api/>
- Admin dashboard: <http://127.0.0.1:8090/_/>
- Χειροκίνητη εφαρμογή migrations: `.\pocketbase.exe migrate up`

## Σχήμα (ορίζεται στα `pb_migrations/`)

| Collection | Τύπος | Ρόλος |
|---|---|---|
| `users`         | auth | Λογαριασμός παίκτη. `username` (3-20, `[a-zA-Z0-9_]`, unique/NOCASE) + password. Email προαιρετικό. `identityFields = ["username"]`. |
| `profiles`      | base | Δημόσιο στιγμιότυπο προόδου (1 ανά χρήστη). Τα πεδία του `PlayerProfile.build_public_profile()`. |
| `saves`         | base | ΙΔΙΩΤΙΚΟ πλήρες save (1 ανά χρήστη) για cross-device restore — μόνο ο κάτοχος (Φ4). |
| `friendships`   | base | Σχέσεις φιλίας αίτημα→αποδοχή (`status` pending\|accepted), denormalized ονόματα (Φ5). |
| `clans`         | base | Συντεχνία: `name` (3-24, unique/NOCASE), `description`, `owner` + denormalized `owner_name` (Φ6). |
| `clan_members`  | base | Μέλη & αιτήματα ένταξης (`status` pending\|member, `role` leader\|member). **Unique index στο `user`** = ένα clan ανά παίκτη (Φ6). |
| `messages`      | base | Chat (`scope` clan\|dm): clan chat + DM φίλων. `sender`, `text`, `clan`/`recipient`, `dm_key` (Φ7). |

**Rules στο `profiles`:** διαβάζει κάθε συνδεδεμένος (`@request.auth.id != ''`)·
γράφει/σβήνει μόνο ο κάτοχος (`user = @request.auth.id`). Το `saves` είναι **μόνο του
κατόχου** σε όλες τις πράξεις.

**Rules στα clans (Φ6):** `clans` — διαβάζει κάθε συνδεδεμένος· γράφει/σβήνει μόνο ο
`owner`. `clan_members` — διαβάζει κάθε συνδεδεμένος· **create** ο ίδιος ο χρήστης ΚΑΙ
(ζητά ως `pending` Ή είναι ο αρχηγός μέσω nested `clan.owner`)· **update** (έγκριση
pending→member) μόνο ο αρχηγός· **delete** ο ίδιος (αποχώρηση) Ή ο αρχηγός (kick/disband).

**Rules στα messages (Φ7 + Φ8):** ανάγνωση — DM μόνο τα δύο μέρη (`sender`/`recipient`)·
clan chat μόνο μέλος (back-relation `clan.clan_members_via_clan.user ?= @request.auth.id`).
create — πάντα ως ο ίδιος ο `sender`· clan μόνο αν είσαι μέλος· **DM ΜΟΝΟ μεταξύ αποδεκτών
φίλων** (Φ8 hardening — correlated `@collection.friendships:fa/:fb` με `status='accepted'` σε
μία από τις δύο κατευθύνσεις). `updateRule = null` (αμετάβλητα)· delete μόνο ο `sender`.
Επαληθεύτηκε με αρνητικά tests (outsider δεν διαβάζει/γράφει clan chat· τρίτος δεν διαβάζει
DM· μη-φίλος & pending ΔΕΝ στέλνουν DM — 7/7 PASS). Ανανέωση στον client = **adaptive
polling** (γρήγορο όταν το παράθυρο είναι εστιασμένο, σταδιακή επιβράδυνση σε σιωπή, αργός
ρυθμός σε alt-tab)· realtime/SSE = μελλοντική επιλογή χωρίς αλλαγή σχήματος.

Τα `profiles`/`friendships`/`clan_members`/`messages` έχουν denormalized ονόματα ώστε οι
λίστες/bubbles να εμφανίζονται χωρίς να ανοίγει το κλειδωμένο `users`.

## Σκλήρυνση & GDPR (Φάση 8)

**Rate limiting** (`pb_migrations/1785000100_rate_limits.js` — ενεργοποιεί τον
ενσωματωμένο limiter, όρια ΑΝΑ client σε κυλιόμενο παράθυρο):

| Label | Όριο | Σκοπός |
|---|---|---|
| `messages:create` | 10 / 10s | anti-spam chat |
| `POST /api/collections/users/auth-with-password` | 10 / 30s | anti brute-force login |
| `POST /api/collections/users/records` | 5 / 60s | anti mass-registration |
| `/api/` | 300 / 10s | γενικό δίχτυ ασφαλείας |

Επαληθεύτηκε εμπειρικά ότι επιστρέφει **429** μετά το όριο (messages & auth).

**GDPR — «δικαίωμα στη λήθη»:** ο παίκτης διαγράφει self-service τον λογαριασμό του
(`Net.delete_account()` → `DELETE /api/collections/users/records/{id}`). Ο deleteRule του
`users` (default `id = @request.auth.id`) το επιτρέπει, και το **cascadeDelete** σε όλα τα
relations→`users` σβήνει αυτόματα profile + save + friendships + clan(owner) + clan_members
+ messages. Επαληθεύτηκε ότι δεν μένει ΚΑΝΕΝΑ εξαρτημένο record (7/7 PASS). Το UI
(ProfilePopup) απαιτεί να πληκτρολογηθεί ξανά το username πριν την οριστική διαγραφή.
Δεν αποθηκεύεται email (data minimization — ανήλικοι).

**Ασφάλεια μεταφοράς:** ο `Net` ΔΕΝ στέλνει ποτέ το auth token σε απομακρυσμένο host
χωρίς HTTPS (`_is_transport_secure_for_auth` — http επιτρέπεται μόνο σε loopback). Άρα το
production URL του Oracle ΠΡΕΠΕΙ να είναι `https://` (πίσω από reverse proxy + TLS).

### Ροή σύνδεσης (για το `Net` autoload, Φάση 2-4)

```
POST /api/collections/users/records            {username, password, passwordConfirm}   → register
POST /api/collections/users/auth-with-password {identity: username, password}           → token
POST /api/collections/profiles/records         {user, username, ...build_public_profile} (Bearer token)
GET  /api/collections/profiles/records                                                   (Bearer token)
```

## Deploy στο Oracle (Ampere A1 / arm64) — μελλοντικό βήμα

Το `pb_data/` και το binary είναι OS-agnostic ως προς τα migrations. Στον server:

```bash
./download-pocketbase.sh                       # arm64 autodetect
./pocketbase superuser upsert <admin-email> <strong-pass>
./pocketbase serve --http=0.0.0.0:8090         # πίσω από reverse proxy + TLS
# systemd service για αυτόματη εκκίνηση — βλ. https://pocketbase.io/docs/going-to-production/
```

Άνοιξε το firewall/Security List της Oracle μόνο για τη θύρα του reverse proxy (443).
