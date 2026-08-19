# GoWays 🚴‍♂️💨

**Google Maps gives you the fastest route. GoWays gives you the one that hurts you the least.**

GoWays is an iOS navigation app built for cyclists in Jabodetabek (Greater Jakarta) that ranks routes by **estimated PM2.5 exposure dose** — not travel time — then measures your actual dose while you ride.

![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20watchOS-lightgrey)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)
![CoreML](https://img.shields.io/badge/ML-CoreML-blue)
![HealthKit](https://img.shields.io/badge/HealthKit-HR%20based%20VE-red)
![Status](https://img.shields.io/badge/status-in%20development-yellow)

---

## 🎬 Demo

<video  src="./readme.docs/screenrec-demo-c5.MP4" controls muted></video>

---

### Share your ride

Post-ride summary, shareable Strava-style.

<p align="center">
<img src="./readme.docs/IMG_3301.PNG" width="45%" alt="Shareable trip sum
mary card" />
  <img src="./readme.docs/IMG_3293.JPG" width="45%" alt="Trip summary scree
n" />
</p>

---

## 🧠 Why GoWays?

Jakarta has some of the worst air quality of any major city, and cyclists take the brunt of it — breathing harder, more often, right next to the source of the pollution. Every navigation app out there optimizes for **time**. None of them ask how much of that air actually ends up in your lungs.

GoWays flips that:

- 🗺️ **Planning Mode** — before you set off, GoWays compares up to 3 alternative routes and ranks them by estimated exposure dose, not distance or travel time.
- 🚴 **Live Ride Mode** — once you start riding, GoWays measures your actual dose in real time: segment-by-segment duration from GPS, minute ventilation derived from your heart rate (Apple Watch), and PM2.5 concentration refreshed every hour.

The division of labor is deliberate: a CoreML model produces the absolute dose number per location cluster, while a deterministic formula layer handles the ranking — combining road type, greenery, and actual travel time.

---

## ✨ Features

- **Exposure-dose-based route ranking**, not just distance/time — powered by OpenRouteService (cycling profile) + CoreML PM2.5 prediction + Jabodetabek road type & greenery data.
- **Live dose tracking** during the ride — GPS map-matching per ~200m segment, anti-flapping at segment boundaries, incremental dose accumulation.
- **Heart-rate-based ventilation rate** — with an Apple Watch paired, dose is computed from your actual breathing rate (Greenwald et al. 2019), not a constant.
- **Exposure heatmap** along the route, using ISPU / Indonesian Ministry of Environment (Permen LHK 14/2020) thresholds.
- **Post-ride summary** — actual dose, per-segment breakdown, ride history.
- Honest about uncertainty: route pairs with similar exposure are flagged as "equivalent" instead of being forced apart to look smarter.

---

## 🏗️ Tech Stack

<table>
<tr>
<th align="left">📱 iOS</th>
<th align="left">🧠 ML</th>
<th align="left">⚙️ Backend</th>
<th align="left">🌐 API External</th>
</tr>
<tr>
<td valign="top">

![Swift](https://img.shields.io/badge/Swift-F54A2A?style=flat-square&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0066CC?style=flat-square&logo=swift&logoColor=white)
![MapKit](https://img.shields.io/badge/MapKit-000000?style=flat-square&logo=apple&logoColor=white)
![CoreLocation](https://img.shields.io/badge/CoreLocation-000000?style=flat-square&logo=apple&logoColor=white)
![HealthKit](https://img.shields.io/badge/HealthKit-FF2D55?style=flat-square&logo=apple&logoColor=white)
![WatchConnectivity](https://img.shields.io/badge/WatchConnectivity-000000?style=flat-square&logo=apple&logoColor=white)

</td>
<td valign="top">

![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)
![scikit-learn](https://img.shields.io/badge/scikit--learn-F7931E?style=flat-square&logo=scikitlearn&logoColor=white)
![GradientBoostingRegressor](https://img.shields.io/badge/Gradient%20Boosting%20Regressor-F7931E?style=flat-square)

</td>
<td valign="top">

![Go](https://img.shields.io/badge/Go-00ADD8?style=flat-square&logo=go&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)

</td>
<td valign="top">

![OpenRouteService](https://img.shields.io/badge/OpenRouteService-8A2BE2?style=flat-square)
![Open-Meteo](https://img.shields.io/badge/Open--Meteo-2C3E50?style=flat-square)
![OpenAQ](https://img.shields.io/badge/OpenAQ-00A9A5?style=flat-square)
![OpenStreetMap](https://img.shields.io/badge/OpenStreetMap-7EBC6F?style=flat-square&logo=openstreetmap&logoColor=white)

</td>
</tr>
</table>

Project structure:

```
GoWays/
├── Extensions/     Color+, Font+, and other Apple-type extensions
├── Components/     Small reusable views
├── Models/         Pure data structs/enums
├── Services/       Networking, CoreML, GPS, dose calculations
├── ViewModels/     State + orchestration
└── Views/          Screen-level SwiftUI views
```

Full data flow, critical contracts, and dose formulas live in [`CLAUDE.md`](./CLAUDE.md) and [`RUMUS.md`](./RUMUS.md).

---

## ⚠️ Known limitations

- CAMS (the underlying PM2.5 data source) has coarse resolution — on short routes, the ML model's contribution to ranking can approach zero, with the formula layer (road type, greenery) doing the heavy lifting.
- The model and road data only cover **Jabodetabek**. Anything outside that is extrapolation.
- Planning mode numbers are **estimates**, not measurements — that's why the UI shows ranges/categories rather than precise figures.

Full details in `CLAUDE.md` §6.

---

## 👥 Team

Built by:

- **Revan Ferdinand**
- **Jonathan Basuki**
- **Marvellino Christian Sanjoto**
- **Devi Jayanti Sujata**
- **Ananta Ghaisani**

---

<p align="center">Your breath is worth something. Your route should know that. 🌬️</p>
