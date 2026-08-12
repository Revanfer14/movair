# RUMUS.md — Formula Dosis CleanRoute

> Referensi tunggal buat rumus final dosis paparan PM2.5 per rute: asal tiap variabel, siapa yang "pegang" dia (model ML / formula deterministik / OpenRouteService / GPS), dan kontrak yang gak boleh dilanggar pas implementasi Swift. Kalau ada perbedaan angka antara dokumen ini dan kode, dokumen ini yang jadi acuan — update dua-duanya bareng.

**Target user: pesepeda.** Versi sebelumnya ditulis untuk pengendara motor. Semua konsekuensi pivot itu udah dibakedin ke dokumen ini — lihat §10 buat daftar perubahannya.

---

## §1. Rumus Final

```
Dosis_rute = VE × Σᵢ (Cᵢ × tᵢ)
```

Breakdown tiap komponen:

```
Cᵢ         = C_base(cellᵢ) × M_road,ᵢ × M_green,ᵢ

tᵢ         = planning : ETA_total_ORS × (distanceᵢ / Σ distance)
             live     : durasi terukur GPS per segmen  (§5.2)
```

`i = 1...n` — segmen hasil potong polyline ORS tiap ~200m (lihat §6).

**Tidak ada `F_moda` di rumus ini.** Faktor moda sengaja tidak dipakai — alasannya di §2.2. Jangan dimasukin balik tanpa baca bagian itu dulu.

**Ranking pakai `Σ(Cᵢ × tᵢ)`, bukan `Dosis_rute`.** `VE` konstan di semua kandidat → cancel total pas dibandingin. `VE` cuma dipakai buat nampilin angka dosis absolut ke user.

**Aturan ranking:**

- Beda `Σ(Cᵢ × tᵢ)` antar rute < 20% → tampilkan "paparan setara", jangan klaim satu lebih bersih.
- Tiebreaker: waktu tempuh tercepat, bukan jarak.
- Detour cap: rute alternatif ditolak kalau `ETA_total > 1.5 × ETA_rute_tercepat`.

---

## §2. Lapisan Konstanta — `VE`

### 2.1 `VE` — laju ventilasi

| Var | Arti | Nilai | Status |
| --- | --- | --- | --- |
| `VE` | Laju ventilasi saat bersepeda | **0.040 m³/min (40 L/min)** | Fallback yang dipakai sekarang |

- Nilai ini dipakai **sekarang dan seterusnya sebagai fallback** kalau data heart rate gak tersedia.
- Idealnya `VE` dihitung per-individu dari heart rate (HealthKit). Rumusnya **belum ditetapkan** — jangan dikarang, jangan diimplementasi setengah-setengah. Sampai rumusnya ada, konstanta ini yang berlaku.
- Desain kode: protokol `VentilationRateProvider`, implementasi `ConstantVentilationRate` mengembalikan 0.040. Versi berbasis HR nyusul sebagai implementasi kedua tanpa nyentuh `DoseCalculator`.

**Nilai lama `0.014 m³/min` udah gak berlaku.** Itu angka aktivitas ringan / duduk di kendaraan (Mainka et al. 2025, diturunkan dari U.S. EPA Exposure Factors Handbook 2011), cocok buat pengendara motor yang duduk diam. Bersepeda = aktivitas moderat–berat, ventilasinya jauh lebih tinggi.

Efek gabungan dengan penghapusan `F_moda`:

```
Versi motor    : 0.014 × 1.5 = 0.021 m³/min efektif
Versi sepeda   : 0.040       = 0.040 m³/min efektif
Net            : angka dosis absolut naik ~1.9×
```

Itu bener, bukan bug. Ranking gak berubah sama sekali.

### 2.2 `F_moda` — TIDAK DIPAKAI (F_moda = 1.0)

Faktor moda **sengaja dihapus dari rumus.** Ini keputusan terdokumentasi, bukan kelalaian. Ditulis di sini supaya gak ada yang baca angka `1.5` di dokumen lama (`v4-summary.md`, `CleanRoute-ML-Plan_v4.0.md`) terus masukin balik.

