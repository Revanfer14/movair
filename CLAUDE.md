# CLAUDE.md — CleanRoute iOS

Panduan kerja buat ngembangin app CleanRoute. Kalau ada konflik antara file ini dan asumsi lu, **file ini yang menang**. Kalau ada konflik soal rumus, `RUMUS.md` yang menang.

**Target user: pesepeda / cyclist.** Bukan pengendara motor. Kalau nemu sisa referensi "motor" di dokumen lama (`v4-summary.md`, `CleanRoute-ML-Plan_v4.0.md`), itu artefak versi sebelumnya — abaikan dan catat biar diperbaiki. `RUMUS.md` udah diupdate.

---

## 0. Hard Rules (jangan dilanggar)

### 0.1 No comments

- **JANGAN nulis comment apapun** di kode Swift baru: no `//`, no `/* */`, no doc comment (`///`), no `// MARK:`, no `// TODO:`.
- **JANGAN hapus header comment default yang di-generate Xcode** (blok `//  FileName.swift` / `//  CleanRoute` / `//  Created by ...` di paling atas file). Itu tetap.
- Struktur file dibikin lewat **pemecahan file & tipe**, bukan lewat comment separator. Kalau lu ngerasa butuh `// MARK:` buat misahin bagian → itu sinyal file-nya kepanjangan, pecah jadi file baru.
- Konsekuensi: nama variabel, fungsi, dan tipe harus **self-explanatory**. `let cubicMetersPerMinute` bukan `let ve`. `func splitPolylineEvery200m` bukan `func split`.

### 0.2 Folder structure (fixed)

```
CleanRoute/
├── Extensions/     Color+, Font+, dan extension utility lain
├── Components/     View kecil reusable (card, badge, button, chip)
├── Models/         struct/enum data murni, no logic, no networking
├── Services/       networking, CoreML, file loading, GPS, kalkulasi murni
├── ViewModels/     @Observable / ObservableObject, state + orkestrasi
└── Views/          screen-level SwiftUI view
```

- Setiap file baru **wajib** masuk salah satu folder di atas. Jangan bikin folder baru (no `Utils/`, no `Helpers/`, no `Core/`, no `Managers/`).
- Kalau ragu file baru masuk mana:
  - Cuma nyimpen data, gak punya method yang punya side effect → `Models/`
  - Manggil network / baca file / manggil CoreML / baca GPS / murni ngitung → `Services/`
  - Punya `@Published`/`@Observable` state yang dipakai View → `ViewModels/`
  - Dipakai di lebih dari satu View dan gak punya state sendiri → `Components/`
  - `extension` ke tipe milik Apple → `Extensions/`
- 1 file = 1 tipe utama. Nama file = nama tipe.

### 0.3 Code quality

- Clean, readable, structured. Fungsi pendek, satu tanggung jawab.
- No force unwrap (`!`) kecuali di literal yang emang gak mungkin gagal. Pakai `guard let` / `throws`.
- No magic number di tengah logic. Semua konstanta rumus masuk satu tempat (`Services/DoseConstants.swift`), nilainya persis kayak §3.
- Networking pakai `async/await` + `URLSession`, bukan completion handler.
- Service = `protocol` + implementasi konkret, biar bisa di-fake pas testing.
- Jangan taro business logic di View. View cuma render state dari ViewModel.

---

## 1. Apa yang dibangun

App navigasi iOS **khusus pesepeda** di Jabodetabek yang me-ranking rute berdasarkan **estimasi dosis paparan PM2.5**, bukan waktu tempuh — lalu **mengukur dosis aktual** selama perjalanan berlangsung.

> "Google Maps kasih rute tercepat. CleanRoute kasih rute yang paling sedikit bikin lu sakit."

Ada **dua mode** dan bedanya penting:

|          | Planning Mode                                    | Live Ride Mode                           |
| -------- | ------------------------------------------------ | ---------------------------------------- |
| Kapan    | Sebelum berangkat                                | Selama gowes                             |
| `tᵢ`     | Estimasi, dari ETA ORS dibagi proporsional jarak | **Diukur real-time** dari GPS per segmen |
| `C_base` | 1 prediksi per grup fetch                        | Re-prediksi tiap pergantian jam WIB      |
| Output   | Ranking rute + dosis perkiraan                   | Dosis aktual + ringkasan pasca-gowes     |

Alur planning:

