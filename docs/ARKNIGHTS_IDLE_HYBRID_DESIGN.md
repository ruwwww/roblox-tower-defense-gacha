# Blueprint Arsitektur: Arknights Tower Defense × Idle RPG (Idle Heroes)

**Branch:** `feature/idle-arknights-td`  
**Status:** Brainstorming & Architecture Blueprint (Disusun bersama agen Codex)

---

## 1. Solusi Algoritma Auto-Formation Heuristic

Tantangan utama Anda: **"Bagaimana cara sistem menempatkan formasi 6 hero secara otomatis pada map tile 2D yang berbeda-beda tanpa sentuhan manusia?"**

Sistem menggunakan **Multi-Stage Greedy Heuristic dengan Topological Scoring**:

```
[Analisis Grid Map] ──> [1. Pasang Blocker (Land)] ──> [2. Pasang DPS (Tower)] ──> [3. Pasang Medic (Tower)]
```

### Tahap 1: Map Topology Analysis (Pre-computation)
Map 2D memiliki 3 jenis tile:
- `Path`: Jalur jalan musuh (Start -> Crystal Goal).
- `Ground (Land)`: Tile dataran rendah di samping atau di atas jalur (hanya untuk Tank/Fighter).
- `High-Ground (Tower)`: Tile tebing/dataran tinggi (hanya untuk Sniper/Caster/Medic).

Sistem menghitung nilai heuristik untuk setiap tile:
1. **Choke Point Score ($S_{choke}$)**: Seberapa dekat tile ke Base Crystal, tapi tetap memiliki jarak aman ($D_{base} \in [15\%, 40\%]$ dari total panjang rute). Menahan musuh terlalu dekat ke spawn berisiko bocor saat swarm; menahan terlalu dekat ke crystal berisiko kalah instan.
2. **Lane Convergence ($C_{lane}$)**: Titik pertemuan bila map memiliki lebih dari 1 rute spawn.

### Tahap 2: Penempatan Blocker (Role: Tank & Fighter)
1. Filter hero berjenis `Land` di formasi (prioritas: Tank dengan Block Count tertinggi, misal Block 3, lalu Fighter Block 2).
2. Pilih tile `Ground` dengan nilai:
   $$\text{Score}_{ground} = S_{choke} \times 1.5 + C_{lane} \times 2.0 - \text{OverlapPenalty}$$
3. Tile ini menjadi **"Killzone Anchor"**. Musuh akan terhenti di sini saat dihadang blocker.

### Tahap 3: Penempatan DPS Ranged (Role: Sniper & Caster)
1. Filter hero berjenis `Tower` (Sniper / Caster).
2. Untuk setiap tile `High-Ground` yang kosong, hitung jangkauan serang (Range):
   $$\text{Score}_{dps} = (\text{Tiles Jalur yang Dijangkau}) + (\text{Bobot Killzone Anchor} \times 3.0)$$
3. Prioritaskan tile tebing yang bisa menembak langsung ke area di mana Tank sedang menahan musuh (fokus burst).

### Tahap 4: Penempatan Medic / Support
1. Hero Medic tidak menyerang musuh, melainkan menyembuhkan kawan.
2. Pilih tile `High-Ground` yang jangkauan heal-nya mencakup sebanyak mungkin blocker `Ground` yang sudah dipasang di Tahap 2:
   $$\text{Score}_{medic} = \sum_{b \in \text{Blockers}} \mathbb{I}(\text{dist}(medic, b) \le \text{Range}_{medic}) \times \text{Threat}_{b}$$

Hasilnya: **Formasi seimbang, protektif, dan optimal di map mana pun secara otomatis!**

---

## 2. Deterministic Headless Simulation Engine (Ground Truth & Instant Skip)

Prinsip utama: **"Simulasi adalah kebenaran mutlak (Ground Truth), tampilan visual hanyalah proyektor."**

```
             ┌──────────────────────────────────────────────┐
             │ Server Headless Simulation (Tick-based, 10Hz)│
             └──────────────────────┬───────────────────────┘
                                    │
               ┌────────────────────┴────────────────────┐
               ▼                                         ▼
      [Klik "Skip Battle"]                     [Tonton Pertempuran]
               │                                         │
     • 0 ms processing                          • Client me-replay timeline
     • Langsung tampilkan                       • Speed 1x, 2x, 4x
       Loot & Bintang (1-3★)                    • Animasi Mana & Ultimate
```

1. **Fixed-Tick Discrete Math**:
   - Simulasi berjalan pada fixed timestep (10 tick per detik).
   - Menggunakan integer math atau fixed precision (tanpa floating point physics engine) sehingga 100% deterministik.
2. **Instant Skip Execution**:
   - Ketika player klik "Start Battle" dengan opsi "Skip", server mengeksekusi 600 tick (1 menit durasi tempur) dalam waktu **kurang dari 20 milidetik**.
   - Server langsung mengembalikan status `Victory/Defeat`, sisa HP crystal, bintang 1–3★, dan drop loot.
3. **Replay Controller**:
   - Jika pemain memilih menonton, server mengirim payload ringkas `BattleSnapshot` (seed, formasi, spawn timeline).
   - Client menjalankan visual loop yang memancarkan proyektil, animasi skill saat Energy/Mana bar penuh, dan floating damage text yang identik 1:1 dengan hasil server.

---

## 3. Desain Lobby Kota Interaktif (Gaya Idle Heroes)

Lobby adalah hub sosial multiplayer, sedangkan pertempuran bersifat **private solo instanced**.

