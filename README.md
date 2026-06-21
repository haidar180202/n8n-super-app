# n8n-super-app (Supreme Mother Orchestrator)

Repo ini berisi:

- Workflow n8n: [Supreme Mother Orchestrator V1.0 (1).json](./Supreme%20Mother%20Orchestrator%20V1.0%20(1).json)
- Runtime lokal n8n + Postgres: [docker-compose.yml](./docker-compose.yml)

Workflow ini mengorkestrasi pipeline produksi video YouTube berbasis scene:

1. Generate spesifikasi video (topik, script, scene, metadata YouTube) lewat Groq (OpenAI-compatible endpoint).
2. Jika ada “evolution plan”, kirim notifikasi ke Telegram.
3. Jika tidak, pecah scene satu-per-satu, generate image URL (Pollinations), kirim image-to-video request ke Luma Dream Machine, polling status, ambil download URL untuk tiap scene.
4. Kumpulkan seluruh URL clip untuk diproses lanjut (merge/render) dan opsional upload YouTube.

## Menjalankan n8n lokal

Jalankan stack:

```bash
docker compose up -d
```

Akses UI:

- http://localhost:5678

Data n8n tersimpan di volume `n8n_data`, database di `postgres_data`.

## Import workflow

Di UI n8n:

1. Workflows → Import from file
2. Pilih file: `Supreme Mother Orchestrator V1.0 (1).json`
3. Simpan workflow

Workflow yang benar akan bernama:

- `Supreme Mother Orchestrator V1.0 (Fixed)`

## Konsep data (output AI)

Node “Supreme Mother Orchestrator” mengharapkan response JSON berbentuk:

- `project`: UUID string
- `log`: string
- `meta`: object (title, hook, pacing)
- `video_data`: object
  - `script`: string
  - `voice`: string (mis. `id-ID-ArdiNeural`)
  - `scenes`: array scene
    - `id`: number
    - `prompt`: string (prompt visual)
    - `motion`: string (instruksi gerak)
    - `text`: string (overlay/caption)
    - `sec`: number (durasi)
    - `audio_segment`: string (instruksi audio)
- `yt_deployment`: object (title, description, tags, thumb_prompt)
- `evolution`: string atau `null`

Setelah response didapat, node “Extract Data” mengekstrak field penting ke:

- `hasEvolution`: boolean (true jika `evolution` terisi)
- `evolutionPlan`: string (isi evolution atau “No updates proposed”)
- `projectId`, `ytTitle`, `ytDescription`, `ytTags`
- `scenes`: array scene (dipakai untuk loop)

## Cara kerja workflow (node-by-node)

### 1) Trigger & AI Orchestration

1. **Start Video Generation** (Manual Trigger)
   - Menjalankan workflow secara manual dari UI.
2. **Init Clip Cache** (Code)
   - Menginisialisasi cache clip per-execution (dipakai untuk mengumpulkan `clipUrl` per scene).
3. **Supreme Mother Orchestrator** (HTTP Request → Groq)
   - POST ke `https://api.groq.com/openai/v1/chat/completions`.
   - Menghasilkan dokumen JSON “spesifikasi produksi”.
4. **Extract Data** (Set)
   - Parsing JSON response dan menaruh field-field penting ke item output.

### 2) Branch governance: Evolution Proposed?

5. **Evolution Proposed?** (IF)
   - Jika `hasEvolution == true`:
     - Masuk jalur notifikasi Telegram.
   - Jika `hasEvolution == false`:
     - Masuk jalur produksi video per scene.

### 3A) Jalur notifikasi (jika ada evolution)

6. **Format Telegram Message** (Set)
   - Menyusun teks laporan “SYSTEM EVOLUTION REPORT”.
7. **Send to Telegram** (Telegram)
   - Mengirim pesan ke chat ID yang kamu isi.

Output jalur ini adalah notifikasi. Produksi video tidak berjalan (sesuai konsep governance).

