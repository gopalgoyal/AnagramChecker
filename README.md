# Anagram Checker — Test Framework

A BDD test framework built with **SpecFlow + NUnit** that checks if two strings are anagrams.

---

## What is an Anagram?

Two words that contain the same letters in a different order.

| Word 1 | Word 2 | Anagram? |
|---|---|---|
| listen | silent | Yes |
| hello | world | No |
| school master | the classroom | Yes |

---

## Project Structure

```
AnagramAutomation/
├── Features/
│   ├── Anagram_Checker.feature                  ← `@anagram` scenario outline (logic)
│   └── Anagram _Checker_APIValidation.feature   ← `@api` + `@anagram` scenario outline (API)
├── Steps/
│   ├── AnagramSteps.cs              ← Runs the anagram logic tests
│   └── ApiSteps.cs                  ← Runs the API tests
├── Support/
│   └── AnagramHelper.cs             ← Core anagram logic
├── Hooks/
│   └── TestHooks.cs                 ← Auto-starts/stops AnagramWebValidator service
├── AnagramWebValidator/
│   ├── Program.cs                   ← Local REST API (localhost:5000)
│   └── index.html                   ← Web UI for manual testing
├── scripts/
│   └── run-tests.ps1                ← One script: runs tests + report
├── tools/
│   └── TrxToExtent/
│       └── TrxToExtent.ps1          ← Converts TRX results to HTML report
├── TestResults/
│   ├── anagram-results.trx          ← Raw test output (auto-generated)
│   └── AnagramExtentReport.html     ← HTML report (auto-generated)
├── anagram.runsettings              ← Test configuration (env vars, paths)
└── AnagramAutomation.csproj
```

---

## Run Tests

### Option 1 — Single command (recommended)

From the **workspace root** (`AnagramChecker-main/`):

```powershell
powershell -ExecutionPolicy Bypass -File AnagramAutomation/scripts/run-tests.ps1
```

This automatically:
1. Kills any leftover process on port 5000
2. Starts the AnagramWebValidator service and waits until it's ready
3. Runs tests (all by default)
4. Stops the AnagramWebValidator service
5. Generates the HTML report
6. Opens the report in your browser

### Run by tag (optional)

From the workspace root:

```powershell
powershell -ExecutionPolicy Bypass -File AnagramAutomation/scripts/run-tests.ps1 -Tag anagram
powershell -ExecutionPolicy Bypass -File AnagramAutomation/scripts/run-tests.ps1 -Tag api
```

You can pass tag names with or without `@` (for example `api` or `@api`).

### Option 2 — VS Code keyboard shortcut

Press `Ctrl+Shift+B` — does the same as the command above.

### Option 3 — VS Code Test Explorer

Click the flask icon in the sidebar. The `anagram.runsettings` file ensures AnagramWebValidator starts automatically.

---

## Tests

There are **16 tests** in total:

### Scenario Outline — 8 tests (anagram logic)

Defined in `Features/Anagram_Checker.feature`:

| input1 | input2 | Expected |
|---|---|---|
| listen | silent | true |
| hello | world | false |
| conversation | voices rant on | true |
| school master | the classroom | true |
| a gentleman | elegant man | true |
| eleven plus two | twelve plus one | true |
| apple | paple | true |
| rat | car | false |

Tag: `@anagram`

### Scenario Outline — 8 tests (API)

Defined in `Features/Anagram _Checker_APIValidation.feature`.

Tags: `@anagram`, `@api`

---

## Add a New Test

Open `Features/Anagram_Checker.feature` and add a row to the Examples table:

```gherkin
Examples:
  | input1  | input2  | output |
  | listen  | silent  | true   |
  | save    | vase    | true   |   <- add your row here
```

Save the file (auto-formats on save) then run tests. No code changes needed.

---

## View Results

The HTML report opens automatically after `run-tests.ps1` finishes.

To open it manually:
```powershell
Start-Process AnagramAutomation/TestResults/AnagramExtentReport.html
```

The report shows:
- Total / Passed / Failed / Skipped counts
- Pass rate progress bar
- Per-test result with badge (green = pass, red = fail)

---

## VS Code Features

| Feature | How it works |
|---|---|
| **Go to Definition** | Click a step in the feature file → jumps to the C# method |
| **Auto-format** | Save a `.feature` file → table columns align automatically |
| **Test Explorer** | Run/debug individual tests from the sidebar |

Powered by the **Cucumber Full Language Support** extension configured in `.vscode/settings.json`.

---

## AnagramWebValidator Service

A lightweight ASP.NET Core app that exposes:

| Method | Route | Description |
|---|---|---|
| GET | `/` | Serves `index.html` (web UI) |
| POST | `/api/anagram` | Checks if two strings are anagrams |

**Request body:**
```json
{ "string1": "listen", "string2": "silent" }
```

**Response:**
```json
{ "isAnagram": true }
```

The API starts and stops automatically during test runs. To run it manually:
```powershell
dotnet run --project AnagramAutomation/AnagramWebValidator/AnagramWebValidator.csproj
```
Then open `http://localhost:5000` in a browser.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Port 5000 already in use | The script kills it automatically on next run |
| API test fails (status 0) | Run via `run-tests.ps1` — it manages AnagramWebValidator startup |
| Go to Definition not working | `Ctrl+Shift+P` > `Developer: Reload Window` |
| Old TRX files accumulating | The script deletes them automatically after each run |
| AnagramWebValidator build fails | Delete `AnagramAutomation/AnagramWebValidator/bin/` and re-run |
