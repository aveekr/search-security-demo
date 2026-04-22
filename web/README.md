# Demo Web UI

This folder contains a browser-based demo UI for:
- Sign in with Microsoft Entra ID
- Resolve user -> advisor mapping
- Upload documents
- Search documents with advisor-level filtering

## Setup

1. Copy config template:

```powershell
cd web
copy config.sample.js config.js
```

2. Edit `config.js` with your values:
- `entra.clientId`
- `entra.tenantId`
- `entra.redirectUri` (default: `http://localhost:8080`)
- `api.baseUrl`
- `api.functionKey`

3. Start local static server:

```powershell
cd web
python -m http.server 8080
```

4. Open:

`http://localhost:8080`

## Notes

- This demo sends Function key from browser for speed of setup. For production, place UI behind APIM and avoid exposing function keys in frontend code.
- `GET /api/me-context` resolves the login identity to advisor ID using SQL `UserIdentityMap`.
- If no SQL mapping is found, UI can use `fallbackAdvisorMap` from `config.js`.

## Login Troubleshooting

If clicking **Sign in** does nothing or fails immediately:

1. Add this redirect URI in Entra App Registration:
	- `http://localhost:8080`
2. In Azure Portal, App Registration -> Authentication:
	- Add platform: **Single-page application (SPA)**
	- Add redirect URI: `http://localhost:8080`
3. Save, then hard refresh browser and retry.
