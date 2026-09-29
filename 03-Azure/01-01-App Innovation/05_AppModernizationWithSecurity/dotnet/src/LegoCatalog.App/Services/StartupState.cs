namespace LegoCatalog.App.Services;

/// <summary>
/// Represents startup migration/import readiness independently from database health.
/// </summary>
public sealed class StartupState
{
    private int _status = (int)StartupStatus.Pending;

    public StartupStatus Status => (StartupStatus)Volatile.Read(ref _status);

    public void MarkReady() =>
        Interlocked.Exchange(ref _status, (int)StartupStatus.Ready);

    public void MarkFailed() =>
        Interlocked.Exchange(ref _status, (int)StartupStatus.Failed);
}

public enum StartupStatus
{
    Pending,
    Ready,
    Failed,
}