```
User input origin → destination
  → OpenRouteService: ≤3 rute alternatif (profil cycling, otomatis gak lewat tol)
  → potong tiap polyline jadi segmen ~200m
  → kelompokkan segmen jadi grup fetch (clustering jarak, threshold 20 km)
  → fetch Open-Meteo 1× per grup, pakai koordinat titik referensi grup
  → CoreML CleanRoutePM25 → C_base per grup   ← satu-satunya lapisan ML
  → roads_data.json lookup per segmen → M_road, M_green
  → Cᵢ = C_base × M_road × M_green
  → tᵢ = ETA_total × (distanceᵢ / distance_total)
  → ranking: Σ(Cᵢ × tᵢ) terkecil → gate 20% → detour cap 1.5×
```

Alur live ride:

```
User mulai gowes
  → GPS proyeksi posisi ke polyline rute terpilih (jalan sama persis off-route atau enggak, §4.6)
  → deteksi masuk/keluar batas segmen → timer per segmen mulai dari 0, stop pas keluar
  → tᵢ_aktual = akumulasi durasi per segmen (kumulatif sejak awal ride)
  → tiap update lokasi: Δtᵢ = tᵢ_sekarang − tᵢ_update-sebelumnya per segmen
  → tiap ganti jam WIB: re-fetch Open-Meteo + re-prediksi C_base
  → tiap update HR: VE_sekarang dihitung dari HR (§4.7)
  → Δdosis = VE_sekarang × Σ(Cᵢ × Δtᵢ) ; dosis_total += Δdosis   ← inkremental, BUKAN VE_sekarang × exposure kumulatif dihitung ulang
```

**Pembagian tugas yang dikunci:** ML ngasih **angka dosis absolut**, rumus deterministik ngasih **ranking**. Model ML buta lokasi — seluruh diferensiasi spasial datang dari `roads_data.json`, bukan dari model.

---

## 2. Aset yang udah ada di `Services/`

| File                     | Isi                          | Catatan                                                                                           |
| ------------------------ | ---------------------------- | ------------------------------------------------------------------------------------------------- |
| `CleanRoutePM25.mlmodel` | Model final, udah dikonversi | Output **skala log**                                                                              |
| `model_gbr_v4_log.pkl`   | Sumber sklearn               | Referensi doang, gak dipakai runtime                                                              |
| `roads_data.json`        | 147.027 cell, grid 166m      | Versi greenery yang udah dikoreksi (1.516 full-green cell) meskipun nama file gak ada suffix `_2` |

`RUMUS.md` ada di root project. Itu single source of truth buat rumus.

---

## 3. Kontrak Kritis (salah di sini = app diam-diam ngaco tanpa crash)

```
1. expm1() pada output CoreML          ← lupa = dosis salah ~50×
2. wind_speed dalam m/s                ← Open-Meteo default km/jam
3. hour_of_day & is_weekend pakai WIB  ← bukan UTC, bukan timezone device
4. Koordinat ORS urutannya [lon, lat]  ← kebalik dari MapKit/CLLocation
5. Konstanta rumus:
     M_road  : arteri 1.25 · kolektor 1.15 · lokal 1.00
     M_green : 1 − 0.05 × greenery_index
     VE      : 0.040 m³/min (fallback) — atau HR-based (§4.7) kalau HR > 30 bpm & profil HealthKit lengkap
     F_moda  : TIDAK DIPAKAI — lihat §4.7, jangan dimasukin balik
     Dosis   : planning → VE × Σ(Cᵢ × M_road × M_green × menit)      ← VE konstan, boleh di luar Σ
               live     → Σᵢ (VEᵢ × Cᵢ × M_road,ᵢ × M_green,ᵢ × menit) ← VE WAJIB di dalam Σ, lihat §4.7
6. Planning mode: Σ tᵢ harus balik persis ke ETA total dari ORS
   Live mode: Σ tᵢ = durasi terukur, TIDAK dipaksa sama dengan ETA
7. Fetch CAMS pakai clustering jarak (§4.2)  ← BUKAN floor(lat/0.4), floor(lon/0.4)
8. Live mode: dosis diakumulasi INKREMENTAL per update (Δdosis += VE_sekarang × Σ(Cᵢ×Δtᵢ))
   ← BUKAN VE_sekarang × exposure_seluruh_riwayat dihitung ulang tiap update
9. Off-route BUKAN kondisi khusus buat map-matching/timer ← lihat §4.6
```

Poin 1–4 gak bikin crash — makanya ditulis eksplisit. Tiap nyentuh `PMPredictor`, `OpenMeteoService`, atau `ORSRoutingService`, cek ulang list ini.

---

## 4. Services — spesifikasi

### 4.1 `ORSRoutingService`

Ganti total `MKDirections`. MapKit tetap dipakai, tapi **cuma buat nampilin peta + geocoding**, bukan routing.