**Apa itu `F_moda`:** rasio konsentrasi PM2.5 yang beneran dihirup di arus lalu lintas vs konsentrasi ambient area. Versi motor pakai 1.5, diambil dari literatur pengendara motor (rentang ~1.3–3.2).

**Kenapa dihapus — dua alasan independen:**

1. **Buat pesepeda angkanya mendekati 1.0, bukan 1.5.** Studi yang ngebandingin 6 moda di rute yang sama, dinormalisasi ke background: bus 1.65, metro 1.51, jalan kaki 1.33, trem 1.31, mobil 1.09, **sepeda 1.06** — paling rendah dari semua moda. Masuk akal secara fisik: motor duduk di tengah arus persis di belakang knalpot, pesepeda menepi ke bahu jalan / jalur sepeda.

2. **Risiko double counting dengan `M_road`.** Dua-duanya narik dari kolam literatur yang sama (*roadside increment studies*). `M_road = 1.25` udah bilang "pinggir arteri lebih kotor dari ambient"; `F_moda = 1.5` bilang lagi hal yang mirip. Dipasang dua-duanya → `1.25 × 1.5 = 1.875×` di atas ambient untuk arteri, susah dipertahanin.

**Keputusan:** efek pinggir jalan sepenuhnya dibawa `M_road`. `F_moda` = 1.0, dihilangkan dari rumus.

---

## §3. `C_base` — Output Model ML (Lapis 1)

```
C_base(cell) = expm1( model_gbr_v4_log.predict([
    base_pm25, wind_speed, relative_humidity, hour_of_day, is_weekend
]) )
```

| Var | Asal | Catatan |
| --- | --- | --- |
| `base_pm25` | Open-Meteo Air Quality API (CAMS) | Resolusi **0.4° ≈ 44 km** (CAMS global) |
| `wind_speed` | Open-Meteo Forecast API | **Wajib m/s** — API default-nya km/jam |
| `relative_humidity` | Open-Meteo Forecast API | % |
| `hour_of_day` | Jam device | **WIB, bukan UTC, bukan `TimeZone.current`** |
| `is_weekend` | Hari device | 0/1, dari WIB |
| output | `CleanRoutePM25.mlmodel` (GBR, skala log) | **Wajib `expm1()`** — lupa ini = dosis salah ~50× |

### 3.1 Granularitas: per CAMS cell, bukan per segmen, bukan per rute

Ini perubahan dari versi sebelumnya yang nulis fetch per segmen.

Alasannya: grid CAMS global 0.4° ≈ 44 km. Untuk rute pendek, fetch per segmen artinya ratusan request buat angka yang **identik persis**. Tapi pesepeda bisa nempuh > 44 km, dan rute segitu pasti nyebrang cell — jadi "1 fetch per rute" juga salah.

Aturan yang bener:

1. Tiap segmen dipetakan ke index cell: `floor(lat / 0.4)`, `floor(lon / 0.4)`.
2. Dedupe → himpunan cell unik yang dilewati rute.
3. Fetch air quality + weather **1× per cell unik**, pakai koordinat centroid cell.
4. Panggil CoreML **1× per cell unik** → `C_base` per cell.
5. Tiap segmen ambil `C_base` dari cell-nya sendiri.

Rute 10 km → 1 fetch. Rute 60 km → 2–3 fetch. Cap keras **8 fetch per request**; kalau lebih, kasih tau user rutenya di luar cakupan yang divalidasi dan jangan lanjut diam-diam.

**Jangan interpolasi antar cell.** Nilai per cell dipakai apa adanya. Batas cell bikin `Cᵢ` melompat, dan itu representasi jujur dari resolusi CAMS — bukan artefak yang perlu dihaluskan.

> Catatan: angka "~11 km" di `v4-summary.md` §2 itu stale — 11 km adalah resolusi CAMS **Europe**. Indonesia dilayani CAMS **global**, 0.4° ≈ 44 km. Angka 44 km yang operatif.