### 3B) Jalur produksi video (tanpa evolution)

8. **Split Scenes** (Split Out)
   - Mengubah `scenes` array menjadi item-item terpisah (1 item = 1 scene).
9. **Loop Over Scenes** (Split in Batches)
   - Menjalankan proses per scene dan kembali lagi sampai scene habis.
   - Dua output penting:
     - Output “main” untuk memproses item scene.
     - Output “done” (cabang kedua) dipakai ketika loop selesai untuk lanjut ke pengumpulan hasil.

#### Pipeline per scene (di dalam loop)

10. **Generate Image (Pollinations.ai)** (Set)
   - Tidak mengunduh file image.
   - Hanya membuat `imageUrl` (URL ke image yang bisa diakses publik).
11. **Generate Motion (Luma AI)** (HTTP Request)
   - Mengirim request image-to-video ke Luma Dream Machine:
     - `prompt`: diambil dari `scene.motion`
     - `keyframes.frame0.url`: memakai `imageUrl`
   - Output berisi `id` generation.
12. **Wait for Video Generation** (Wait)
   - Delay sebelum cek status (menghindari polling terlalu agresif).
13. **Check Video Status** (HTTP Request)
   - GET status generation Luma berdasarkan `id`.
14. **Download Video Clip** (Set)
   - Mengambil `clipUrl` dari response status (contoh: `$json.video.download_url`).
15. **Store Clip** (Code)
   - Menyimpan `clipUrl` ke cache per-execution.
16. Kembali ke **Loop Over Scenes** untuk scene berikutnya.

#### Setelah loop selesai (output “done”)

17. **Collect All Clips** (Code)
   - Mengambil seluruh `clipUrl` yang terkumpul selama loop.
   - Output:
     - `allClips`: array URL video per scene
     - `projectId`, `ytTitle`, `ytDescription`, `ytTags` (dibawa untuk tahap berikutnya)
18. **Merge Video Clips** (Code)
   - Saat ini hanya membuat “status output” dan jumlah clip.
   - Catatan: penggabungan video + audio belum benar-benar dilakukan di workflow ini.
19. **Prepare YouTube Upload** (Set)
   - Menyiapkan field metadata untuk node YouTube.
20. **Upload to YouTube** (YouTube)
   - Upload membutuhkan file video final sebagai binary.
   - Karena workflow ini belum menghasilkan file video final, node ini adalah placeholder sampai ada step render/merge beneran.

## Credential yang wajib kamu set di n8n

- **Groq**: credential Bearer token untuk node “Supreme Mother Orchestrator”.
- **Luma**: credential Bearer token untuk node “Generate Motion (Luma AI)” dan “Check Video Status”.
- **Telegram**: bot token + `chatId` pada node “Send to Telegram”.
- **YouTube**: OAuth2 credential untuk node “Upload to YouTube”.

## Kenapa sebelumnya muncul error “node unexecuted”

Error:

- “There is no connection back to the node 'Download Video Clip', but it's used in an expression here.”

Terjadi jika ada expression yang memanggil output node lain yang belum dieksekusi dalam jalur yang sama (contoh: `$("Download Video Clip").all()`), atau node dieksekusi parsial (Execute Node) sehingga node yang direferensikan belum jalan.

Workflow versi `Fixed` menghindari expression lintas-cabang seperti itu dan mengumpulkan hasil lewat jalur eksekusi yang valid.

## Catatan penting & batasan saat ini

- Workflow ini menghasilkan:
  - Spesifikasi produksi (script + scenes)
  - URL clip per scene (`allClips`)
- Workflow ini belum menghasilkan:
  - 1 file video final (render+merge)
  - Audio Edge-TTS yang disatukan ke video
- Untuk benar-benar upload YouTube, kamu butuh tahap render/merge (FFmpeg/VPS/worker) yang mengembalikan binary video final ke n8n.
