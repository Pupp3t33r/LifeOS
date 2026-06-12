FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["services/money/LifeOS.Money.Api/LifeOS.Money.Api.csproj", "services/money/LifeOS.Money.Api/"]
COPY ["aspire/LifeOS.ServiceDefaults/LifeOS.ServiceDefaults.csproj", "aspire/LifeOS.ServiceDefaults/"]
RUN dotnet restore "services/money/LifeOS.Money.Api/LifeOS.Money.Api.csproj"
COPY . .
WORKDIR "/src/services/money/LifeOS.Money.Api"
RUN dotnet build "LifeOS.Money.Api.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "LifeOS.Money.Api.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "LifeOS.Money.Api.dll"]
