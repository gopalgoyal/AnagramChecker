using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http.Json;
using System.Text.Json.Serialization;
using System.Linq;

var builder = WebApplication.CreateBuilder(args);
var urls = Environment.GetEnvironmentVariable("ANAGRAM_WEB_VALIDATOR_URLS")
    ?? "http://0.0.0.0:5000";
builder.WebHost.UseUrls(urls.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
builder.Services.Configure<JsonOptions>(o => o.SerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull);
var app = builder.Build();

app.MapPost("/api/anagram", async (HttpRequest req) =>
{
    var dto = await req.ReadFromJsonAsync<AnagramRequest>();
    if (dto == null) return Results.BadRequest();
    bool isAnagram = AreAnagrams(dto.String1, dto.String2);
    return Results.Json(new { isAnagram });
});

app.MapGet("/", async () =>
{
    var htmlPath = Path.Combine(AppContext.BaseDirectory, "index.html");
    if (File.Exists(htmlPath))
    {
        var html = await File.ReadAllTextAsync(htmlPath);
        return Results.Content(html, "text/html");
    }
    return Results.Text("Anagram API running");
});

app.Run();

static bool AreAnagrams(string? a, string? b)
{
    if (a == null || b == null) return false;
    var sa = new string(a.Where(char.IsLetterOrDigit).Select(char.ToLower).ToArray());
    var sb = new string(b.Where(char.IsLetterOrDigit).Select(char.ToLower).ToArray());
    return sa.OrderBy(c => c).SequenceEqual(sb.OrderBy(c => c));
}

record AnagramRequest([property: JsonPropertyName("string1")] string? String1, [property: JsonPropertyName("string2")] string? String2);
