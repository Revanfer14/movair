# Documentation API — movair server

Base URL produksi: `https://<adadeh>.railway.app`
Base URL lokal: `http://localhost:8080`

Semua request/response `application/json`. Header `X-Device-Id` wajib di semua `/route-plans` dan `/ride-records`.

---

## GET /health
Cek server & database hidup, gak butuh header.

**200**
```json
{ "status": "ok", "wib_time": "2026-08-17T09:24:11+07:00", "hour_of_day": 9, "database": "ok" }
```
**503**: `status: "degraded"`, `database: "unreachable"`

---

## POST /predict
Prediksi PM2.5, batch maks 64 baris.

**Body**
```json
{ "rows": [{ "base_pm25": 123.9, "wind_speed": 1.22, "relative_humidity": 92, "hour_of_day": 2, "is_weekend": 0 }] }
```
- `base_pm25` float 0–1000
- `wind_speed` float 0–20 (m/s)
- `relative_humidity` float 0–100
- `hour_of_day` int 0–23
- `is_weekend` int 0/1
- `lat` float −90–90, opsional
- `lon` float −180–180, opsional

Semua 5 field pertama wajib, nilai `0` valid. `lat`/`lon` opsional tapi harus dikirim
berpasangan (satu tanpa yang lain → 400); **bukan input model**, cuma dicatat ke tabel
`ml_samples` buat data collecting — gak mempengaruhi `c_base`.

**200**
```json
{ "model_version": "gbr_v4_log", "c_base": [62.45] }
```
`c_base` paralel dengan `rows`, sudah kena `expm1()` — jangan di-transform lagi.

**Errors**: rows kosong/field hilang/body rusak → 400; nilai di luar rentang → 400; rows>64 atau body>256KB → 400; predictor mati → 503.

---

## POST /route-plans
Arsip hasil perhitungan rute (fire-and-forget). Server gak validasi kebenaran angka (`c_i`, `exposure`, `dose_ug`), cuma validasi struktur.

**Header wajib**: `X-Device-Id`

**Body** (ringkas)
```json
{
  "id": "uuid",
  "created_at_wib": "...",
  "model_version": "gbr_v4_log",
  "origin": {"lat":0,"lon":0}, "destination": {"name":"Grand Indonesia","lat":0,"lon":0},
  "chosen_rank": 1,
  "equivalent_exposure": false,
  "weather": { "base_pm25":0,"wind_speed":0,"relative_humidity":0,"temperature":0,"hour_of_day":0,"is_weekend":0,"c_base":0 },
  "fetch_groups": [{
    "index": 0,
    "reference": {"lat":-6.2621,"lon":106.6682},
    "base_pm25": 52.5, "wind_speed": 1.22, "relative_humidity": 92.0,
    "temperature": 28.4, "hour_of_day": 9, "is_weekend": 0,
    "c_base": 62.45, "segment_count": 120
  }],
  "routes": [{
    "rank":1,"label":"Rute A","distance_m":400,"duration_s":94,"exposure":117.4,"dose_ug":4.70,
    "segments": [{"index":0,"fetch_group_index":0,"mid":{"lat":0,"lon":0},"cum_start_m":0,"cum_end_m":200,"road_class":3,"greenery_index":0.0,"m_road":1.15,"m_green":1.0,"c_base":62.45,"c_i":71.8175,"t_i_s":47.0,"c_i_t_i":56.25}]
  }]
}
```

`fetch_groups` dan `segments[].fetch_group_index` opsional (aditif, backward compatible). Kalau ada beberapa fetch cuaca terpisah untuk satu rute (satu per grup jarak, maks 8 grup), tiap grup diarsipkan lewat `fetch_groups[]`; `weather` di level atas tetap diisi client dengan nilai grup pertama dan tetap tersimpan seperti biasa — gak jadi wajib, gak dihapus.

`destination` juga opsional (aditif). Kalau diisi, `lat`/`lon` harus berpasangan dan divalidasi rentang (-90..90 / -180..180); `name` opsional, maks 200 karakter. Ketiganya dipromosikan jadi kolom (`destination_name`, `destination_lat`, `destination_lon`) supaya muncul di `GET /route-plans`.

**Validasi**: `X-Device-Id` ada, `id` UUID valid, `model_version` gak kosong, `routes` gak kosong (tiap route punya `rank` + ≥1 segmen), `chosen_rank` cocok salah satu `rank`, total segmen ≤2000, body ≤2MB, kalau `fetch_groups` dikirim: gak boleh kosong, maks 8 elemen, `index` unik & integer non-negatif, dan tiap `segments[].fetch_group_index` (kalau ada) harus cocok salah satu `fetch_groups[].index` — kalau `fetch_groups` gak dikirim, `fetch_group_index` di segmen diabaikan — semua gagal → 400 (segmen/body kelebihan → "Permintaan terlalu besar").

**201** (baru tersimpan): `{ "id": "...", "created": true }`
**200** (id sudah pernah dikirim, diabaikan): `{ "id": "...", "created": false }`

Idempoten via `id` — **generate UUID baru tiap kali route plan dihitung ulang**. Reuse ID bikin hasil perhitungan baru hilang tanpa error.

`created_at` yang dipakai server = waktu terima, bukan `created_at_wib` dari device (tetap tersimpan di payload).