### Struktur Fasilitas di Kota (Lobby Stands):
1. **Summon Altar (Kuil Gacha)**:
   - Stand dengan lingkaran pilar sihir.
   - Menggunakan `Scroll` (Summon Ticket) atau `Diamond`.
   - Banner Standar & Banner Rate-Up Pity.
2. **Campaign Gate (Gerbang Ekspedisi)**:
   - Pintu gerbang utama menuju peta stage PvE (Bab 1: Grassland, Bab 2: Dark Forest, dst.).
   - Dilengkapi **Peti AFK Auto-Loot** yang terus terisi per menit!
3. **Hero Altar / Backpack**:
   - Tempat melihat seluruh koleksi hero.
   - Upgrade hero menggunakan **Elixir + Gold**.
   - Equip 4 slot gear (Weapon, Armor, Accessory, Boots).
4. **Blacksmith (Pandai Besi)**:
   - Tempat menggabungkan/menempa gear tier rendah menjadi tier tinggi (misal: 3 Gear Hijau -> 1 Gear Biru).
5. **Arena Gate (PVP - Rencana)**:
   - Menghadapi formasi hero pemain lain (pertahanan AI vs penyerang AI).
6. **Event Board / Daily Quests**:
   - 7-Day Newbie Carnival, Beginner Mission, VIP perks.

---

## 4. Sistem Hero, Role, Mana & Equipment

### Role Pembagian Arknights × Idle Heroes
| Role | Posisi Penempatan | Fungsi Pertempuran | Tipe Stat Utama |
| :--- | :--- | :--- | :--- |
| **Defender** | **Ground (Land)** | Menahan hingga 3 musuh, armor tebal, HP tinggi | DEF, HP, Block Count (3) |
| **Guard** | **Ground (Land)** | Menahan 1-2 musuh, physical damage tinggi | ATK, HP, Block Count (1-2) |
| **Sniper** | **High-Ground (Tower)** | Serangan jarak jauh fisik cepat ke musuh terbang/runner | ATK, Attack Speed, Crit |
| **Caster** | **High-Ground (Tower)** | Serangan sihir area (AoE) menembus musuh ber-armor | Magic ATK, AoE Radius |
| **Medic** | **High-Ground (Tower)** | Menyembuhkan hero Ground yang sedang menahan musuh | Healing Power, Range |
| **Support** | **High-Ground (Tower)** | Slow aura, buff ATK tim, regenerasi Energy/Mana tim | Utility, Buff % |

### Mekanik Mana & Active Skill
- Setiap hero memiliki bar **Energy (0 / 100)**.
- Setiap serangan atau saat menahan damage menghasilkan +10 s.d. +15 Energy.
- Saat bar mencapai 100, hero secara otomatis (atau manual jika mode auto mati) mengaktifkan **Ultimate Skill** dengan efek visual megah (misal: Meteor Storm, Fortress Shield, Divine Heal).

### Equipment (4 Slot)
- **Weapon**: Menambah Flat ATK & Crit Rate.
- **Armor**: Menambah HP & Physical DEF.
- **Accessory**: Menambah Magic Resist & Energy Recharge Speed.
- **Boots**: Menambah Attack Speed & Dodge.
- Rarity: Common (Abu-abu) -> Rare (Hijau) -> Elite (Biru) -> Epic (Ungu) -> Legendary (Emas).
- Didapat dari: **AFK Auto-Loot Chest**, drop Boss Campaign, dan Toko Blacksmith.

---

## 5. Ekonomi & AFK Auto-Loot

### 4 Mata Uang Utama:
1. **Gold**: Mata uang umum untuk upgrade gear dan biaya level up hero.
2. **Elixir**: Esensi hero khusus untuk menaikkan level hero di Backpack.
3. **Diamond**: Mata uang premium (untuk summon, refresh shop, klaim AFK instan).
4. **Heroic Scroll**: Tiket gacha ganjil/sepuluh hero.

### Formula AFK Auto-Loot:
Pendapatan loot dihitung dari stage campaign tertinggi yang berhasil diselesaikan:
$$\text{Gold/Menit} = 50 + (\text{Stage} \times 12)$$
$$\text{Elixir/Menit} = 30 + (\text{Stage} \times 8)$$
$$\text{Account EXP/Menit} = 20 + (\text{Stage} \times 5)$$
Setiap interval 10 menit, ada probabilitas roll drop equipment sesuai tier stage. Maksimal akumulasi waktu offline: **12 jam** (dapat diperluas ke 24 jam via VIP/Robux).

---

## 6. Struktur Stage PvE & Monetisasi

- **Format Bab**: Tiap chapter terdiri dari 10 Stage (misal 1-1 s.d. 1-10).
- **Pacing**:
  - Stage 1–4: Musuh normal (pembiasaan formasi).
  - Stage 5: Mini-Boss pertama (tes DPS & Blocker).
  - Stage 6–9: Musuh berfitur khusus (armor tebal, musuh terbang yang kebal blocker land).
  - Stage 10: Chapter Boss (memiliki skill serangan area ke hero tower).
- **Monetisasi Robux Ramah Pemain**:
  - **Fast AFK Claim (Quick Rewards)**: Dapatkan 120 menit hasil AFK seketika (1x gratis harian, berikutnya via Diamond/Robux).
  - **Beginner Starter Pack**: 10x Heroic Scroll + Hero 5★ SSR Defender + 100.000 Elixir.
  - **VIP Privilege Tier**: Menambah slot backpack, limit waktu AFK loot, dan diskon stamina.
