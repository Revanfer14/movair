# RUMUS.md — Formula Dosis CleanRoute

> Referensi tunggal buat rumus final dosis paparan PM2.5 per rute: asal tiap variabel, siapa yang "pegang" dia (model ML / formula deterministik / OpenRouteService / GPS), dan kontrak yang gak boleh dilanggar pas implementasi Swift. Kalau ada perbedaan angka antara dokumen ini dan kode, dokumen ini yang jadi acuan — update dua-duanya bareng.

**Target user: pesepeda.** Versi sebelumnya ditulis untuk pengendara motor. Semua konsekuensi pivot itu udah dibakedin ke dokumen ini — lihat §10 buat daftar perubahannya.

---

## §1. Rumus Final

**Planning mode** — `VE` satu nilai konstan buat seluruh rute (belum ada HR live sebelum berangkat), jadi boleh ditarik keluar Σ:

```
Dosis_rute = VE × Σᵢ (Cᵢ × tᵢ)
```

**Live mode** — `VE` bisa berubah tiap update HR (§2.1.1), jadi **wajib** di dalam Σ:

```
Dosis_rute = Σᵢ (VEᵢ × Cᵢ × tᵢ)
```

`VEᵢ` = laju ventilasi yang beneran berlaku pas porsi waktu `tᵢ` itu dijalani — **bukan** VE saat ini dikalikan ke seluruh riwayat paparan sejak awal ride. Kalau `VE` konstan (fallback 0.040), dua bentuk di atas identik secara aljabar — VE bisa ditarik keluar Σ tanpa mengubah hasil. Begitu `VE` berbasis HR dan HR berubah-ubah sepanjang ride, dua bentuk itu **tidak lagi ekuivalen**; cuma bentuk kedua (VE di dalam Σ) yang benar secara fisik.

**Implementasi live mode:** `tᵢ` di `RideTracker` itu kumulatif sejak awal ride (gak pernah reset), jadi rumus di atas gak boleh dihitung ulang dari nol tiap update lokasi — itu sama saja narik VE saat ini keluar Σ lagi lewat pintu belakang. Yang diakumulasi adalah dosis **inkremental** per update:

```
Δtᵢ     = tᵢ_sekarang − tᵢ_update-sebelumnya     (per segmen, ≥ 0)
Δdosis  = VE(HR_saat_ini) × Σᵢ (Cᵢ × Δtᵢ)
dosis_total += Δdosis
```

Cuma porsi waktu yang baru (`Δtᵢ`) yang dinilai pakai HR saat ini; porsi waktu yang udah lewat tetap "terkunci" ke `VE` yang berlaku waktu itu, karena udah ditambahkan ke `dosis_total` di update-update sebelumnya dan gak dihitung ulang. Lihat §5.2 dan `LiveRideDoseSession.swift`.

Breakdown tiap komponen:

```
Cᵢ         = C_base(cellᵢ) × M_road,ᵢ × M_green,ᵢ

tᵢ         = planning : ETA_total_ORS × (distanceᵢ / Σ distance)
             live     : durasi terukur GPS per segmen (kumulatif) — dipecah jadi Δtᵢ per update, lihat di atas
```

`i = 1...n` — segmen hasil potong polyline ORS tiap ~200m (lihat §6).

**Tidak ada `F_moda` di rumus ini.** Faktor moda sengaja tidak dipakai — alasannya di §2.2. Jangan dimasukin balik tanpa baca bagian itu dulu.

**Ranking pakai `Σ(Cᵢ × tᵢ)`, bukan `Dosis_rute`.** Ranking kejadian di planning mode (sebelum berangkat), tempat `VE` masih konstan di semua kandidat rute → cancel total pas dibandingin. `VE` cuma dipakai buat nampilin angka dosis absolut ke user, gak pernah buat nentuin rute mana yang direkomendasikan.

**Aturan ranking:**

- Beda `Σ(Cᵢ × tᵢ)` antar rute < 20% → tampilkan "paparan setara", jangan klaim satu lebih bersih.
- Tiebreaker: waktu tempuh tercepat, bukan jarak.
- Detour cap: rute alternatif ditolak kalau `ETA_total > 1.5 × ETA_rute_tercepat`.

---

## §2. Lapisan Konstanta — `VE`

### 2.1 `VE` — laju ventilasi

| Var  | Arti                          | Nilai                       | Status                         |
| ---- | ----------------------------- | --------------------------- | ------------------------------ |
| `VE` | Laju ventilasi saat bersepeda | **0.040 m³/min (40 L/min)** | Fallback yang dipakai sekarang |