---

## GET /route-plans/:id
Ambil payload utuh, persis seperti yang dikirim.

**Header wajib**: `X-Device-Id`

**200**: body identik payload POST.
**400**: id bukan UUID. **404**: gak ada / milik device lain (bukan 403).

---

## GET /route-plans
List route plan milik device (tanpa payload), terbaru dulu.

**Header wajib**: `X-Device-Id`

Query: `limit` (opsional, default 50, range 1–200; di luar rentang → 400).

**200**
```json
{ "route_plans": [{ "id":"...", "created_at":"...", "model_version":"...", "route_count":1, "segment_count":2, "fetch_group_count":0, "chosen_rank":1, "destination_name":"Grand Indonesia", "destination_lat":-6.1778, "destination_lon":106.7908 }] }
```
Device tanpa data → `{"route_plans": []}` (array kosong, bukan `null`).

---

## POST /ride-records
Arsip ride yang **beneran dilewati** user (jejak GPS asli + dosis per-segmen aktual dari live tracking) — kebalikan dari `/route-plans` yang nyimpen rencana. Fire-and-forget + retry lokal dari app. Server gak validasi kebenaran angka, cuma struktur & rentang nilai.

**Header wajib**: `X-Device-Id`

**Body** (ringkas)
```json
{
  "id": "uuid",
  "route_plan_id": "uuid atau null",
  "model_version": "gbr_v4_log",
  "started_at_wib": "...", "completed_at_wib": "...",
  "origin": {"lat":0,"lon":0}, "destination": {"name":"Grand Indonesia","lat":0,"lon":0},
  "totals": {
    "total_dose_ug": 42.7, "attributed_duration_s": 1180.4, "unattributed_duration_s": 22.0,
    "elapsed_duration_s": 1202.4, "travelled_distance_m": 5310.2, "average_speed_kmh": 15.9,
    "ended_off_route": false
  },
  "segments": [{"index":0,"c_i":38.4,"t_i_s":42.1,"c_i_t_i":26.9,"dose_ug":1.08,"interpolated":false}],
  "trace": [{"lat":-6.2088,"lon":106.8456,"t_s":0.0,"acc_m":8.2,"spd_mps":4.1}]
}
```

`route_plan_id` opsional dan **gak** foreign-key ke `route_plans.id` (arsip plan bisa gagal duluan, ride record gak boleh ikut ditolak). `segments[].index` sejajar dengan `route_plans` punya `routes[].segments[].index` — buat query prediksi-vs-aktual. `segments[].dose_ug` dosis terakumulasi per segmen (`Σ dose_ug ≈ totals.total_dose_ug`, dipastikan di app). `trace[].t_s` detik sejak `started_at`.

**Validasi**: `X-Device-Id` ada, `id` UUID valid, `route_plan_id` UUID valid (kalau diisi), `segments[].index` non-negatif & unik, `segments[].c_i/.t_i_s/.c_i_t_i/.dose_ug` ada & angka valid, `trace[].lat/.lon` di rentang -90..90/-180..180, `destination` sama seperti `/route-plans`, `totals.total_dose_ug` ada & non-negatif, total segmen ≤2000, titik trace ≤3000, body ≤2MB (segmen/trace/body kelebihan → "Permintaan terlalu besar").

**201/200**: sama format dengan `/route-plans` — `{ "id": "...", "created": true|false }`. Idempoten via `id`, aman buat retry.

---

## GET /ride-records/:id
Ambil payload utuh. **Header wajib**: `X-Device-Id`. **200**: body identik payload POST. **400**: id bukan UUID. **404**: gak ada / milik device lain.

---

## GET /ride-records
List ride record milik device (tanpa payload/trace), terbaru dulu. **Header wajib**: `X-Device-Id`. Query: `limit` (default 50, range 1–200).

**200**
```json
{ "ride_records": [{ "id":"...", "route_plan_id":"...", "created_at":"...", "started_at":"...", "completed_at":"...", "model_version":"...", "segment_count":27, "trace_point_count":812, "total_dose_ug":42.7, "attributed_duration_s":1180.4, "unattributed_duration_s":22.0, "travelled_distance_m":5310.2 }] }
```
Device tanpa data → `{"ride_records": []}`.

---

## Error umum (semua endpoint)
```json
{ "error": "pesan" }
```
| Status | Pesan | Kapan |
| --- | --- | --- |
| 400 | Permintaan tidak valid | body rusak, field hilang, header kosong, ID bukan UUID |
| 400 | Nilai input tidak valid | field ada tapi nilai di luar rentang |
| 400 | Permintaan terlalu besar | body atau jumlah baris/segmen lewat batas |
| 404 | Data tidak ditemukan | route plan/ride record gak ada, atau route tidak terdaftar |
| 405 | Permintaan tidak valid | method salah buat path itu |
| 429 | Terlalu banyak permintaan, coba lagi sebentar | kena rate limit, header `Retry-After` |
| 503 | Layanan lagi gangguan, coba lagi | predictor mati atau database gagal |
| 500 | Layanan lagi gangguan, coba lagi | sisanya |

**Rate limit**: 60/menit per `X-Device-Id` (burst 20), 240/menit per IP (burst 60). Kena limit → 429 + `Retry-After: 60`.
