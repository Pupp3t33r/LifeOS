FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["services/gateway/LifeOS.Gateway/LifeOS.Gateway.csproj", "services/gateway/LifeOS.Gateway/"]
COPY ["aspire/LifeOS.ServiceDefaults/LifeOS.ServiceDefaults.csproj", "aspire/LifeOS.ServiceDefaults/"]
RUN dotnet restore "services/gateway/LifeOS.Gateway/LifeOS.Gateway.csproj"
COPY . .
WORKDIR "/src/services/gateway/LifeOS.Gateway"
RUN dotnet build "LifeOS.Gateway.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "LifeOS.Gateway.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "LifeOS.Gateway.dll"]
