using System;
using System.Linq;

namespace AnagramAutomation.Support
{
    public static class AnagramHelper
    {
        public static bool AreAnagrams(string a, string b)
        {
            if (a == null || b == null) return false;
            Func<string, string> norm = s => new string(s.ToLowerInvariant().Where(c => !char.IsWhiteSpace(c)).OrderBy(c => c).ToArray());
            return norm(a) == norm(b);
        }
    }
}
