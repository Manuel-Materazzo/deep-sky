# AI Asset Generation Tools — Terms of Use & License Evaluation

**Reference IDs:** `CNT-02`, `D-11`, `A-08`  
**Verification Date:** 2026-11-14  
**Status:** Prepared for promoter decision (`D-11`) — **no AI-generated assets are committed to the repository yet.**

## Summary of Candidate Tools

| Tool / Platform | Ownership & Commercial Use of Outputs | Redistribution in Public Open-Source Repo | Key Caveats & Restrictions | Official Source |
| :-- | :-- | :-- | :-- | :-- |
| **OpenAI (ChatGPT / GPT Image API)** | OpenAI assigns its rights in outputs to the user; commercial use permitted | Allowed under OpenAI Terms of Use (user holds contractual rights to output) | Purely AI-generated outputs may lack statutory copyright; non-exclusive across similar prompts; must respect Usage Policies | `https://openai.com/policies/row-terms-of-use/` |
| **Google (Gemini / Imagen / Vertex AI)** | Google claims no ownership over generated outputs; commercial use permitted | Allowed to publish and redistribute output images | Cannot use outputs to train/build a competing image generation model; SynthID/provenance markers must not be stripped | `https://ai.google.dev/gemini-api/terms` |
| **Recraft (Paid Plans / API)** | Paid plans and API grant full ownership and commercial rights | Allowed on **paid** plans/API | **Free tier is non-commercial** and outputs belong to Recraft (public gallery) — **do not use free tier** for repo assets | `https://www.recraft.ai/terms` |
| **Ideogram (Hosted Web / API)** | Users retain rights to outputs from the hosted service; commercial use allowed | Allowed for hosted service outputs (check active plan visibility) | **Open-weight model releases** (e.g. non-commercial agreements) prohibit commercial deployment/redistribution of weights | `https://ideogram.ai/terms` |
| **Black Forest Labs (FLUX)** | Outputs from hosted/API or commercially licensed models usable commercially | Output redistribution permitted; **Dev weights** are non-commercial | Restricted open-weights (Dev) require a commercial license for commercial products/services | `https://bfl.ai/legal/terms-of-service` |
| **Midjourney (Paid Plans)** | Users own assets created under paid plans (Pro/Mega required if gross revenue > $1M/yr) | Allowed for paid outputs; free/canceled public gallery remix rules apply | No official API; default generations are public unless using Stealth Mode (Pro/Mega) | `https://docs.midjourney.com/docs/terms-of-service` |

## Practical Risks for Open-Source Redistribution (`A-08`)

1. **Non-exclusivity and copyrightability:** In major jurisdictions (US, EU, UK), raw unedited AI outputs generally lack human authorship and cannot be claimed under exclusive copyright. Any license placed on raw AI outputs primarily communicates downstream permissions and project intent rather than enforceable exclusivity.
2. **Free-tier traps:** Several platforms (notably **Recraft Free**) retain ownership or forbid commercial use on free tiers. If Deep Sky or a downstream self-hoster later uses the app in a paid hosting setup (`project-brief.md` ch. 12), free-tier non-commercial assets would create a licensing conflict.
3. **Attribution / AI-training clauses:** None of the platforms allow redistributing assets *as a training dataset for competing models* where prohibited by platform terms; asset documentation should state provenance transparently.

## Recommendation for Promoter (`D-11`)

1. **Tool choice:** Prefer **OpenAI (ChatGPT/GPT Image)**, **Google (Gemini/Imagen via paid/API or standard Gemini)**, or **Recraft Paid/API** (avoiding free tiers with non-commercial restrictions). Record the exact tool and tier in each asset's catalog entry (`A-07`).
2. **Separate Asset License (`content/LICENSE-ASSETS`):**
   - **Recommended Option A (`CC0-1.0`):** Dedicate the repository's generated visual assets to the public domain via `CC0-1.0` (with an explicit disclaimer that third-party rights/platform terms still apply). Best fit when assets are raw or lightly touched AI outputs that likely carry no exclusive copyright anyway, ensuring zero friction for self-hosters and MIT forks.
   - **Option B (`CC-BY-4.0`):** Use Creative Commons Attribution 4.0 if substantial human artistic editing/composition is performed and attribution to Deep Sky is desired (compatible with MIT distribution as separate media files, though requires attribution notices in forks).
   - **Avoid:** Applying MIT directly to images without a dedicated `LICENSE-ASSETS` file (MIT is written for software source code and does not clearly address AI-generated media).

## Next Step (Promoter Decision)

- Choose the approved generation tool(s) and tier.
- Confirm **Option A (`CC0-1.0`)** or **Option B (`CC-BY-4.0`)** for `content/LICENSE-ASSETS`.
- Only after this approval may `DS-2` pilot assets be committed to the repository.