```
POST https://api.openrouteservice.org/v2/directions/cycling-regular/geojson
Header: Authorization: <ORS_API_KEY>, Content-Type: application/json

Body:
{
  "coordinates": [[lonStart, latStart], [lonEnd, latEnd]],
  "alternative_routes": { "target_count": 3, "share_factor": 0.6, "weight_factor": 1.6 },
  "instructions": false,
  "elevation": false
}
```

- **API key**: baca dari `Secrets.xcconfig` → mapping ke `Info.plist` → `Bundle.main.object(forInfoDictionaryKey: "ORS_API_KEY")`. Jangan hardcode. Jangan commit `Secrets.xcconfig`.
- **Profil `cycling-regular`** adalah profil yang tepat, bukan proxy. Konsekuensinya:
  - Rute gak akan pernah lewat tol/motorway → **gak perlu layer filter tol sendiri**. Kebutuhan legal (sepeda dilarang masuk tol) ketutup tanpa kode tambahan.
  - **`duration` dari ORS valid apa adanya.** Gak ada faktor koreksi kecepatan.
- Profil lain (`cycling-road`, `cycling-electric`, `cycling-mountain`) bisa jadi preferensi user nanti. Jangan bangun sekarang. Kalau dibangun, itu cuma ganti path segment di URL — jangan ubah apapun di layer dosis.
- `alternative_routes` cuma jalan kalau `coordinates` **tepat 2 titik** dan `target_count` maksimum 3.
- Response GeoJSON: `features[].geometry.coordinates` (array `[lon, lat]`), `features[].properties.summary.duration` (detik) dan `.distance` (meter).
- Rate limit free tier ketat. **Wajib** debounce input dan cache hasil per pasangan (origin, destination) yang dibulatkan koordinatnya. Jangan panggil tiap keystroke.
- Error handling eksplisit: 401 (key salah), 403 (kuota habis), 404 (gak ada rute), timeout. Masing-masing pesan user-facing beda.

### 4.2 `OpenMeteoService`

Dua endpoint, gratis tanpa API key:

```
Air quality:
https://air-quality-api.open-meteo.com/v1/air-quality
  ?latitude=..&longitude=..&hourly=pm2_5&timezone=Asia%2FJakarta&forecast_days=1

Weather:
https://api.open-meteo.com/v1/forecast
  ?latitude=..&longitude=..&hourly=wind_speed_10m,relative_humidity_2m
  &wind_speed_unit=ms&timezone=Asia%2FJakarta&forecast_days=1
```

- `wind_speed_unit=ms` **wajib**. Kontrak #2 — kalau hilang, unit jadi km/jam, prediksi ngaco tanpa error.
- `timezone=Asia/Jakarta` biar index jam-nya langsung WIB.
- Ambil nilai di index jam sekarang, bukan rata-rata harian.

**Fetch per grup jarak, bukan per rute dan bukan per segmen.**

> **Revisi.** Versi sebelumnya file ini nyuruh kuantisasi grid `floor(lat / 0.4)`, `floor(lon / 0.4)`. **Pendekatan itu udah dibatalkan secara empiris** — lihat `RUMUS.md` §3.1. Rute uji `(-6.262199, 106.668267)` → `(-6.177820, 106.790758)`: dua titik yang menurut floor-division jatuh di cell yang sama persis ternyata ngasih `base_pm25` 52,5 vs 40,2 dari Open-Meteo. Kalau nemu kode yang masih pakai `floor(coord / 0.4)` buat dedup fetch, itu implementasi versi lama — ganti.

Penyebabnya: Open-Meteo kemungkinan interpolasi kontinu antar node CAMS sebelum ngasih hasil, atau grid CAMS asli gak align ke kelipatan bulat 0.4°. Dua-duanya sama akibatnya — kuantisasi grid gak bisa dipakai buat nebak "titik ini masih area yang sama secara PM2.5 atau udah beda".

**Clustering berbasis jarak, sekuensial sepanjang urutan rute:**

1. Jalan segmen demi segmen sesuai urutan rute.
2. Segmen pertama jadi titik referensi grup-1.
3. Segmen berikutnya: kalau jaraknya dari titik referensi grup aktif **≤ 20 km**, masuk grup itu. Kalau lebih jauh, segmen ini jadi titik referensi grup baru.
4. Ulangi sampai semua segmen ke-assign.
5. Fetch air quality + weather **1× per grup**, pakai koordinat **titik referensi grup** (bukan centroid).
6. Panggil CoreML **1× per grup** → `C_base` per grup.
7. Tiap segmen ambil `C_base` dari grup tempat dia di-assign.

Jarak pakai `CLLocation.distance(from:)`, bukan Euclidean derajat.

