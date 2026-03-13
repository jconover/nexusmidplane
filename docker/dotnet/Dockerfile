# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files from app/dotnet-app (build context is repo root)
COPY app/dotnet-app/ .

RUN dotnet restore
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
# NOTE: In real on-prem this would be Windows Server + IIS.
# We use Linux ASP.NET Core runtime here for cross-platform portability.
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

COPY --from=build /app/publish .

EXPOSE 5000
ENV ASPNETCORE_URLS=http://+:5000

ENTRYPOINT ["dotnet", "dotnet-app.dll"]