- Nilai ini dipakai **sekarang dan seterusnya sebagai fallback** kalau data heart rate gak tersedia (HealthKit gak diotorisasi, Apple Watch gak kepasang, HR ≤ 30 bpm, atau salah satu input formula §2.1.1 gak lengkap).
- Idealnya `VE` dihitung per-individu dari heart rate (HealthKit). Rumusnya **udah dipilih dan udah diimplementasi** — lihat §2.1.1 — di `HealthKitVentilationRateProvider` + `MinuteVentilationEstimator`.
- Desain kode: protokol `VentilationRateProvider`, implementasi `ConstantVentilationRate` mengembalikan 0.040, dan `HealthKitVentilationRateProvider` (§2.1.1) sebagai implementasi kedua yang jatuh balik ke `ConstantVentilationRate` kalau input gak lengkap. `DoseCalculator` sendiri gak berubah — yang berubah adalah **cara live mode manggil dia**: per-increment waktu, bukan per-total-riwayat (lihat §1).

### 2.1.1 Formula HR-based — Greenwald et al. 2019 (dipilih, sudah diimplementasi)

```
V̇E = exp(-9.59) × HR^2.39 × age^0.274 × sex^-0.204 × FVC^0.520
```

| Var | Asal | Catatan |
| --- | --- | --- |
| `HR` | HealthKit, live, dari `HKWorkoutSession` + `HKLiveWorkoutBuilder` | bpm, real-time selama ride |
| `age` | HealthKit `dateOfBirth` | tahun |
| `sex` | HealthKit `biologicalSex` | **1 = pria, 2 = wanita** (encoding asli paper, bukan pilihan kita). `.other`/`.notSet`/gak diotorisasi → **default ke 1 (pria)** — keputusan produk, dicatat di sini, bukan di kode |
| `FVC` | **Diestimasi**, bukan diukur | lihat di bawah |

