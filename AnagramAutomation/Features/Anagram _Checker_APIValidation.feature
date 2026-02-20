@api
Feature: Anagram Checker API Validation
    As a user
    I want to validate if two strings are anagrams via API
    So that I can verify API behavior

    @anagram
    Scenario Outline: Validate via AnagramAPI if two strings are anagrams
        Given a running Anagram API at "http://localhost:5000"
        When I POST to "/api/anagram" with payload strings "<input1>" and "<input2>"
        Then the API response field "isAnagram" should be "<output>"

        Examples:
            | input1          | input2          | output |
            | listen          | silent          | true   |
            | hello           | world           | false  |
            | conversation    | voices rant on  | true   |
            | school master   | the classroom   | true   |
            | a gentleman     | elegant man     | true   |
            | eleven plus two | twelve plus one | true   |
            | apple           | paple           | true   |
            | rat             | car             | false  |