### 3.2 Granularitas waktu di live mode

Ride sepeda gampang lewat batas jam. `hour_of_day` adalah fitur ML terkuat kedua (20% importance) dan pola bias CAMS berubah tajam sore–malam (kelebihan ~20 µg/m³ jam 18–05, cuma ~5 di siang hari).

- Tiap pergantian jam WIB selama ride: re-fetch Open-Meteo untuk cell aktif dan re-prediksi `C_base`.
- Segmen yang udah selesai **tetap** pakai `C_base` yang berlaku waktu itu. Jangan di-retro-fit.

### 3.3 Sifat model

Model ini **buta lokasi**. Dia gak tau lagi diminta buat segmen ke berapa atau rute mana — cuma nerima 5 angka, balikin 1 angka. Informasi "segmen ini di koordinat mana" udah hilang begitu masuk ke 5 fitur; yang nentuin isi 5 angka itu adalah proses fetch **sebelum** model dipanggil.

**Kenapa cuma 5 fitur ini** (bukan O2/CO2/CO/NO2/dll):

- O2/CO2 gak tersedia di Open-Meteo sama sekali.
- O2 nyaris konstan di atmosfer (~20.9%) → zero variance, gak ada sinyal.
- CO2 variasinya musiman/global, bukan sinyal per-jam yang relevan buat koreksi lokal.
- Polutan lain (CO, NO2, SO2, O3) di Open-Meteo sengaja di-exclude karena keluaran sistem CAMS yang sama dengan `base_pm25` — nambah mereka cuma nambah gejala dari bias yang sama, bukan sinyal koreksi independen.
- `wind_speed` & `relative_humidity` dipilih karena driver meteorologis PM2.5 yang established: angin = dispersi/dilusi, kelembapan = hygroscopic growth partikel + proxy stabilitas atmosfer.

**Jangan tambah fitur spasial ke ML.** SET-8 (`road_class`, `greenery_index`, `congestion_ratio` sebagai fitur) menghasilkan `correct_direction_rate = 0%`, dikonfirmasi 2× di 2 protokol training. Effective spatial n = 7 stasiun berapapun jumlah row. Jalur ini ditutup permanen.

---

## §4. `M_road`, `M_green` — Formula Deterministik (Lapis 2)

```
M_road,ᵢ  = lookup(road_classᵢ)     dari roads_data.json
M_green,ᵢ = 1 − 0.05 × greenery_indexᵢ
```

| road_class | Contoh | M_road | Asal |
| --- | --- | --- | --- |
| 1 (tol) | — | tidak muncul (§4.2) | Legal — sepeda dilarang masuk tol |
| 2 (arteri) | Jl. Sudirman | 1.25 | Studi roadside-increment (literatur) |
| 3 (kolektor) | Jalan raya biasa | 1.15 | idem |
| 4 (lokal) | Gang, komplek | 1.00 | idem |

`road_classᵢ` dan `greenery_indexᵢ` didapat dari lookup koordinat segmen ke `roads_data.json` (grid precomputed dari OpenStreetMap, 147.027 cell, resolusi ~166m). **Bukan** dari model ML, **bukan** dari ORS. Lookup ini tetap **per segmen** — inilah satu-satunya bagian yang beneran butuh granularitas per segmen.

**Sifat penting:** ini satu-satunya sumber diferensiasi spasial untuk rute pendek. `base_pm25` (~44 km) dan model ML gak bisa bedain jalan arteri dari gang — yang bikin dua rute punya dosis beda hampir seluruhnya berasal dari lapisan ini. Setelah `F_moda` dihapus, lapisan ini juga satu-satunya yang membawa efek pinggir jalan (§2.2).

(Untuk rute panjang yang nyebrang CAMS cell, `C_base` mulai ikut berkontribusi ke perbedaan. Kecil, tapi bukan nol lagi — jangan bilang "kontribusi ML ke ranking selalu nol".)

### 4.1 Penanganan cell bermasalah