**Threshold 20 km itu provisional, bukan final.** ~Separuh resolusi nominal CAMS (44 km), dipilih konservatif karena nominal itu udah kebukti gak bisa dipercaya persis. Belum divalidasi lewat sampling sistematis — lihat §6 dan `RUMUS.md` §9. Taro di `DoseConstants`, jangan sebar di beberapa tempat.

Rute pendek (< threshold total) → 1 fetch. Rute panjang → jumlah fetch **emergent dari clustering**, bukan dari hitungan cell grid manapun.

- Cap keras **8 fetch per request**, sekarang dihitung dari **jumlah grup**, bukan jumlah cell unik. Kalau lebih, kasih tau user rutenya di luar cakupan yang divalidasi dan jangan lanjut diam-diam.
- Kalau fetch gagal: **jangan fallback ke angka hardcode.** Tampilkan error, biarin user retry. Angka dosis palsu lebih buruk daripada gak ada angka.
- **Jangan interpolasi antar grup.** Bukan karena batas grup itu "jujur" — klaim lama itu udah gak berlaku, karena Open-Meteo kemungkinan udah interpolasi sendiri. Alasannya sekarang lebih sederhana: yang kita kontrol adalah granularitas grup fetch kita sendiri, dan nambah interpolasi di atasnya cuma nambah lapisan tebakan tanpa dasar.

### 4.3 `PMPredictor`

Wrapper `CleanRoutePM25.mlmodel`.

- Input 5 fitur, urutannya sesuai kelas Swift generated: `base_pm25`, `wind_speed`, `relative_humidity`, `hour_of_day`, `is_weekend`.
- Cek nama input/output property di kelas generated (`CleanRoutePM25Input` / `CleanRoutePM25Output`) sebelum nulis kode — jangan ngarang nama, converter sklearn sering ngasih nama output generik.
- **Output harus di-`expm1()`.** Kontrak #1. Bungkus di satu tempat, jangan sampai ada caller yang bisa dapet nilai mentah skala log.
- `hour_of_day` dan `is_weekend` diturunkan dari `Calendar` dengan `TimeZone(identifier: "Asia/Jakarta")`, bukan `.current`.
- Model di-load sekali, disimpan sebagai instance. Jangan di-init per segmen.
- Frekuensi panggil: **1× per grup fetch per jam WIB.** Bukan per segmen, bukan per GPS update.

### 4.4 `RoadDataStore`

