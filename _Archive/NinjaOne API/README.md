# Archive: NinjaOne API scripts

Not in use. Archived on 25 November 2026.

These scripts call the NinjaOne public API (and the Halo API) from one always-on management device, then write custom fields or create Halo tickets for all devices. They were archived because they need that management device and API secrets stored on it. The current approach uses only per-device scripts, the native Halo-NinjaOne sync and NinjaOne alerts.

| Script | What it did |
|---|---|
| RPT-HW Warranty - NinjaOne Dates to Custom Field | Copied NinjaOne warranty dates to `warrantyEndDate` and `warrantyStartDate` |
| RPT-SEC Patch and AV - NinjaOne Status to Custom Field | Wrote `patchStatus` and `avStatus` for every Windows device |
| MON-SYS Stale Devices - NinjaOne Last Seen to Halo | Wrote `lastSeenStatus`; optional Halo review ticket per client |
| MON-SYS Lifecycle - Refresh Opportunities to Halo | Wrote `lifecycleFlag`; optional Halo opportunity per client |
| CFG-MNT Onboarding - Halo Client to NinjaOne Organisation | Created a NinjaOne organisation from a Halo client and printed installer links |

## Before using them again

- They were tested only against a fake API, never against a live tenant.
- They call `/v2/...`. The 2022 API spec lists `/api/v2/...`. `expand=warranty` is not in that spec.
- Fields they used: `ninjaApiClientId`, `ninjaApiClientSecret`, `haloApiUrl`, `haloApiTenant`, `haloApiClientId`, `haloApiClientSecret` (management device only), plus the output fields above. Fields written through the API need the **API** permission set to **Read/Write**.
