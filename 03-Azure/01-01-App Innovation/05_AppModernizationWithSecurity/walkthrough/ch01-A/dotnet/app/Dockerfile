# Multi-stage build: compile with the SDK image, run on the smaller ASP.NET runtime image.
# Build context is the dotnet/ folder, so all paths below are relative to it.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore first so the package layer is cached independently of source changes.
COPY src/LegoCatalog.App/LegoCatalog.App.csproj src/LegoCatalog.App/
RUN dotnet restore src/LegoCatalog.App/LegoCatalog.App.csproj

COPY src/ src/
RUN dotnet publish src/LegoCatalog.App/LegoCatalog.App.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Kestrel listens on 8080 so the container can run as a non-root user.
ENV ASPNETCORE_URLS=http://+:8080 \
    CATALOG_SEED_PATH=/data/catalog.json \
    CATALOG_IMAGES_PATH=/data/images

COPY --from=build /app/publish .

# The seed JSON and the product images are static content mounted at runtime,
# not baked into the image.
VOLUME ["/data"]

EXPOSE 8080
USER $APP_UID

ENTRYPOINT ["dotnet", "LegoCatalog.App.dll"]
