---
summary: "Amazon Bedrock provider data sources: AWS CLI foundation model inventory via region + profile."
read_when:
  - Debugging Bedrock usage or auth issues
  - Updating Bedrock AWS CLI commands or parsing
---

# Amazon Bedrock provider

Amazon Bedrock uses the AWS CLI to list foundation models for a given region and profile. No browser cookies or API tokens beyond standard AWS credentials.

## Data sources + fallback order

1) **AWS CLI** (`aws bedrock list-foundation-models`)
   - No fallback — single-source CLI strategy.

## Credentials (if applicable)

- Requires AWS CLI installed and configured (`aws configure`).
- Uses standard AWS credential chain (env vars, `~/.aws/credentials`, IAM roles).
- Optional `AWS_PROFILE` for named profile selection.

## API endpoints / Probe mechanism

- **Strategy**: `bedrock.cli` (kind: `.cli`)
- **Command**: `aws bedrock list-foundation-models --region <region> --output json`
- **Timeout**: 20 seconds
- **PATH augmentation**: Ensures `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, `/bin`, `/usr/sbin`, `/sbin` are on PATH.

### Configuration resolution (in order)

**Region** (required):
1. Preferences setting `bedrock.region`
2. `AWS_REGION` env var
3. `AWS_DEFAULT_REGION` env var

**Profile** (optional):
1. Preferences setting `bedrock.profile`
2. `AWS_PROFILE` env var

**Model filter** (optional, client-side filtering):
1. Preferences setting `bedrock.modelID`
2. `BEDROCK_MODEL_ID` env var

When a model filter is set, results are filtered client-side by matching the filter string (case-insensitive) against `modelId`, `modelName`, and `providerName`.

## Parsing + mapping

- AWS CLI returns JSON with `modelSummaries[]`, each containing `modelId`, `modelName`, `providerName`.
- Snapshot shows model count, region, profile (if set), filter (if set), and up to 3 model IDs.
- No quota/rate-limit windows — `usedPercent` is always 0, `hasKnownLimit` is false.
- Primary `RateWindow` label: "Foundation models".
- Supports model breakdown via `supportsModelBreakdown: true`.

## Key files
- `Sources/RunicCore/Providers/Bedrock/BedrockProviderDescriptor.swift`
- `Sources/RunicCore/Providers/Bedrock/BedrockUsageFetcher.swift`
