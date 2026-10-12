#:sdk Aspire.AppHost.Sdk@13.5.3
#:package Aspire.Hosting.JavaScript@13.5.3
#:package Aspire.Hosting.Python@13.5.3

var builder = DistributedApplication.CreateBuilder(args);



#pragma warning disable ASPIRECSHARPAPPS001 // Type is for evaluation purposes only and is subject to change or removal in future updates. Suppress this diagnostic to proceed.

var app = builder.AddUvicornApp("app", "./app", "main:app")
    .WithUv()
    //.WithEnvironment("REPAIR_PLANNER_AGENT_URL", dotnetapp.GetEndpoint("https"))
    .WithArgs("--host", "0.0.0.0", "--port", "8000")
    .WithHttpsEndpoint(port: 8000, name: "api", isProxied: false)
    .WithExternalHttpEndpoints()
    .WithHttpHealthCheck("/health", endpointName: "api");

var appApiEndpoint = app.GetEndpoint("api");

var dotnetworkflow = builder.AddCSharpApp("dotnetworkflow", "./dotnetworkflow/FactoryWorkflow.csproj")
    .WithExternalHttpEndpoints()
    // .WithEnvironment("SSL_CERT_DIR", "/etc/ssl/certs")
   // .WithHttpEndpoint(port:8001, env: "DOTNETWORKFLOW_PORT", name: "api")
    .WithEnvironment("SSL_CERT_FILE", "/etc/ssl/certs/ca-certificates.crt")
    .WithReference(app)
    .WithEnvironment("MAINTENANCE_SCHEDULER_AGENT_URL", ReferenceExpression.Create($"{appApiEndpoint}/maintenance-scheduler"))
    .WithEnvironment("PARTS_ORDERING_AGENT_URL", ReferenceExpression.Create($"{appApiEndpoint}/parts-ordering"))
    .WithHttpHealthCheck("/health");
#pragma warning restore ASPIRECSHARPAPPS001 // Type is for evaluation purposes only and is subject to change or removal in future updates. Suppress this diagnostic to proceed.
// Use the externally reachable HTTP endpoint for the frontend (Aspire also creates an internal/proxied endpoint).
var apiEndpoint = dotnetworkflow.GetEndpoint("http")
    ?? throw new InvalidOperationException("Expected 'http' endpoint for 'dotnetworkflow' was not created.");
var frontend = builder.AddViteApp("frontend", "./frontend")
    .WithReference(dotnetworkflow)
    .WithReference(app);

var codespaceName = Environment.GetEnvironmentVariable("CODESPACE_NAME");
var codespacesPortForwardingDomain = Environment.GetEnvironmentVariable("GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN");

if (!string.IsNullOrWhiteSpace(codespaceName) && !string.IsNullOrWhiteSpace(codespacesPortForwardingDomain))
{
    frontend.WithEnvironment("VITE_API_URL", () => $"https://{codespaceName}-{apiEndpoint.Port}.{codespacesPortForwardingDomain}/");
}
else
{
    frontend.WithEnvironment("VITE_API_URL", ReferenceExpression.Create($"{apiEndpoint}/"));
}

frontend.WaitFor(app)
    .WaitFor(dotnetworkflow);

app.PublishWithContainerFiles(frontend, "./static");

builder.Build().Run();