- **Cell miss** (koordinat di luar grid Jabodetabek): default `road_class = 4`, `greenery_index = 0` → M_road 1.00, M_green 1.00. Netral, bukan optimistis.
- Kalau > 30% segmen kena default, kasih tau user bahwa akurasi di luar Jabodetabek menurun. Jangan diam.
- **Cell `road_class = 1` nyempil**: seharusnya gak pernah muncul (§4.2). Kalau muncul, itu artefak snapping grid 166m — perlakukan sebagai kolektor (1.15) dan catat sebagai anomali. **Jangan buang segmennya**, itu ngerusak kontrak `Σtᵢ = ETA` di planning mode.

### 4.2 Filter tol

Ditangani sepenuhnya oleh **profil `cycling-regular` di OpenRouteService**. Profil sepeda gak pernah ngasih rute lewat tol/motorway. **Gak perlu layer filter tol sendiri**, gak perlu `tollPreference`, gak perlu pencocokan `road_class = 1`.

Ini menggantikan aturan lama yang nyuruh pakai `MKDirections.tollPreference = .avoid`.

### 4.3 Open item — verifikasi tipe stasiun training

Belum ditutup. `M_road` mengasumsikan `C_base` itu konsentrasi **ambient/background**. Kalau sebagian dari 7 stasiun OpenAQ yang dipakai training ternyata **roadside**, maka `C_base` udah mengandung sebagian efek pinggir jalan, dan `M_road` bakal double counting.

- Cek metadata tipe stasiun di OpenAQ v3 untuk ketujuh stasiun.
- Kalau mayoritas roadside → `M_road` perlu diturunkan, atau `C_base` diperlakukan sebagai konsentrasi roadside dan `M_road` jadi faktor relatif antar kelas jalan (bukan relatif ambient).
- Konstan/deterministik → **cancel di ranking**. Cuma ngaruh ke angka absolut. Gak nge-blok development, tapi harus beres sebelum klaim angka absolut.

---

## §5. `tᵢ` — Distribusi Waktu per Segmen

Ada **dua mode** dan bedanya fundamental. Jangan campur.

### 5.1 Planning mode (sebelum berangkat)

```
tᵢ = ETA_total_ORS × (distanceᵢ / Σ distance)
```

| Var | Asal |
| --- | --- |
| `ETA_total_ORS` | `features[].properties.summary.duration` (detik) — satu angka utuh buat seluruh rute |
| `distanceᵢ` | Panjang segmen (~200m), hasil potong polyline ORS |

- `congestion_ratio` = **1.0 seragam**, jadi bobot waktu = proporsi jarak murni. Ini keputusan terukur, bukan kelalaian: simulasi Monte Carlo nunjukin 0 dari 30 ranking flip. **Tabel lookup 144-cell sengaja tidak dibangun.**
- `duration` dari profil `cycling-regular` **valid apa adanya** untuk pesepeda. Gak ada faktor koreksi kecepatan. (Ini beda dari versi motor, di mana profil sepeda cuma proxy dan durasinya kepanjangan.)
- **Kontrak wajib:** `Σ tᵢ` harus balik **persis** ke `ETA_total_ORS`. Ini bukan estimasi waktu baru — cuma pecahan proporsional dari angka yang udah ditampilkan & dipercaya user.

### 5.2 Live mode (selama gowes) — pengukuran real-time

`tᵢ` **diukur**, bukan diestimasi. Event-based segment timer, bukan rekonstruksi log GPS pasca-gowes.

Perilaku: user masuk segmen-1 → timer segmen-1 mulai dari 0. User keluar zona segmen-1 → timer segmen-1 stop, timer segmen-2 mulai dari 0. Terus sampai selesai.

**Map-matching per update lokasi:**

1. Proyeksikan posisi GPS ke polyline rute terpilih → titik terdekat + jarak kumulatif sepanjang rute.
2. Jarak kumulatif → index segmen (dari batas kumulatif §6).
3. Index beda dari segmen aktif → transisi.

