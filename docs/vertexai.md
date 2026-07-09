---
summary: "Vertex AI provider data sources: gcloud CLI model inventory via project + region configuration."
read_when:
  - Debugging Vertex AI usage or auth issues
  - Updating Vertex AI gcloud commands or parsing
---

# Vertex AI provider

Vertex AI uses the `gcloud` CLI to list available AI models for a Google Cloud project and region. No API token or browser cookies.

## Data sources + fallback order

1) **gcloud CLI** (`gcloud ai models list`)
   - No fallback — single-source CLI strategy.

## Credentials (if applicable)

- Requires `gcloud` CLI installed and authenticated (`gcloud auth login`).
- Authenticated via standard Google Cloud ADC (Application Default Credentials) — `GOOGLE_APPLICATION_CREDENTIALS` env var or `gcloud auth application-default login`.

## API endpoints / Probe mechanism

- **Strategy**: `vertexai.cli` (kind: `.cli`)
- **Command**: `gcloud ai models list --project=<project> --region=<location> --format=json`
- **Timeout**: 20 seconds
- **PATH augmentation**: Ensures `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin` are on PATH.

### Configuration resolution (in order)

**Project**:
1. Preferences setting `vertexai.project`
2. `VERTEX_AI_PROJECT` env var
3. `GOOGLE_CLOUD_PROJECT` env var
4. `GCLOUD_PROJECT` env var

**Location** (defaults to `us-central1`):
1. Preferences setting `vertexai.location`
2. `VERTEX_AI_LOCATION` env var
3. `GOOGLE_CLOUD_REGION` env var

## Parsing + mapping

- gcloud returns a JSON array of models (not a wrapped object). `VertexAIModelsResponse` decodes the top-level array directly.
- Each model has `name` (resource path) and `displayName` (human label).
- Snapshot shows model count, project, region, and up to 3 display names as a preview.
- No quota/rate-limit windows — `usedPercent` is always 0, `hasKnownLimit` is false.
- Primary `RateWindow` label: "AI models".
- Supports model breakdown via `supportsModelBreakdown: true`.

## Key files
- `Sources/RunicCore/Providers/VertexAI/VertexAIProviderDescriptor.swift`
- `Sources/RunicCore/Providers/VertexAI/VertexAISettingsReader.swift`
- `Sources/RunicCore/Providers/VertexAI/VertexAIUsageFetcher.swift`
