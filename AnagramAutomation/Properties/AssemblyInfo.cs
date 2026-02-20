using NUnit.Framework;

//parallelizable
[assembly: Parallelizable(ParallelScope.Fixtures)]
[assembly: LevelOfParallelism(4)]

//non parallelizable
//[assembly: NonParallelizable]