**Anti-flapping (wajib):** akurasi GPS di jalan perkotaan ±10–20m, sementara segmen cuma 200m. Tanpa guard, timer loncat-loncat di batas dan durasi per segmen jadi sampah.

- Transisi diterima kalau posisi udah **≥ 20m melewati batas** segmen berikutnya.
- Terima transisi **maju** secara default. Mundur cuma diterima kalau bertahan ≥ 3 update berturut-turut.
- Loncat > 1 segmen dalam 1 update: isi segmen yang keloncat dengan durasi interpolasi dari jarak, tandai `interpolated = true`.

**Akumulasi:**

- Pakai jam monotonik (`systemUptime` / `CLLocation.timestamp`), bukan `Date()` — kebal perubahan jam sistem.
- Akumulasi per index segmen, bukan overwrite. Segmen bisa dilewati lebih dari sekali.
- **Durasi berhenti tetap dihitung.** Berhenti di lampu merah tetap napas, tetap kena paparan.

**Off-route:**

- Jarak tegak lurus ke polyline > 50m selama > 15 detik → status `offRoute`.
- **v1: terima gapnya.** Waktu off-route masuk bucket `unattributedDuration`, gak dibebankan ke segmen manapun.
- Tampilkan di ringkasan: "X menit di luar rute — gak dihitung dalam dosis". Jangan diam-diam dihilangkan, jangan juga dikarang.
- Balik ke dalam 50m → lanjut dari segmen hasil proyeksi saat itu.

**Kontrak:** di live mode `Σ tᵢ` = durasi aktual terukur, dan **tidak dipaksa** sama dengan `ETA_total_ORS`. Beda antara keduanya itu informasi, bukan error.

---

## §6. Segmentasi Rute (`i = 1...n`)

- Sumber: `features[].geometry.coordinates` dari response GeoJSON OpenRouteService. **Koordinat ORS urutannya `[lon, lat]`** — kebalik dari `CLLocationCoordinate2D`.
- Potong tiap interval tetap, default **200m**:
  1. Hitung jarak kumulatif sepanjang polyline pakai `CLLocation.distance(from:)`, bukan Euclidean derajat.
  2. Tiap kelipatan 200m, interpolasi linear antar 2 titik polyline terdekat buat dapetin koordinat potongan.
  3. Sisa terakhir jadi segmen pendek (< 200m).
- 200m dipilih karena ≈ resolusi grid `roads_data.json` (166m). Jangan dibikin lebih halus — cuma nambah lookup redundan ke cell yang sama.
- Tiap segmen simpan: index, koordinat awal/akhir, **jarak kumulatif awal & akhir**. Nilai kumulatif itu yang dipakai map-matching di §5.2.
- Rute 60 km → ~300 segmen. Struktur harus tetap enteng: array of struct.
- Tiap segmen dipakai buat **2 lookup independen**:
  - koordinat → CAMS cell → `C_base` (§3, di-share antar segmen dalam cell yang sama)
  - koordinat → grid jalan → `M_road`/`M_green` (§4, per segmen)

  Dua-duanya gak saling tahu satu sama lain.

---

## §7. Ringkasan Kepemilikan

```
OpenRouteService  → ETA_total, geometri polyline, filter tol   (gak tau apa-apa soal PM2.5)
MapKit            → render peta + geocoding                     (bukan routing)
Model ML          → C_base per CAMS cell                        (buta lokasi, cuma paham cuaca+waktu)
roads_data.json   → M_road, M_green per segmen                  (buta cuaca, cuma paham geometri jalan)
GPS / RideTracker → tᵢ aktual di live mode                      (buta polusi, cuma paham posisi+waktu)
Formula Swift     → gabungin semua jadi Cᵢ, tᵢ, Σ(Cᵢ×tᵢ)        (satu-satunya titik ketemu)
```

Semua sumber di atas independen total — gak pernah "ngobrol" sampai ketemu di titik perkalian terakhir di `DoseCalculator`.

---

## §8. Kontrak Kritis (jangan sampai dilanggar)

