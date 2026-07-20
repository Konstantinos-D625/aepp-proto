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
| `users`    | auth | Λογαριασμός παίκτη. `username` (3-20, `[a-zA-Z0-9_]`, unique/NOCASE) + password. Email προαιρετικό. `identityFields = ["username"]`. |
| `profiles` | base | Δημόσιο στιγμιότυπο προόδου (1 ανά χρήστη). Τα πεδία του `PlayerProfile.build_public_profile()`. |

**Rules στο `profiles`:** διαβάζει κάθε συνδεδεμένος (`@request.auth.id != ''`)·
γράφει/σβήνει μόνο ο κάτοχος (`user = @request.auth.id`).

Το `profiles` έχει denormalized `username` για αναζήτηση φίλων χωρίς να ανοίγει το
κλειδωμένο `users`. Friends/clans/chat collections έρχονται σε επόμενες φάσεις.

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
