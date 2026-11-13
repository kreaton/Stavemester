# Stavemester

![Blazor WebAssembly](https://img.shields.io/badge/Blazor-WebAssembly-lightgrey)
![.NET 10](https://img.shields.io/badge/.NET-10-lightgrey)
![Installable web app](https://img.shields.io/badge/PWA-installable-lightgrey)

![Stavemester: stavespil for børn på 5-6 år](images/banner.png)

**Stavespil for børn på 5–6 år.**

Et billede vises sammen med en kasse pr. bogstav i ordet. Barnet trykker bogstaverne ind fra
et stort tastatur (A–Å). Et forkert bogstav giver en besked og en lyd, `?` viser det næste
bogstav (som barnet så selv skal finde på tastaturet), og et færdigt ord giver hurra.

- **Niveau 1** – første bogstav er skrevet på forhånd.
- **Niveau 2** – ingen hjælp.

## Ordbogen

Ordene ligger i `src/Stavemester/wwwroot/ordbog.json`:

```json
[
  { "word": "kat", "image": "🐱" },
  { "word": "hest", "image": "hest.jpg", "sound": "hest.mp3" }
]
```

| Felt    | Betydning |
|---------|-----------|
| `word`  | Ordet. Store/små bogstaver er ligegyldige; kun A–Z, Æ, Ø og Å (ord med andre tegn springes over). |
| `image` | En emoji, eller et filnavn (`.jpg`, `.png`, `.webp`, `.gif`, `.svg`) i `wwwroot/images/`. |
| `sound` | Valgfri. Et lydklip i `wwwroot/sounds/`, der afspilles når ordet vises og med 🗣️-knappen. |

Filen må indeholde kommentarer (`// ...` og `/* ... */`) og et komma efter sidste element, fx
til at slå et ord fra midlertidigt:

```json
  // { "word": "mille", "image": "IMG_9678.jpg" },
```

Ordene kommer i tilfældig rækkefølge, og alle ord vises én gang før nogen gentages.

## Kør og udgiv

```bash
dotnet run --project src/Stavemester
```

`src/Stavemester/Publish.bat` udgiver til `bin/Publish`. Ikonerne laves med
`powershell -File tools\make-icons.ps1`.

## Deploy

**GitHub Actions:** `.github/workflows/deploy.yml` udgiver ved hvert push til `main` (eller manuelt
fra fanen Actions) og lægger spillet i mappen `stavemester/` på KidsGames' GitHub Pages:
<https://kreaton.github.io/KidsGames/stavemester/>. Den bruger repository secret `PAGES_DEPLOY_KEY`.
