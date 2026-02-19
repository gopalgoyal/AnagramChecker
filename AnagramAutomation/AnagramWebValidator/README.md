# Anagram Web Validator

Run the API locally to provide an endpoint for API/RestAssured validation.

Run:

```powershell
cd AnagramAutomation\AnagramWebValidator
dotnet run
```

The service will be available at http://localhost:5000 and exposes:
- POST /api/anagram  { "string1":"...", "string2":"..." } -> { "isAnagram": true|false }
