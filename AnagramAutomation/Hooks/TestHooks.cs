using System;
using System.IO;
using TechTalk.SpecFlow;
using Serilog;
using System.Drawing;
using System.Diagnostics;
using System.Net.Http;
using System.Threading;

namespace AnagramAutomation.Hooks
{
    [Binding]
    public class TestHooks
    {
        private static readonly string LogFile = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "anagram.log");
        private static Process? _webValidatorProcess;

        [BeforeTestRun]
        public static void BeforeTestRun()
        {
            Log.Logger = new LoggerConfiguration()
                .WriteTo.File(LogFile)
                .CreateLogger();
            Log.Information("Starting Anagram tests");

            // Optionally start the web validator API if environment variable is set
            try
            {
                var startApi = Environment.GetEnvironmentVariable("START_DUMMY_API");
                if (string.Equals(startApi, "true", StringComparison.OrdinalIgnoreCase))
                {
                    var projectPath = Path.GetFullPath(
                        Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "AnagramWebValidator"));
                    var psi = new ProcessStartInfo("dotnet", $"run --project \"{projectPath}\"")
                    {
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        CreateNoWindow = true
                    };
                    _webValidatorProcess = Process.Start(psi);

                    // Poll until the API responds or 30s timeout
                    using var http = new HttpClient();
                    var deadline = DateTime.UtcNow.AddSeconds(30);
                    while (DateTime.UtcNow < deadline)
                    {
                        try
                        {
                            var response = http.GetAsync("http://localhost:5000/").Result;
                            Log.Information("AnagramWebValidator ready (status {0})", response.StatusCode);
                            break;
                        }
                        catch
                        {
                            Thread.Sleep(500);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Log.Warning("Failed to start dummy API: {0}", ex.Message);
            }
        }

        [AfterTestRun]
        public static void AfterTestRun()
        {
            Log.Information("Finished Anagram tests");
            Log.CloseAndFlush();

            try
            {
                if (_webValidatorProcess != null && !_webValidatorProcess.HasExited)
                {
                    _webValidatorProcess.Kill(true);
                    _webValidatorProcess.Dispose();
                    _webValidatorProcess = null;
                }
            }
            catch (Exception ex)
            {
                // ignore
            }
        }
    }
}
