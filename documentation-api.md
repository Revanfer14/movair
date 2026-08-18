# Documentation API — movair server

Base URL produksi: `https://<domain>.up.railway.app`
Base URL lokal: `http://localhost:8080`

Semua request/response `application/json`. Header `X-Device-Id` wajib di semua `/route-plans`.

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
{ "rows": [{ "base_pm25": 123.9, "wind_speed": 1.22, "relative_humidity": 92, "hour_of_day": 2, "is_weekend": 0, "lat": -6.2, "lon": 107.0 }] }
```
- `base_pm25` float 0–1000
- `wind_speed` float 0–20 (m/s)
- `relative_humidity` float 0–100
- `hour_of_day` int 0–23
- `is_weekend` int 0/1
- `lat` float −90–90, **opsional**
- `lon` float −180–180, **opsional**

Semua field selain `lat`/`lon` wajib, nilai `0` valid. `lat`/`lon` cuma buat data collecting — kalau gak dikirim (app lama), kolomnya NULL di server, gak ada yang pecah. Nilainya koordinat **titik fetch cuaca (fetch group)**, sama persis dengan yang dipakai manggil Open-Meteo — bukan posisi user saat request.

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
  "origin": {"lat":0,"lon":0}, "destination": {"lat":0,"lon":0},
  "chosen_rank": 1,
  "equivalent_exposure": false,
  "weather": { "base_pm25":0,"wind_speed":0,"relative_humidity":0,"temperature":0,"hour_of_day":0,"is_weekend":0,"c_base":0 },
  "routes": [{
    "rank":1,"label":"Rute A","distance_m":400,"duration_s":94,"exposure":117.4,"dose_ug":4.70,
    "segments": [{"index":0,"mid":{"lat":0,"lon":0},"cum_start_m":0,"cum_end_m":200,"road_class":3,"greenery_index":0.0,"m_road":1.15,"m_green":1.0,"c_base":62.45,"c_i":71.8175,"t_i_s":47.0,"c_i_t_i":56.25}]
  }]
}
```

**Validasi**: `X-Device-Id` ada, `id` UUID valid, `model_version` gak kosong, `routes` gak kosong (tiap route punya `rank` + ≥1 segmen), `chosen_rank` cocok salah satu `rank`, total segmen ≤2000, body ≤2MB — semua gagal → 400 (segmen/body kelebihan → "Permintaan terlalu besar").

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
{ "route_plans": [{ "id":"...", "created_at":"...", "model_version":"...", "route_count":1, "segment_count":2, "chosen_rank":1 }] }
```
Device tanpa data → `{"route_plans": []}` (array kosong, bukan `null`).

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
| 404 | Data tidak ditemukan | route plan gak ada, atau route tidak terdaftar |
| 405 | Permintaan tidak valid | method salah buat path itu |
| 429 | Terlalu banyak permintaan, coba lagi sebentar | kena rate limit, header `Retry-After` |
| 503 | Layanan lagi gangguan, coba lagi | predictor mati atau database gagal |
| 500 | Layanan lagi gangguan, coba lagi | sisanya |

**Rate limit**: 60/menit per `X-Device-Id` (burst 20), 240/menit per IP (burst 60). Kena limit → 429 + `Retry-After: 60`.
