using System;
using System.Text.Json;
using System.Threading.Tasks;
using NUnit.Framework;
using RestSharp;
using TechTalk.SpecFlow;

namespace AnagramAutomation.Steps
{
    /// <summary>
    /// SIMPLE EXPLANATION:
    /// This file tests the API (the website's anagram checker).
    /// 
    /// What it does:
    /// 1. Connects to the website (http://localhost:5000)
    /// 2. Sends two words to the API
    /// 3. Gets back the answer (YES or NO)
    /// 4. Checks if the answer is correct
    /// 
    /// Why we need this:
    /// - Tests the API like a user would
    /// - Confirms the website works correctly
    /// </summary>
    [Binding]
    public class ApiSteps
    {
        // The website URL (must be running for tests to work!)
        private string _baseUrl = "http://localhost:5000";
        
        // Stores the answer from the website
        private RestResponse? _lastResponse;

        /// <summary>
        /// Set the website URL (usually http://localhost:5000)
        /// </summary>
        [Given("a running Anagram API at \"(.*)\"")]
        public void GivenARunningAnagramApiAt(string url)
        {
            _baseUrl = url?.TrimEnd('/') ?? _baseUrl;
        }

        /// <summary>
        /// Send a request to the API with two words
        /// </summary>
        [When("I POST to \"(.*)\" with payload strings \"(.*)\" and \"(.*)\"")]
        public async Task WhenIPostToWithPayloadStrings(string path, string input1, string input2)
        {
            var client = new RestClient(_baseUrl);
            var request = new RestRequest(path, Method.Post);
            request.AddHeader("Content-Type", "application/json");

            // Build payload from inline input strings
            var payload = new JsonObject();
            payload["string1"] = input1;
            payload["string2"] = input2;

            request.AddStringBody(payload.ToString(), DataFormat.Json);
            _lastResponse = await client.ExecuteAsync(request);
        }

        [Then("the API response field \"(.*)\" should be \"(.*)\"")]
        public void ThenTheApiResponseFieldShouldBe(string field, string expected)
        {
            Assert.IsNotNull(_lastResponse, "No API response recorded");
            Assert.AreEqual(200, (int)_lastResponse!.StatusCode, "Unexpected status code: " + _lastResponse.StatusCode);

            using var doc = JsonDocument.Parse(_lastResponse.Content ?? "{}");
            if (!doc.RootElement.TryGetProperty(field, out var prop))
                Assert.Fail("Response JSON does not contain field: " + field);

            var actual = prop.GetRawText().Trim('"');
            Assert.AreEqual(expected, actual, "Field value mismatch");
        }

        // Helper lightweight JSON object builder
        private sealed class JsonObject : System.Collections.Generic.Dictionary<string, object?>
        {
            public override string ToString()
            {
                return JsonSerializer.Serialize(this);
            }
        }
    }
}