**Sumber:** Greenwald R, Hayat MJ, Dons E, Giles L, Villar R, Jakovljevic DG, Good N. 2019. "Estimating minute ventilation and air pollution inhaled dose using heart rate, breath frequency, age, sex and forced vital capacity: A pooled-data analysis." *PLoS ONE* 14(7): e0218673. DOI: [10.1371/journal.pone.0218673](https://doi.org/10.1371/journal.pone.0218673). Dipilih dari 2 kandidat yang dievaluasi — menang karena:

- Pooled data 471 subjek, umur 4–80, sex seimbang, 5 negara, 3 benua — jauh lebih luas dari kandidat lain (Oneda dkk., *Physiological Reports* 2026, "A Bayesian approach to estimate minute ventilation from heart rate during exercise for assessing environmental exposures of females", DOI: [10.14814/phy2.70767](https://physoc.onlinelibrary.wiley.com/doi/10.14814/phy2.70767) — cuma 19 subjek wanita, treadmill running doang).
- Aktivitas yang di-cover termasuk **cycling**, bukan cuma running.
- **Gak butuh kalibrasi lab** (VT1/VT2 dari CPET) kayak model berbasis domain intensitas — kandidat lain gak kepake justru karena itu: gak mungkin device konsumer nentuin domain intensitas tanpa tes lab.

**Akurasi — dicatat apa adanya:** median cross-validated percent error 0.664% (nyaris gak bias secara rata-rata), tapi **IQR 45.4 persentase poin** — prediksi per-menit individual bisa meleset jauh meskipun rata-ratanya gak bias. Ini error tambahan di atas error dosis yang udah ada (§9: cuma 43% perjalanan akurat ±20%) — belum dievaluasi gimana keduanya bertumpuk. Jangan klaim akurasi VE yang lebih baik dari ini.

**`FVC` gak bisa diambil langsung dari Apple Watch.** HealthKit punya tipe `HKQuantityTypeIdentifier.forcedVitalCapacity`, tapi Apple Watch gak pernah nulis ke situ — cuma keisi kalau user pernah pakai app/device spirometer terpisah (jarang). Dua opsi:

1. **FVC terukur** (kalau kebetulan ada di HealthKit) — dipakai apa adanya kalau tersedia.
2. **FVC diestimasi** dari `height` + `age` + `sex` (semua ada di HealthKit) + etnis, pakai persamaan referensi. **Belum di-pin — task terpisah, lihat §2.1.2.**

### 2.1.2 Sumber estimasi FVC — DIPILIH: South Asian reference equations (Leong et al. 2022)

```
FVC (L) = intercept − 0.0224×age + 0.0458×height_cm     (pria)
FVC (L) = intercept − 0.0200×age + 0.0305×height_cm     (wanita)

Pria   : intercept = −3.349
Wanita : intercept = −1.533
```

`age` dalam tahun, `height` dalam **cm** (beda dari formula V̇E di §2.1.1 yang makein meter — jangan ketuker unit pas implementasi).

**Sumber:** Leong WY, Gupta A, Hasan M, dkk. 2022. "Reference equations for evaluation of spirometry function tests in South Asia, and among South Asians living in other countries." *European Respiratory Journal* 60(6): 2102962. DOI: [10.1183/13993003.02962-2021](https://doi.org/10.1183/13993003.02962-2021). Open access, koefisien di Tabel 2 (Model M1: umur + tinggi doang, gak pakai berat/region — didesain penulisnya biar "konsisten dipakai kayak GLI 2012 dan NHANES III").

**Kenapa ini yang dipilih** — 4 kandidat dievaluasi total, urutan kronologis:

1. **Hankinson NHANES III (1999)** — Hankinson JL, Odencrantz JR, Fedan KB. "Spirometric reference values from a sample of the general U.S. population." *Am J Respir Crit Care Med* 159(1): 179–187. Closed-form (polinomial `intercept + a·age + b·age² + c·height²`), tapi **ditolak**: cuma 3 kategori ras (Caucasian, African American, Mexican American) — gak ada kategori Asia sama sekali.
2. **GLI-2012** — Quanjer PH, Stanojevic S, Cole TJ, dkk. 2012. "Multi-ethnic reference values for spirometry for the 3–95-yr age range: the global lung function 2012 equations." *Eur Respir J* 40(6): 1324–1343. Punya kategori "North East Asian"/"South East Asian", tapi **ditolak**: bukan closed-form (spline LMS/GAMLSS, butuh tabel lookup umur-per-umur), dan tetep harus milih kategori etnis per user.
3. **GLI Global 2022** — Bowerman C, dkk. 2023. "A Race-neutral Approach to the Interpretation of Lung Function Measurements." *Am J Respir Crit Care Med*. Race-neutral (gak perlu nanya etnis user), didukung rekomendasi ATS/ERS April 2023. **Ditolak buat sekarang**, dua alasan: (a) tetep spline-based, butuh tabel `Mspline`/`Sspline` resmi dari GLI yang gak bisa diambil langsung (ersnet.org nolak automated fetch, dan tools resminya **"by law" dibatasi buat riset/edukasi/validasi software, bukan buat dipakai di produk**, belum jelas cakupannya buat use-case CleanRoute); (b) package open-source `rspiro` yang implementasi formulanya berlisensi **GPL (≥2)** — copy kode/tabelnya langsung ke codebase komersial CleanRoute berisiko ketarik kewajiban copyleft GPL.
4. **South Asian (Leong et al. 2022)** — **dipilih.** Closed-form (linear doang, `intercept + a·age + b·height`), gak ada isu lisensi (paper open access biasa, bukan software berlisensi khusus), tervalidasi di 5.589 subjek net-never-smoker dari Bangladesh/India Utara/India Selatan/Pakistan/Sri Lanka + validasi eksternal 339 orang South Asian di Singapura (studi HELIOS), umur 18–85.

**Catatan jujur soal fit populasi:** South Asian **bukan** Asia Tenggara/Indonesia. Ini bukan formula yang divalidasi buat orang Jakarta — tapi dari semua kandidat yang dicek, ini yang paling deket secara geografis/genetik (apalagi ada lengan validasi Singapura) dari opsi yang beneran bisa diimplementasi tanpa tabel spline atau lisensi bermasalah. Kalau nanti ada waktu buat ngurus akses GLI Global 2022 resmi (klarifikasi syarat pemakaian ke ERS/GLI network), itu tetep upgrade yang lebih bener secara metodologis — lihat langkah 3 di atas.

**Status implementasi:** formula V̇E (§2.1.1) dan estimasi FVC (§2.1.2) **udah diimplementasi** di `HealthKitVentilationRateProvider` + `MinuteVentilationEstimator`. Urutan yang dipakai: (1) HealthKit authorization + baca `height`/`dateOfBirth`/`biologicalSex` sekali di `prepare()` awal ride, (2) HR live dari Apple Watch (`HKWorkoutSession` + `HKLiveWorkoutBuilder`) dikirim ke iPhone lewat WatchConnectivity, throttled maks 1× per 5 detik, (3) FVC dihitung sekali per ride via §2.1.2 (gak berubah-ubah sepanjang ride), (4) `V̇E` dihitung ulang tiap `apply()` dipanggil, pakai HR saat itu — fallback ke `ConstantVentilationRate` (0.040) kalau HR ≤ 30 bpm atau profil HealthKit gagal dimuat.

**Bug yang sempat kejadian dan udah diperbaiki:** implementasi awal ngambil `exposure` kumulatif (`Σ(Cᵢ × tᵢ)` sejak awal ride, terus terus bertambah) dan langsung dikaliin `VE` dari HR **saat query dipanggil**. Efeknya, HR sesaat sebelum query ikut nge-*rescale* seluruh riwayat paparan dari awal ride — bukan cuma porsi waktu yang beneran dijalani di HR segitu. Ini persis kesalahan "VE ditarik keluar Σ padahal VE gak konstan" yang dibahas di §1. Diperbaiki jadi akumulasi inkremental: `LiveRideDoseSession` sekarang nyimpen durasi-per-segmen dari update sebelumnya, ngitung `Δtᵢ` tiap panggilan `apply()`, dan nambahin `VE(HR_saat_ini) × Σ(Cᵢ × Δtᵢ)` ke total dosis yang jalan terus (`accumulatedDoseMicrograms`) — bukan nghitung ulang dari nol tiap update. Lihat rumus Δdosis di §1.

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

2. **Risiko double counting dengan `M_road`.** Dua-duanya narik dari kolam literatur yang sama (_roadside increment studies_). `M_road = 1.25` udah bilang "pinggir arteri lebih kotor dari ambient"; `F_moda = 1.5` bilang lagi hal yang mirip. Dipasang dua-duanya → `1.25 × 1.5 = 1.875×` di atas ambient untuk arteri, susah dipertahanin.

**Keputusan:** efek pinggir jalan sepenuhnya dibawa `M_road`. `F_moda` = 1.0, dihilangkan dari rumus.

---

## §3. `C_base` — Output Model ML (Lapis 1)

```
C_base(cell) = expm1( model_gbr_v4_log.predict([
    base_pm25, wind_speed, relative_humidity, hour_of_day, is_weekend
]) )
```

| Var                 | Asal                                      | Catatan                                                                                                                                |
| ------------------- | ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `base_pm25`         | Open-Meteo Air Quality API (CAMS)         | Resolusi nominal **0.4° ≈ 44 km** (CAMS global) — lihat catatan §3.1 soal kenapa nominal ini gak bisa dipakai langsung buat kuantisasi |
| `wind_speed`        | Open-Meteo Forecast API                   | **Wajib m/s** — API default-nya km/jam                                                                                                 |
| `relative_humidity` | Open-Meteo Forecast API                   | %                                                                                                                                      |
| `hour_of_day`       | Jam device                                | **WIB, bukan UTC, bukan `TimeZone.current`**                                                                                           |
| `is_weekend`        | Hari device                               | 0/1, dari WIB                                                                                                                          |
| output              | `CleanRoutePM25.mlmodel` (GBR, skala log) | **Wajib `expm1()`** — lupa ini = dosis salah ~50×                                                                                      |

### 3.1 Granularitas: per grup fetch berbasis jarak, bukan per segmen, bukan per rute

> **Revisi.** Versi sebelumnya dokumen ini nyuruh kuantisasi grid lewat `floor(lat/0.4), floor(lon/0.4)` buat nentuin "segmen mana masuk cell CAMS mana". **Pendekatan itu salah, dan udah dikonfirmasi salah secara empiris** — lihat kotak temuan di bawah. Section ini ditulis ulang total. Kalau nemu kode yang masih pakai `floor(coord / 0.4)` buat dedup fetch, itu implementasi versi lama, harus diganti.

**Temuan yang membatalkan pendekatan lama:**

Rute uji dari `(-6.262199, 106.668267)` ke `(-6.177820, 106.790758)`, 120 segmen. Titik awal dan titik akhir, kalau dihitung pakai `floor(coord/0.4)`, jatuh di cell grid yang **sama persis** (`lat_idx = -16`, `lon_idx = 266` buat dua-duanya). Tapi query langsung ke Open-Meteo di dua koordinat itu ngasih `base_pm25` **52.5 vs 40.2** — beda ~23%, padahal menurut kuantisasi grid harusnya identik.

Ini bukan bug di kode dedup — kodenya udah bener ngikutin rumus `floor()`. Masalahnya di **asumsi di balik rumus itu**: kita anggap Open-Meteo ngasih nilai step-function per grid 0.4° (nilai konstan di dalam satu cell, lompat di batas). Kenyataannya kemungkinan besar salah satu dari ini:

1. Open-Meteo **interpolasi kontinu** antar node CAMS (bilinear atau semacamnya) sebelum ngasih hasil ke caller, bukan nearest-neighbor.
2. Grid CAMS asli **gak align** ke kelipatan bulat 0.4° dari (0,0), jadi batas cell yang kita hitung sendiri gak nyerempet batas cell yang beneran dipakai di belakang API.

Dua-duanya sama akibatnya: **kuantisasi grid gak bisa dipakai buat nebak "titik ini masih di area yang sama secara PM2.5 atau udah beda."**

**Pendekatan baru: clustering berbasis jarak, bukan grid quantization.**

1. Jalan segmen demi segmen sesuai urutan rute.
2. Segmen pertama jadi titik referensi grup-1.
3. Segmen berikutnya: kalau jaraknya (`CLLocation.distance(from:)`, bukan Euclidean derajat) dari titik referensi grup aktif **≤ threshold**, masuk grup itu. Kalau lebih jauh dari threshold, segmen ini jadi titik referensi grup baru.
4. Ulangi sampai semua segmen ke-assign ke satu grup.
5. Fetch air quality + weather **1× per grup**, pakai koordinat titik referensi grup (bukan centroid — titik referensi lebih murah dihitung dan cukup representatif selama threshold cukup kecil).
6. Panggil CoreML **1× per grup** → `C_base` per grup.
7. Tiap segmen ambil `C_base` dari grup tempat dia di-assign.

**Threshold jarak: `20 km`, berlaku sebagai nilai provisional, bukan final.** Ini ~separuh dari resolusi nominal CAMS (44 km), dipilih konservatif karena kita udah tau nominal itu gak bisa dipercaya persis. Belum divalidasi lewat sampling sistematis. **Open item** (lihat §9) — sebelum threshold ini dipatenkan, perlu sampling beberapa titik lagi di sepanjang rute yang sama (misal tiap ~5 km) buat liat pola perubahan `base_pm25`-nya: kalau berubahnya smooth/gradual, threshold kecil (10–15 km) lebih aman; kalau ternyata ada lompatan tajam di titik tertentu lalu konsisten lagi di kedua sisi, itu petunjuk ada batas real di situ dan threshold bisa disesuaikan.

Rute pendek (< threshold total) → 1 fetch. Rute panjang → beberapa fetch, jumlahnya emergent dari clustering, bukan dari hitungan cell grid manapun.

**Cap keras tetap 8 fetch per request** (sekarang dihitung dari jumlah grup hasil clustering, bukan dari jumlah cell unik); kalau lebih, kasih tau user rutenya di luar cakupan yang divalidasi dan jangan lanjut diam-diam.

**Soal "jangan interpolasi antar cell" — klaim ini direvisi.** Versi dokumen sebelumnya bilang batas cell yang bikin `Cᵢ` melompat itu "representasi jujur dari resolusi CAMS, bukan artefak yang perlu dihaluskan." Klaim itu **udah gak valid** buat cara kita ambil data sekarang: temuan di atas nunjukin Open-Meteo kemungkinan besar udah interpolasi sendiri secara internal, jadi model step-function yang diasumsikan sepanjang dokumen ini gak akurat. Yang kita kontrol sekarang bukan "batas cell CAMS yang jujur", tapi **granularitas grup fetch kita sendiri** — makin kecil threshold, makin sering fetch, makin dekat ke "nilai kontinu asli" tapi makin mahal secara request budget (cap 8). Trade-off ini eksplisit, dan threshold 20 km adalah titik keseimbangan sementara, bukan angka yang diturunkan dari sifat CAMS yang sebenarnya.

> Catatan: angka "~11 km" di `v4-summary.md` §2 itu stale — 11 km adalah resolusi CAMS **Europe**. Indonesia dilayani CAMS **global**, nominal 0.4° ≈ 44 km — tapi lihat catatan di atas, angka nominal ini sekarang cuma dipakai sebagai justifikasi kasar buat threshold, bukan buat kuantisasi langsung.

### 3.2 Granularitas waktu di live mode

Ride sepeda gampang lewat batas jam. `hour_of_day` adalah fitur ML terkuat kedua (20% importance) dan pola bias CAMS berubah tajam sore–malam (kelebihan ~20 µg/m³ jam 18–05, cuma ~5 di siang hari).

- Tiap pergantian jam WIB selama ride: re-fetch Open-Meteo untuk grup aktif dan re-prediksi `C_base`.
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

| road_class   | Contoh           | M_road              | Asal                                 |
| ------------ | ---------------- | ------------------- | ------------------------------------ |
| 1 (tol)      | —                | tidak muncul (§4.2) | Legal — sepeda dilarang masuk tol    |
| 2 (arteri)   | Jl. Sudirman     | 1.25                | Studi roadside-increment (literatur) |
| 3 (kolektor) | Jalan raya biasa | 1.15                | idem                                 |
| 4 (lokal)    | Gang, komplek    | 1.00                | idem                                 |

`road_classᵢ` dan `greenery_indexᵢ` didapat dari lookup koordinat segmen ke `roads_data.json` (grid precomputed dari OpenStreetMap, 147.027 cell, resolusi ~166m). **Bukan** dari model ML, **bukan** dari ORS. Lookup ini tetap **per segmen** — inilah satu-satunya bagian yang beneran butuh granularitas per segmen. (Grid 166m ini beda konteks dari grup fetch CAMS di §3.1 — jangan ketuker; grid `roads_data.json` udah precomputed dan align-nya diketahui, gak punya masalah yang sama kayak asumsi grid CAMS.)

**Sifat penting:** ini satu-satunya sumber diferensiasi spasial untuk rute pendek. `base_pm25` (~44 km) dan model ML gak bisa bedain jalan arteri dari gang — yang bikin dua rute punya dosis beda hampir seluruhnya berasal dari lapisan ini. Setelah `F_moda` dihapus, lapisan ini juga satu-satunya yang membawa efek pinggir jalan (§2.2).

(Untuk rute panjang yang nyebrang grup fetch CAMS, `C_base` mulai ikut berkontribusi ke perbedaan. Kecil, tapi bukan nol lagi — jangan bilang "kontribusi ML ke ranking selalu nol".)

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

| Var             | Asal                                                                                 |
| --------------- | ------------------------------------------------------------------------------------ |
| `ETA_total_ORS` | `features[].properties.summary.duration` (detik) — satu angka utuh buat seluruh rute |
| `distanceᵢ`     | Panjang segmen (~200m), hasil potong polyline ORS                                    |

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

> **Revisi.** Ini keputusan produk terbaru, menggantikan dua versi sebelumnya: draf awal dokumen ini ("v1" — exclude ke `unattributedDuration`), dan implementasi interim yang sempat jalan di kode ("v2" — freeze ke `activeSegmentIndex` terakhir via `attributeToActiveSegment`). Dua-duanya udah gak berlaku.

- Jarak tegak lurus ke polyline > 50m selama > 15 detik → status `offRoute`. **Ini murni flag informasional buat UI** (nampilin "lagi di luar rute" ke user) — status ini **tidak mengubah cara `tᵢ` dihitung sama sekali**.
- Map-matching & timer segmen (aturan di atas: proyeksi ke polyline, index segmen dari jarak kumulatif, anti-flapping ≥20m lewat batas) **jalan identik**, off-route atau enggak. Gak ada cabang kode terpisah buat kondisi ini.
- Selama proyeksi posisi masih nunjuk ke segmen aktif yang sama (belum ada transisi valid) → waktu terus keakumulasi ke segmen itu. User off-route tapi belum "masuk" segmen berikutnya = dianggap masih di segmen yang sama, persis kayak kalau dia di jalur.
- Begitu proyeksi lewat ambang transisi ke segmen berikutnya → segmen aktif pindah seperti biasa, walau posisi fisik user masih > 50m dari polyline. Gak ada syarat "harus balik ke jalur dulu" buat transisi kejadian.
- Gak ada bucket `unattributedDuration` lagi — semua waktu, off-route atau enggak, selalu dibebankan ke suatu segmen lewat proyeksi normal. Gak perlu ditampilkan sebagai "X menit gak dihitung" karena memang gak ada waktu yang dibuang.
- **Trade-off yang disadari:** `Cᵢ` yang dipakai buat waktu off-route adalah `Cᵢ` segmen yang lagi aktif menurut proyeksi terakhir, bukan konsentrasi aktual di lokasi fisik user. Makin jauh/makin lama nyimpang dari rute, makin gak representatif nilai itu. Ini trade-off yang sama kayak versi "v2" sebelumnya — cuma sekarang gak ada logic freeze terpisah, jadi konsekuensinya lebih konsisten diprediksi.

**Kontrak:** di live mode `Σ tᵢ` = durasi aktual terukur, dan **tidak dipaksa** sama dengan `ETA_total_ORS`. Beda antara keduanya itu informasi, bukan error. Off-route **tidak** mengurangi `Σ tᵢ` — lihat kontrak #10 di §8.

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
  - koordinat → grup fetch CAMS (jarak, §3.1) → `C_base` (di-share antar segmen dalam grup yang sama)
  - koordinat → grid jalan → `M_road`/`M_green` (§4, per segmen)

  Dua-duanya gak saling tahu satu sama lain.

---

## §7. Ringkasan Kepemilikan

```
OpenRouteService  → ETA_total, geometri polyline, filter tol   (gak tau apa-apa soal PM2.5)
MapKit            → render peta + geocoding                     (bukan routing)
Model ML          → C_base per grup fetch CAMS                  (buta lokasi, cuma paham cuaca+waktu)
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
     VE      : 0.040 m³/min (fallback) — atau HR-based §2.1.1 kalau HR > 30 bpm & profil ada
     F_moda  : TIDAK DIPAKAI (§2.2) — jangan dimasukin balik
     Dosis   : planning → VE × Σ(Cᵢ × tᵢ)                    ← VE konstan, boleh di luar Σ
               live     → Σ(VEᵢ × Cᵢ × tᵢ)                    ← VE WAJIB di dalam Σ, lihat §1
7. Σtᵢ = ETA_total_ORS            ← HANYA di planning mode
   Σtᵢ = durasi terukur           ← di live mode, sengaja beda dari ETA
8. Fetch CAMS pakai clustering jarak (§3.1)  ← BUKAN floor(lat/0.4), floor(lon/0.4)
9. Live mode: dosis diakumulasi INKREMENTAL per update (Δdosis += VE_sekarang × Σ(Cᵢ×Δtᵢ))
   ← BUKAN VE_sekarang × exposure_seluruh_riwayat dihitung ulang tiap update (§1, §2.1.1)
10. Off-route BUKAN kondisi khusus buat map-matching/timer (§5.2)
    ← jangan exclude ke unattributedDuration, jangan freeze ke "segmen aktif terakhir" — proyeksi & transisi jalan sama kayak on-route
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
- **Threshold clustering CAMS (20 km) masih provisional** (§3.1) — belum divalidasi lewat sampling sistematis sepanjang rute. Belum tau apakah perubahan `base_pm25` di lapangan itu gradual (threshold kecil lebih tepat) atau ada lompatan tajam di titik tertentu (threshold perlu disesuaikan ke situ). Jangan klaim threshold ini akurat sebelum divalidasi.
- **Dosis selama off-route (§5.2) pakai `Cᵢ` segmen aktif menurut proyeksi, bukan konsentrasi aktual di lokasi user.** Makin jauh/lama nyimpang dari rute, makin gak representatif. Ini trade-off yang disadari, bukan bug — alternatifnya (exclude waktu, atau freeze ke segmen lama) dianggap lebih buruk karena user tetap bernapas selama off-route.
- Boleh klaim: _"rute dengan komposisi jalan dan waktu tempuh yang paparannya lebih rendah"_. **Tidak boleh** klaim: _"kami menemukan area yang udaranya lebih bersih"_.

---

## §10. Perubahan dari Versi Sebelumnya

| #   | Versi lama                                                                  | Sekarang                                                     | Alasan                                                                                                                                                                                                                                                                                                                                                            |
| --- | --------------------------------------------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Target pengendara motor                                                     | **Pesepeda**                                                 | Pivot produk                                                                                                                                                                                                                                                                                                                                                      |
| 2   | `VE = 0.014 m³/min`                                                         | **`0.040 m³/min`**                                           | 0.014 = duduk di kendaraan. Sepeda = aktivitas moderat–berat. Ideal: dari heart rate                                                                                                                                                                                                                                                                              |
| 3   | `F_moda = 1.5`                                                              | **Dihapus (= 1.0)**                                          | Literatur: paparan PM2.5 pesepeda ~1,06× background (terendah dari 6 moda). Plus risiko double counting dengan `M_road`                                                                                                                                                                                                                                           |
| 4   | `Dosis = VE × Σ(Cᵢ×tᵢ)` di §1, tapi `0.014 × 1.5 × ...` di §8               | **`VE × Σ(Cᵢ×tᵢ)`** konsisten di dua tempat                  | Dokumen lama inkonsisten sama dirinya sendiri. Resolve ke bentuk §1                                                                                                                                                                                                                                                                                               |
| 5   | 2 lookup independen per segmen (cuaca + jalan)                              | Cuaca/CAMS **per grup fetch**; jalan tetap **per segmen**    | Fetch per segmen redundan total di area yang homogen, tapi "1× per rute" salah buat rute jauh                                                                                                                                                                                                                                                                     |
| 6   | `tᵢ` selalu pecahan proporsional ETA                                        | Planning proporsional; **live diukur GPS real-time**         | Timer per segmen ngilangin proxy `congestion_ratio` sepenuhnya di live mode                                                                                                                                                                                                                                                                                       |
| 7   | `Σtᵢ = ETA` mutlak                                                          | Berlaku **cuma di planning mode**                            | Live mode `Σtᵢ` = durasi aktual                                                                                                                                                                                                                                                                                                                                   |
| 8   | Routing pakai `MKDirections`                                                | **OpenRouteService** (`cycling-regular`)                     | MapKit cuma buat render peta + geocoding                                                                                                                                                                                                                                                                                                                          |
| 9   | Filter tol pakai `tollPreference = .avoid`                                  | Ditangani profil cycling ORS                                 | Profil sepeda gak pernah ngasih rute motorway                                                                                                                                                                                                                                                                                                                     |
| 10  | `congestion_ratio` = fungsi `hour × road_class × is_weekend`                | **1.0 seragam**                                              | Monte Carlo: 0/30 ranking flip. Tabel 144-cell sengaja tidak dibangun                                                                                                                                                                                                                                                                                             |
| 11  | Resolusi CAMS ditulis 11 km di `v4-summary.md`                              | **0.4° ≈ 44 km (nominal)**                                   | 11 km = CAMS Europe. Indonesia pakai CAMS global                                                                                                                                                                                                                                                                                                                  |
| 12  | Dedup fetch CAMS pakai `floor(lat/0.4), floor(lon/0.4)` (grid quantization) | **Clustering berbasis jarak, threshold 20 km (provisional)** | Empiris: dua titik yang menurut floor-division satu cell yang sama ngasih `base_pm25` beda jauh (52,5 vs 40,2, rute uji `-6.262199,106.668267` → `-6.177820,106.790758`, 120 segmen). Grid quantization gak valid buat granularitas Open-Meteo yang sebenarnya — kemungkinan API-nya interpolasi internal, atau grid asli gak align ke kelipatan 0.4°. Lihat §3.1 |
| 13  | Live mode: `dosis = VE(HR_sekarang) × exposure_kumulatif_seluruh_riwayat`, dihitung ulang dari nol tiap update lokasi | **Akumulasi inkremental**: `dosis_total += VE(HR_sekarang) × Σ(Cᵢ × Δtᵢ)`, `Δtᵢ` = durasi baru sejak update terakhir | `VE` berbasis HR (§2.1.1) berubah-ubah sepanjang ride begitu diimplementasi. Versi lama nge-*retroactively rescale* seluruh riwayat paparan pakai HR sesaat pas query — porsi waktu dari 2 jam lalu ikut kena HR barusan. Ini contoh nyata kenapa `VE` harus di dalam Σ kalau gak konstan (§1) |
| 14  | Off-route: waktu di-exclude ke `unattributedDuration` (v1), lalu direvisi jadi freeze ke `activeSegmentIndex` terakhir via `attributeToActiveSegment` (v2, cuma sempat ada di kode/CLAUDE.md) | **Off-route bukan kondisi khusus sama sekali** — map-matching & timer segmen jalan identik on-route/off-route, waktu ngikut proyeksi posisi biasa (§5.2) | User tetap bernapas selama off-route, jadi waktunya harus tetap kehitung (menyingkirkan v1). Tapi freeze ke segmen lama (v2) bikin logic bercabang dan gak perlu — proyeksi normal ke polyline udah otomatis ngasih index segmen yang masuk akal walau posisi jauh dari rute, jadi cabang khusus cuma nambah kompleksitas tanpa manfaat |

Efek gabungan item 2 + 3 ke angka dosis absolut: `0.014 × 1.5 = 0.021` → `0.040`, naik **~1,9×**. Ranking gak berubah sama sekali.

---

## Lampiran — Contoh Perhitungan (ilustrasi, angka fiktif)

Rute pendek ~4 km, seluruhnya dalam 1 grup fetch CAMS → `C_base = 37,9 µg/m³` konstan. `M_green = 1,00` (greenery 0) buat menyederhanakan.

### Planning mode

| Rute                 | Segmen    | road_class | M_road | Cᵢ   | tᵢ (menit) | Cᵢ × tᵢ |
| -------------------- | --------- | ---------- | ------ | ---- | ---------- | ------- |
| **A — lewat arteri** | 1         | arteri     | 1,25   | 47,4 | 10         | 474     |
|                      | 2         | kolektor   | 1,15   | 43,6 | 6          | 262     |
|                      | **Total** |            |        |      | **16**     | **736** |
| **B — lewat gang**   | 1         | lokal      | 1,00   | 37,9 | 9          | 341     |
|                      | 2         | kolektor   | 1,15   | 43,6 | 8          | 349     |
|                      | **Total** |            |        |      | **17**     | **690** |

`C_base` identik di semua baris (satu grup fetch, model gak bedain lokasi). Beda paparan A (736) vs B (690) murni dari `M_road` per segmen — bukti bahwa diferensiasi spasial di rute pendek 100% berasal dari `roads_data.json`.

Dosis absolut:

```
A : 0,040 × 736 = 29,4 µg
B : 0,040 × 690 = 27,6 µg
```

Beda paparan `(736 − 690) / 690 = 6,7%` → di bawah gate 20% → app tampilkan **"paparan setara"**, tiebreak ke rute **A** (lebih cepat, 16 menit).

> Bandingkan versi motor (`0,014 × 1,5 = 0,021`): rute A jadi 15,5 µg. Kenaikan ~1,9× itu murni dari ventilasi pesepeda dikurangi penghapusan `F_moda`, bukan perubahan model.

### Live mode (user pilih rute A, ternyata lebih lambat)

| Segmen    | Cᵢ   | tᵢ terukur | Cᵢ × tᵢ |
| --------- | ---- | ---------- | ------- |
| 1         | 47,4 | 12         | 569     |
| 2         | 43,6 | 7          | 305     |
| **Total** |      | **19**     | **874** |

```
Dosis aktual = 0,040 × 874 = 35,0 µg
```

Perkiraan 29,4 µg → aktual 35,0 µg. Selisihnya dari waktu tempuh nyata yang 3 menit lebih lama dari ETA ORS. **Ini yang dilaporkan ke user sebagai dosis aktual**, dan bedanya dari perkiraan boleh ditampilkan apa adanya — itu informasi, bukan error.