Kesalahan di poin 1–4 bikin app **diam-diam salah tanpa error** — gak crash, cuma angkanya ngaco. Makanya ditulis eksplisit:

```
1. expm1() pada output model             ← lupa = dosis salah ~50×
2. Angin dalam meter/detik               ← Open-Meteo default km/jam
3. Jam & hari pakai WIB                  ← bukan UTC, bukan TimeZone.current
4. Koordinat ORS urutannya [lon, lat]    ← kebalik dari CLLocationCoordinate2D
5. Filter tol pakai profil cycling ORS   ← bukan roads_data.json, bukan MapKit
6. Konstanta rumus HARUS sama persis:
     M_road  : arteri 1.25 · kolektor 1.15 · lokal 1.00
     M_green : 1 − 0.05 × greenery_index
     VE      : 0.040 m³/min
     F_moda  : TIDAK DIPAKAI (§2.2) — jangan dimasukin balik
     Dosis   : 0.040 × Σ(PM2.5 × M_road × M_green × menit)
7. Σtᵢ = ETA_total_ORS            ← HANYA di planning mode
   Σtᵢ = durasi terukur           ← di live mode, sengaja beda dari ETA
```

---

## §9. Batasan yang Harus Tetap Kelihatan

- Model dilatih & divalidasi di **Jabodetabek** (7 stasiun, 210 hari, 26.716 baris). `roads_data.json` juga cuma nutup Jabodetabek. Rute sepeda di luar itu = ekstrapolasi.
- Error floor arsitektur: **12,13 µg/m³**. Error dosis per perjalanan 23,4% vs batas teoretis 24,0% — model udah mentok, gak ada lagi yang bisa diperas.
- Sisa over-prediction: **+11,6%**.
- Cuma **43%** perjalanan akurat dalam ±20%. Jangan tampilkan angka presisi — pakai rentang, kategori, atau perbandingan relatif.
- Koefisien `M_road` / `M_green` dari literatur, bukan dipelajari dari data. Struktural (7 stasiun, konstan per stasiun), bukan kemalasan.
- **Tipe stasiun training belum diverifikasi** (roadside vs background) → risiko double counting di `M_road`, lihat §4.3.
- **PM2.5 itu polutan yang lemah buat membedakan rute.** Literatur nunjukin diskriminasi antar rute high/low traffic cuma ~1,15×, karena PM2.5 didominasi background regional; penanda yang kuat adalah black carbon dan UFP (2,5× dan 1,9×), dan dua-duanya gak tersedia di CAMS. Ini konsisten dengan temuan internal: arah tebakan cuma **43,75%** benar di pasangan rute kontras ekstrem. Konsekuensinya banyak pasangan rute bakal keluar "paparan setara" — itu gate 20% kerja sesuai desain, bukan bug.
- Boleh klaim: _"rute dengan komposisi jalan dan waktu tempuh yang paparannya lebih rendah"_. **Tidak boleh** klaim: _"kami menemukan area yang udaranya lebih bersih"_.

---

## §10. Perubahan dari Versi Sebelumnya

