Anagram Automation

## How to Run Tests + Generate Report

### Option 1 — Single command (recommended)

From the **workspace root** (`AnagramChecker-main/`):

```powershell
powershell -ExecutionPolicy Bypass -File AnagramAutomation/scripts/run-tests.ps1
```

This automatically:
1. Kills any leftover process on port 5000
2. Starts the AnagramWebValidator service and waits until it responds
3. Runs tests (all by default)
4. Stops the AnagramWebValidator service
5. Generates the HTML report
6. Opens the report in your browser

### Run by tag (optional)

From the **workspace root**:

```powershell
powershell -ExecutionPolicy Bypass -File AnagramAutomation/scripts/run-tests.ps1 -Tag anagram
powershell -ExecutionPolicy Bypass -File AnagramAutomation/scripts/run-tests.ps1 -Tag api
```

You can pass tag names with or without `@` (for example `api` or `@api`).

### Option 2 — VS Code keyboard shortcut

Press `Ctrl+Shift+B` — does the same as the command above.

### Option 3 — VS Code Test Explorer

Click the flask icon in the sidebar. The `anagram.runsettings` file automatically injects `START_DUMMY_API=true` so AnagramWebValidator starts before the API test runs.

> Note: Test Explorer does not auto-open the HTML report. Run `run-tests.ps1` to get the report.

---

## Report

The HTML report is generated at:

```
AnagramAutomation/TestResults/AnagramExtentReport.html
```

To open it manually:

```powershell
Start-Process AnagramAutomation/TestResults/AnagramExtentReport.html
```

The report shows total / passed / failed / skipped counts, a pass-rate progress bar, and a per-test result table with colour-coded badges.

---

## Project Structure

```
AnagramAutomation/
├── Features/
│   ├── Anagram_Checker.feature                  <- `@anagram` scenario outline (logic)
│   └── Anagram _Checker_APIValidation.feature   <- `@api` + `@anagram` scenario outline (API)
├── Steps/
│   ├── AnagramSteps.cs              <- Runs the anagram logic tests
│   └── ApiSteps.cs                  <- Runs the API tests
├── Support/
│   └── AnagramHelper.cs             <- Core anagram logic
├── Hooks/
│   └── TestHooks.cs                 <- Auto-starts/stops AnagramWebValidator service
├── AnagramWebValidator/
│   ├── Program.cs                   <- Local REST API (localhost:5000)
│   └── index.html                   <- Web UI for manual testing
├── scripts/
│   └── run-tests.ps1                <- One script: runs tests + report
├── tools/
│   └── TrxToExtent/
│       └── TrxToExtent.ps1          <- Converts TRX results to HTML report
├── TestResults/
│   ├── anagram-results.trx          <- Raw test output (auto-generated)
│   └── AnagramExtentReport.html     <- HTML report (auto-generated)
└── anagram.runsettings              <- Test configuration (env vars, paths)
```

---

## Adding a New Test

Open either feature file and add a row to the Examples table:

```gherkin
Examples:
  | input1 | input2 | output |
  | listen | silent | true   |
  | save   | vase   | true   |   <- add your row here
```

Save the file then run tests. No code changes needed.
