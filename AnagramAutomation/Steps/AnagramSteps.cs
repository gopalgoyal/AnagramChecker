using NUnit.Framework;
using TechTalk.SpecFlow;
using AnagramAutomation.Support;

namespace AnagramAutomation.Steps
{
    /// <summary>
    /// SIMPLE EXPLANATION:
    /// This file contains the code that runs each test step.
    /// 
    /// What it does:
    /// 1. Gets the two words from the test scenario
    /// 2. Checks if they are anagrams (using AnagramHelper)
    /// 3. Compares the result with what we expected
    /// 
    /// You don't need to change this file!
    /// Just read the feature file to understand the tests.
    /// </summary>
    [Binding]
    public class AnagramSteps
    {
        // Store the words we're testing
        private string _a = "";
        private string _b = "";
        
        // Store the result (true or false)
        private bool _result;

        /// <summary>
        /// STEP 1: Get the input words
        /// This runs when the test says: "Given the input strings X and Y"
        /// </summary>
        [Given("the input strings \"(.*)\" and \"(.*)\"")]
        public void GivenTheInputStrings(string a, string b)
        {
            _a = a;
            _b = b;
        }

        /// <summary>
        /// STEP 2: Check if they are anagrams
        /// This runs when the test says: "When I check if they are anagrams"
        /// </summary>
        [When("I check if they are anagrams")]
        public void WhenICheckIfTheyAreAnagrams()
        {
            _result = AnagramHelper.AreAnagrams(_a, _b);
        }

        /// <summary>
        /// STEP 3: Verify the result
        /// This runs when the test says: "Then the result should be X"
        /// </summary>
        [Then("the result should be \"(.*)\"")]
        public void ThenTheResultShouldBe(string expected)
        {
            var exp = bool.Parse(expected);
            Assert.AreEqual(exp, _result);
        }
    }
}