- Load `roads_data.json` sekali, lazy, di background, simpan sebagai dictionary in-memory. 2,5 MB — jangan parse ulang per lookup.
- Lookup: koordinat segmen → index cell grid (`meta.step` dalam derajat, ≈166m) → `road_class` + `greenery_index`.
- `road_class`: 1 tol, 2 arteri, 3 kolektor, 4 lokal.
- Cell `road_class = 1` seharusnya gak pernah muncul karena profil cycling gak ngasih rute tol. Kalau muncul, itu artefak snapping grid — perlakukan sebagai kolektor (1.15) dan catat sebagai anomali. **Jangan buang segmennya** (buang segmen bikin Σtᵢ gak balik ke ETA di planning mode, langgar kontrak #6).
- Cell miss (koordinat di luar grid): default `road_class = 4`, `greenery_index = 0` → M_road 1.00, M_green 1.00. Netral, bukan optimistis.
- **Catatan cakupan**: grid cuma nutup Jabodetabek. Rute sepeda jarak jauh gampang keluar batas ini dan seluruh segmen di luar bakal ketiban default netral. Kalau > 30% segmen kena default, kasih tau user bahwa akurasi di luar Jabodetabek menurun. Jangan diam.

### 4.5 `RouteSegmenter`

- Input: array koordinat polyline dari ORS.
- Potong tiap **200m** dari jarak kumulatif, interpolasi linear antara 2 titik polyline terdekat. Sisa terakhir jadi segmen pendek.
- 200m dipilih karena ≈ resolusi grid 166m. Jangan dibikin lebih halus — cuma nambah lookup redundan ke cell yang sama.
- Pakai `CLLocation.distance(from:)` buat jarak, bukan Euclidean derajat.
- Tiap segmen simpan: index, koordinat awal/akhir, jarak kumulatif awal & akhir sepanjang rute. Nilai kumulatif itu yang dipakai `RideTracker` buat map-matching (§4.6).
- Rute 60 km → ~300 segmen. Struktur harus tetap enteng: array of struct, jangan bikin objek berat per segmen.

### 4.6 `RideTracker` — pengukuran waktu real-time

Ini sumber `tᵢ` di live mode. **Event-based segment timer**, bukan rekonstruksi log GPS pasca-gowes.

**Perilaku:** user masuk segmen-1 → timer segmen-1 mulai dari 0. User keluar zona segmen-1 → timer segmen-1 stop, timer segmen-2 mulai dari 0. Terus sampai selesai.

**Setup lokasi:**

- `CLLocationManager` dengan `desiredAccuracy = kCLLocationAccuracyBestForNavigation`, `activityType = .fitness`, `allowsBackgroundLocationUpdates = true`, `pausesLocationUpdatesAutomatically = false`.
- Info.plist: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`. Capability: Background Modes → Location updates.
- GPS nyala terus selama ride: **disetujui, bukan masalah.** Tetap tampilkan indikator perekaman yang jelas ke user.

**Map-matching per update lokasi:**

1. Proyeksikan posisi ke polyline rute terpilih → dapat titik terdekat + jarak kumulatif sepanjang rute.
2. Jarak kumulatif → index segmen (lookup dari batas kumulatif di §4.5).
3. Kalau index beda dari segmen aktif → transisi.

**Anti-flapping (wajib, jangan diskip):** akurasi GPS di jalan perkotaan bisa ±10–20m, dan batas segmen cuma 200m. Tanpa guard, timer bakal loncat-loncat di batas.

- Transisi baru diterima kalau posisi udah **≥ 20m melewati batas** segmen berikutnya.
- Terima transisi **maju** aja secara default. Mundur cuma diterima kalau bertahan ≥ 3 update berturut-turut (user emang muter balik).
- Loncat > 1 segmen dalam 1 update: isi segmen yang keloncat dengan durasi diinterpolasi dari jarak, tandai `interpolated = true`.

**Akumulasi waktu:**

- Pakai jam monotonik (`ProcessInfo.processInfo.systemUptime` atau `CLLocation.timestamp`), bukan `Date()` — kebal perubahan jam sistem.
- Akumulasi per index segmen, bukan overwrite. Segmen bisa dilewati lebih dari sekali.
- Simpan juga durasi berhenti (kecepatan ≈ 0). Dosis pas berhenti di lampu merah **tetap dihitung** — user tetap napas.

**Off-route (deviasi rute):**

> **Revisi (v3), gantiin v1 (exclude) dan v2 (freeze ke segmen terakhir).** Keduanya udah gak berlaku.

- Jarak tegak lurus ke polyline > 50m dari rute → status `offRoute`. **Ini flag UI doang** (`MapNavigationStats` nampilin `"Off route"`) — **gak boleh ada cabang logic terpisah** buat map-matching atau akumulasi waktu berdasarkan flag ini.
- Map-matching (§4.6 atas: proyeksi ke polyline → index segmen → cek transisi pakai aturan anti-flapping yang sama) **jalan identik**, off-route atau enggak. Selama proyeksi belum lewat ambang transisi ke segmen berikutnya, waktu terus keakumulasi ke segmen aktif yang sama — off-route tapi belum "masuk" segmen baru = dianggap masih di situ. Begitu proyeksi lewat ambang, segmen aktif pindah seperti biasa, walau posisi fisik user masih > 50m dari polyline.
- **Hapus `attributeToActiveSegment` dan cabang khusus off-route dari implementasi v2.** Gak ada lagi bedanya "waktu off-route" vs "waktu on-route" secara kode — cuma beda status flag yang dibaca View buat nampilin indikator. Ini perubahan kode, bukan cuma dokumentasi — kalau `attributeToActiveSegment` masih ada di `RideTracker`, itu artefak v2 yang harus dicabut.
- `unattributedDuration` tetap selalu 0 / dead field di `RideTrackingSnapshot`/`RideRecord`/`TripSummary`, dipertahankan buat kompatibilitas struct doang. Alasannya sekarang lebih simpel dari v2: bukan "di-freeze ke tempat lain", tapi karena emang gak pernah ada cabang yang butuh bucket terpisah.
- `DoseConstants.offRouteGraceSeconds` tetap unused, belum dibersihin (sama kayak sebelumnya).
- Trade-off yang disadari (masih sama kayak v2): `Cᵢ` yang dipakai buat waktu off-route adalah `Cᵢ` segmen aktif menurut proyeksi terakhir, bukan konsentrasi aktual di lokasi fisik user. Makin jauh/lama nyimpang, makin gak representatif.
- Gak ada lagi konsep "balik ke dalam 50m → lanjut dari segmen hasil proyeksi" sebagai event terpisah — gak pernah ada jeda pemrosesan yang perlu dilanjutkan, proyeksi jalan terus tanpa henti dari awal sampai akhir ride.

**Pergantian jam WIB:**

- Ride sepeda gampang lewat batas jam. `hour_of_day` adalah fitur ML terkuat kedua (20% importance) dan pola bias CAMS berubah tajam sore–malam.
- Waktu jam WIB berganti selama ride: re-fetch Open-Meteo untuk **grup aktif** dan re-prediksi `C_base`. Segmen yang udah selesai **tetap** pakai `C_base` yang berlaku waktu itu — jangan di-retro-fit.

**Output:** `RideRecord` di `Models/` — durasi per segmen, `C_base` yang dipakai, `unattributedDuration` (dead field, selalu 0, gak pernah keisi — lihat di atas), flag interpolasi, total dosis aktual.

### 4.7 `DoseCalculator` & `DoseConstants`

Murni fungsi, no networking, no state.

```
Cᵢ         = C_base(grup) × M_road,ᵢ × M_green,ᵢ
tᵢ         = planning : ETA_total × (distanceᵢ / Σ distance)
             live     : durasi terukur RideTracker (kumulatif), dipecah jadi Δtᵢ per update
exposure   = Σ (Cᵢ × tᵢ_menit)                     ← dipakai buat RANKING, planning mode aja
dose_µg    = planning : VE × exposure              ← VE konstan, boleh di luar Σ
             live     : Σᵢ (VEᵢ × Cᵢ × tᵢ_menit), diakumulasi INKREMENTAL per Δtᵢ & VE_sekarang
```

- Ranking pakai `exposure` di planning mode, bukan `dose_µg` (VE konstan → cancel). Live mode gak ada ranking — cuma ngelaporin dosis aktual.
- `congestion_ratio` = **1.0 seragam** di planning mode, jadi bobot waktu = proporsi jarak murni. Ini keputusan terukur, bukan kelalaian: simulasi Monte Carlo nunjukin 0 dari 30 ranking flip. **Jangan bangun tabel lookup 144-cell** — apalagi sekarang, karena live mode ngukur waktu beneran.
- Gate signifikansi: kalau `(exposure_max − exposure_min) / exposure_min < 0.20` → semua rute ditandai **"paparan setara"**, tiebreak ke **waktu tempuh tercepat** (bukan jarak terpendek).
- Detour cap: buang kandidat dengan `ETA > 1.5 × ETA_tercepat`. Untuk sepeda 1.5× itu tenaga yang gak sedikit — kalau ternyata kerasa terlalu longgar di uji coba, turunin dan catat di sini.

**`VE` — laju ventilasi**

```
VE = 0.040 m³/min   (40 L/min)     ← fallback
```

- Fallback dipakai kalau HealthKit gak diotorisasi, Apple Watch gak kepasang, HR ≤ 30 bpm, atau input formula HR-based gak lengkap.
- **HR-based VE udah dipilih dan diimplementasi** — bukan lagi open item. Formula: Greenwald et al. 2019 (RUMUS.md §2.1.1), input HR + age + sex + FVC. `FVC` diestimasi pakai South Asian reference equations, Leong et al. 2022 (RUMUS.md §2.1.2) kalau gak ada FVC terukur di HealthKit.
- Implementasi: protokol `VentilationRateProvider` di `Services/`, `ConstantVentilationRate` (0.040, fallback) + `HealthKitVentilationRateProvider` (HR-based) + `MinuteVentilationEstimator`. HR live dari Apple Watch (`HKWorkoutSession` + `HKLiveWorkoutBuilder`) lewat WatchConnectivity, throttled maks 1× per 5 detik. `FVC` dihitung sekali per ride, gak berubah-ubah sepanjang ride. `V̇E` dihitung ulang tiap `apply()` dipanggil di `LiveRideDoseSession`, pakai HR saat itu.
- **Konsekuensi kritis:** `VE` sekarang bisa berubah-ubah tiap panggilan `apply()`. Live mode WAJIB akumulasi dosis inkremental per-Δt (kontrak §3 poin 8) — `VE` gak boleh ditarik keluar Σ kayak planning mode. Baca RUMUS.md §1 kalau butuh penjelasan lengkap kenapa dua bentuk itu gak lagi ekuivalen begitu `VE` gak konstan.
- Nilai lama 0.014 m³/min (aktivitas ringan / dalam kendaraan) **udah gak berlaku** — itu buat pengendara motor yang duduk diam.

**`F_moda` — TIDAK DIPAKAI**

Faktor moda sengaja dihapus dari rumus. `F_moda = 1.0`, gak muncul di kode sama sekali. Alasannya dua, independen:

1. Buat pesepeda angkanya mendekati 1.0, bukan 1.5. Literatur paparan PM2.5 relatif background: bus 1.65, metro 1.51, jalan kaki 1.33, trem 1.31, mobil 1.09, **sepeda 1.06** — terendah dari semua moda. Nilai 1.5 itu angka pengendara motor, yang duduk di tengah arus persis di belakang knalpot.
2. Risiko double counting dengan `M_road` — dua-duanya narik dari literatur _roadside increment_ yang sama.

Efek gabungan sama perubahan `VE`: `0.014 × 1.5 = 0.021` → `0.040`, angka dosis absolut naik **~1,9×** dibanding versi motor. Ranking gak berubah sama sekali.

**Jangan masukin `F_moda` balik ke kode.** Kalau nemu angka 1.5 di dokumen lama, itu artefak versi motor.

**Open item:** `M_road` masih mengasumsikan `C_base` itu konsentrasi ambient. Kalau sebagian dari 7 stasiun OpenAQ training ternyata roadside, `M_road` bakal double counting sama `C_base`. Perlu dicek dari metadata tipe stasiun OpenAQ v3. Konstan → cancel di ranking, jadi gak nge-blok, tapi harus beres sebelum ada klaim angka absolut.

---

## 5. Aturan UI (non-negotiable, ini yang bikin klaim produk jujur)

- **Headline metric = dosis, bukan konsentrasi.** Rute dengan udara lebih bersih tapi lebih lama bisa punya dosis lebih tinggi. Jangan bikin UI di sekitar `C_rata` (µg/m³).
- **Jangan tampilkan angka presisi di planning mode.** Cuma 43% perjalanan yang akurat dalam ±20%. Tampilkan rentang ("sekitar 45–55 µg"), kategori, atau perbandingan relatif ("rute ini 25% lebih bersih").
- **Bedain visual antara dosis perkiraan dan dosis terukur.** Angka pasca-gowes waktunya beneran diukur, jadi ketidakpastiannya lebih kecil — tapi `C_base`-nya tetap prediksi model. Jangan tampilkan hasil live ride seolah-olah pengukuran sensor.
- **Pewarnaan heatmap pakai `Cᵢ` (konsentrasi), bukan `Cᵢ × tᵢ`**, dan pakai **ambang absolut ISPU / Permen LHK 14/2020**, bukan normalisasi min-max per rute. Kalau pakai min-max, segmen di rute yang seragam kotor bakal keliatan "bersih" secara palsu.

  | Kategori           | PM2.5 (µg/m³) |
  | ------------------ | ------------- |
  | Baik               | 0 – 15,5      |
  | Sedang             | 15,6 – 55,4   |
  | Tidak Sehat        | 55,5 – 150,4  |
  | Sangat Tidak Sehat | 150,5 – 250,4 |
  | Berbahaya          | ≥ 250,5       |

- **Banyak pasangan rute bakal keluar "paparan setara" — itu wajar, jangan diakalin.** PM2.5 didominasi background regional; literatur nunjukin diskriminasi antar rute high/low traffic cuma ~1,15×. Gate 20% lagi kerja sesuai desain. Jangan turunin gate cuma biar UI keliatan lebih "pinter".
- **Klaim yang boleh:** "rute dengan komposisi jalan dan waktu tempuh yang paparannya lebih rendah".
  **Klaim yang dilarang:** "kami menemukan area yang udaranya lebih bersih". Model gak bisa bedain area — pada pasangan rute dengan kontras area ekstrem, arah tebakannya cuma 43,75% benar.
- Sepeda-only. **Gak ada transport mode picker.**
- Semua copy user-facing bahasa Indonesia.

---

## 6. Batasan yang harus tetap kelihatan di dokumen/presentasi

- Resolusi kasar CAMS adalah constraint arsitektural dominan. Untuk rute pendek yang jatuh di satu grup fetch, `C_base` identik → ranking 100% ditentukan formula layer, kontribusi ML ke ranking = nol. Ini pembagian tugas yang disengaja, bukan cacat. (Rute sepeda panjang kepecah jadi beberapa grup — di situ ML mulai punya kontribusi kecil ke ranking. Jangan dibesar-besarkan, tapi juga jangan bilang "selalu nol".)
- **Threshold clustering 20 km masih provisional** dan belum divalidasi lewat sampling sistematis. Belum tau apakah perubahan `base_pm25` di lapangan itu gradual (threshold kecil lebih tepat) atau ada lompatan tajam di titik tertentu. Jangan klaim threshold ini akurat. Lihat `RUMUS.md` §3.1 dan §9.
- Angka nominal 0.4° ≈ 44 km sekarang cuma dipakai sebagai justifikasi kasar buat threshold, **bukan** buat kuantisasi grid. Kuantisasi grid udah kebukti salah secara empiris.
- Effective spatial n = 7 stasiun, berapapun jumlah row (26.716). Fitur spasial gak bisa dipelajari dari situ.
- Error floor arsitektur: 12,13 µg/m³. Model di 23,4% error dosis vs batas teoretis 24,0% — udah mentok.
- Sisa over-prediction: +11,6%.
- Koefisien `M_road` / `M_green` dari literatur, bukan dari data. Struktural, bukan kemalasan.
- Tipe stasiun training belum diverifikasi (roadside vs background) → risiko double counting di `M_road`.
- PM2.5 itu polutan yang lemah buat membedakan rute. Penanda yang kuat adalah black carbon dan UFP (diskriminasi 2,5× dan 1,9×), dan dua-duanya gak tersedia di CAMS.
- Model dilatih & divalidasi di Jabodetabek. `roads_data.json` juga cuma nutup Jabodetabek. Rute sepeda di luar itu = ekstrapolasi.
- **Dosis selama off-route pakai `Cᵢ` segmen aktif menurut proyeksi, bukan konsentrasi aktual di lokasi user** (§4.6). Makin jauh/lama nyimpang dari rute, makin gak representatif — trade-off yang disadari, bukan bug.

---

## 7. Anti-patterns (jangan diulang, udah dibuktikan gagal)

- **Jangan tambah fitur spasial (`road_class`, `greenery_index`, `congestion_ratio`) ke model ML.** SET-8 menghasilkan `correct_direction_rate = 0%`, dikonfirmasi 2× di 2 protokol training. Jalur ini ditutup permanen.
- **Jangan masukin `F_moda` balik.** Lihat §4.7.
- **Jangan bikin layer filter tol manual.** Profil cycling ORS udah nutup ini.
- **Jangan fetch Open-Meteo per segmen.** Per grup hasil clustering jarak. Lihat §4.2.
- **Jangan pakai `floor(lat / 0.4)`, `floor(lon / 0.4)` buat dedup fetch.** Udah dibatalkan secara empiris — dua titik di cell yang sama menurut floor ngasih `base_pm25` beda 23%. Lihat §4.2 dan `RUMUS.md` §3.1.
- **Jangan bikin tabel congestion 144-cell.** Lihat §4.7.
- **Jangan pakai `MKDirections` buat routing.** Cuma ORS.
- **Jangan panggil OpenAQ dari app.** Itu sumber label training, gak pernah runtime.
- **Jangan ganti formula VE HR-based atau estimasi FVC tanpa proses evaluasi kandidat kayak yang udah dilakuin** (RUMUS.md §2.1.1/§2.1.2). Greenwald et al. 2019 + Leong et al. 2022 udah dipilih & diimplementasi — bukan placeholder.
- **Jangan tarik `VE` keluar Σ di live mode.** Begitu VE HR-based, itu ngerusak akumulasi dosis (lihat bug yang udah kejadian, RUMUS.md §2.1.1). Live mode wajib inkremental per-Δt.
- **Jangan bikin cabang khusus buat off-route** (exclude ke `unattributedDuration`, freeze ke `activeSegmentIndex`, atau apapun). Off-route cuma flag UI — lihat §4.6.
- **Jangan over-engineer.** Kalau solusi paling sederhana udah lolos gate yang diukur, berhenti di situ.

---

## 8. Cara kerja yang gw mau

- Jawab langsung, gak usah preamble atau ngulang konteks yang udah ada di sini.
- Kalau ganti isi file, kasih **file lengkap**, bukan diff/potongan.
- Kalau nemu masalah metodologis atau angka yang gak konsisten, **bilang**, jangan diem-diem dibenerin atau ditutupin.
- Kalau ada keputusan arsitektural yang diambil di tengah jalan, tulis alasannya di file ini, bukan cuma di kode.

---

## 9. Dokumen lama yang masih stale

`RUMUS.md` udah sinkron sama file ini, termasuk revisi clustering jarak di §3.1 / §4.2 (grid quantization dibatalkan). Yang belum:

| Dokumen                      | Yang salah                                                                                                                                                                                     |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `v4-summary.md`              | Target motor · `VE = 0.014` · `F_moda = 1.5` · resolusi CAMS ditulis 11 km · filter tol pakai MapKit · `roads_data_2.json` (nama file aktual tanpa suffix) · dedup fetch pakai kuantisasi grid |
| `CleanRoute-ML-Plan_v4.0.md` | Target motor · routing MapKit · filter tol manual · `congestion_ratio` sebagai fungsi deterministik (sekarang 1.0 seragam) · dedup fetch pakai kuantisasi grid                                 |

Dua dokumen itu tetap valid buat bagian **ML/training** (dataset, gate, LOSO, SET-8). Yang stale cuma bagian **runtime/produk**. Kalau ada konflik, `CLAUDE.md` dan `RUMUS.md` yang menang.