| # | Versi lama | Sekarang | Alasan |
| --- | --- | --- | --- |
| 1 | Target pengendara motor | **Pesepeda** | Pivot produk |
| 2 | `VE = 0.014 m³/min` | **`0.040 m³/min`** | 0.014 = duduk di kendaraan. Sepeda = aktivitas moderat–berat. Ideal: dari heart rate |
| 3 | `F_moda = 1.5` | **Dihapus (= 1.0)** | Literatur: paparan PM2.5 pesepeda ~1,06× background (terendah dari 6 moda). Plus risiko double counting dengan `M_road` |
| 4 | `Dosis = VE × Σ(Cᵢ×tᵢ)` di §1, tapi `0.014 × 1.5 × ...` di §8 | **`VE × Σ(Cᵢ×tᵢ)`** konsisten di dua tempat | Dokumen lama inkonsisten sama dirinya sendiri. Resolve ke bentuk §1 |
| 5 | 2 lookup independen per segmen (cuaca + jalan) | Cuaca/CAMS **per CAMS cell 0.4°**; jalan tetap **per segmen** | Fetch per segmen redundan total di grid 44 km, tapi "1× per rute" salah buat rute > 44 km |
| 6 | `tᵢ` selalu pecahan proporsional ETA | Planning proporsional; **live diukur GPS real-time** | Timer per segmen ngilangin proxy `congestion_ratio` sepenuhnya di live mode |
| 7 | `Σtᵢ = ETA` mutlak | Berlaku **cuma di planning mode** | Live mode `Σtᵢ` = durasi aktual |
| 8 | Routing pakai `MKDirections` | **OpenRouteService** (`cycling-regular`) | MapKit cuma buat render peta + geocoding |
| 9 | Filter tol pakai `tollPreference = .avoid` | Ditangani profil cycling ORS | Profil sepeda gak pernah ngasih rute motorway |
| 10 | `congestion_ratio` = fungsi `hour × road_class × is_weekend` | **1.0 seragam** | Monte Carlo: 0/30 ranking flip. Tabel 144-cell sengaja tidak dibangun |
| 11 | Resolusi CAMS ditulis 11 km di `v4-summary.md` | **0.4° ≈ 44 km** | 11 km = CAMS Europe. Indonesia pakai CAMS global |

Efek gabungan item 2 + 3 ke angka dosis absolut: `0.014 × 1.5 = 0.021` → `0.040`, naik **~1,9×**. Ranking gak berubah sama sekali.

---

## Lampiran — Contoh Perhitungan (ilustrasi, angka fiktif)

Rute pendek ~4 km, seluruhnya dalam 1 CAMS cell → `C_base = 37,9 µg/m³` konstan. `M_green = 1,00` (greenery 0) buat menyederhanakan.

### Planning mode

| Rute | Segmen | road_class | M_road | Cᵢ | tᵢ (menit) | Cᵢ × tᵢ |
| --- | --- | --- | --- | --- | --- | --- |
| **A — lewat arteri** | 1 | arteri | 1,25 | 47,4 | 10 | 474 |
| | 2 | kolektor | 1,15 | 43,6 | 6 | 262 |
| | **Total** | | | | **16** | **736** |
| **B — lewat gang** | 1 | lokal | 1,00 | 37,9 | 9 | 341 |
| | 2 | kolektor | 1,15 | 43,6 | 8 | 349 |
| | **Total** | | | | **17** | **690** |

`C_base` identik di semua baris (satu cell, model gak bedain lokasi). Beda paparan A (736) vs B (690) murni dari `M_road` per segmen — bukti bahwa diferensiasi spasial di rute pendek 100% berasal dari `roads_data.json`.

Dosis absolut:

```
A : 0,040 × 736 = 29,4 µg
B : 0,040 × 690 = 27,6 µg
```

Beda paparan `(736 − 690) / 690 = 6,7%` → di bawah gate 20% → app tampilkan **"paparan setara"**, tiebreak ke rute **A** (lebih cepat, 16 menit).

> Bandingkan versi motor (`0,014 × 1,5 = 0,021`): rute A jadi 15,5 µg. Kenaikan ~1,9× itu murni dari ventilasi pesepeda dikurangi penghapusan `F_moda`, bukan perubahan model.

### Live mode (user pilih rute A, ternyata lebih lambat)

| Segmen | Cᵢ | tᵢ terukur | Cᵢ × tᵢ |
| --- | --- | --- | --- |
| 1 | 47,4 | 12 | 569 |
| 2 | 43,6 | 7 | 305 |
| **Total** | | **19** | **874** |

```
Dosis aktual = 0,040 × 874 = 35,0 µg
```

Perkiraan 29,4 µg → aktual 35,0 µg. Selisihnya dari waktu tempuh nyata yang 3 menit lebih lama dari ETA ORS. **Ini yang dilaporkan ke user sebagai dosis aktual**, dan bedanya dari perkiraan boleh ditampilkan apa adanya — itu informasi, bukan error.
