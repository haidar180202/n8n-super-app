# n8n-super-app (Supreme Mother Orchestrator)

This repository contains the configuration and environment for **Supreme Mother Orchestrator**, an automated scene-based video production pipeline powered by n8n, Groq, Luma AI, and FFmpeg.

## Repository Contents

- **n8n Workflow (Encrypted):** [supreme.json.enc](./supreme.json.enc) (Secured configuration)
- **Local n8n Runtime + Postgres:** [docker-compose.yml](./docker-compose.yml)
- **Deployment Build:** [Dockerfile](./Dockerfile)
- **Encryption Scripts:** [encrypt.sh](./encrypt.sh) and [decrypt.sh](./decrypt.sh)

---

## 🎬 How the Pipeline Works

1. **AI Video Specification:** The workflow triggers manually or via schedule and requests video specs (topic, script, pacing, scene list, visual prompts, overlays, duration) from Groq (`llama-3.3-70b-versatile`).
2. **Governance Check:** If an "evolution plan" is proposed by the AI, the production stops and sends a detailed proposal to Telegram for approval.
3. **Asset Generation Loop:**
   - **Image Prompting:** Generates high-quality scene images using Pollinations.ai (Flux model).
   - **Video Generation:** Submits image-to-video rendering requests to the Luma Dream Machine API.
   - **Status Polling:** Periodically checks Luma rendering status (every 30s) until the video status is `completed`.
   - **Download:** Extracts and stores each completed scene video clip.
4. **Aggregation & Merging:** Gathers all clips and runs local **FFmpeg** inside the n8n container to concatenate clips into the final video file.
5. **YouTube Upload:** Uploads the finished video directly to YouTube as private/unlisted with AI-generated titles, tags, and SEO descriptions.

---

## 🔐 Secure Workflow & Licensing (Encryption)

For intellectual property protection, the actual n8n workflow file is distributed in an encrypted format: `supreme.json.enc`. This prevents unauthorized cloning or copying of the orchestration logic.

### How to Decrypt the Workflow
If you have the authorized access password, you can decrypt the file to retrieve the raw JSON workflow:

Using the helper script:
```bash
bash decrypt.sh <access_password>
```

Or manually using OpenSSL:
```bash
openssl enc -d -aes-256-cbc -in supreme.json.enc -out supreme.json -k <access_password> -pbkdf2
```
*Note: This will generate the clean `supreme.json` file which can then be imported into n8n.*

### How to Encrypt the Workflow (for Developers)
If you make changes inside n8n, export the workflow as JSON to `supreme.json` and encrypt it before committing to Git:

Using the helper script:
```bash
bash encrypt.sh <access_password>
```

Or manually using OpenSSL:
```bash
openssl enc -aes-256-cbc -salt -in supreme.json -out supreme.json.enc -k <access_password> -pbkdf2
```

---

## 🚀 Getting Started

### 1. Run n8n Locally
Start the local Docker Compose stack:
```bash
docker compose up -d
```
Access the n8n UI at:
- **URL:** [http://localhost:5678](http://localhost:5678)

### 2. Decrypt & Import the Workflow
1. Decrypt the `supreme.json.enc` file using your access key.
2. In the n8n UI:
   - Go to **Workflows** -> **Import from file...**
   - Choose the decrypted [supreme.json](./supreme.json) file.
   - Save the workflow.

### 3. Setup Credentials in n8n UI
Ensure you set up the following credentials in n8n for the nodes to authenticate successfully:
- **Groq API Key:** Link to credential name **`Bearer Auth account`**.
- **Luma AI API Key:** Link to credential name **`Bearer Auth account 2`**.
- **Telegram Bot Token:** Configure in the **`Send to Telegram`** node.
- **YouTube OAuth2:** Configure in the **`Upload to YouTube`** node.

---

## 🛠️ Stack Configuration Details
- **n8n Container:** Built with custom Alpine-based Node image containing **FFmpeg** and **Tini** for process execution.
- **n8n running user:** Configured to run as root (`user: "0:0"`) to allow file access and local shell commands for video processing under `/tmp/`.
- **Database:** PostgreSQL 16 Alpine container with persistent storage volumes.