using LegoCatalog.App.Services;

namespace LegoCatalog.App.Tests;

public sealed class ImageSecurityTests
{
    [Theory]
    [InlineData("../catalog.json")]
    [InlineData("..\\catalog.json")]
    [InlineData("%2e%2e%2fcatalog.json")]
    [InlineData("10000000-0000-4000-8000-000000000001.PNG")]
    [InlineData("not-a-uuid.png")]
    public void RejectsNonCanonicalImageKeys(string key)
    {
        Assert.False(LocalImageStore.IsCanonicalImageKey(key));
    }

    [Fact]
    public void AcceptsCanonicalImageKey()
    {
        Assert.True(
            LocalImageStore.IsCanonicalImageKey(
                "10000000-0000-4000-8000-000000000001.png"));
    }
}
