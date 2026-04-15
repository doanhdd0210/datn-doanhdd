FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY DatnBackend.Api/DatnBackend.Api.csproj DatnBackend.Api/
RUN dotnet restore DatnBackend.Api/DatnBackend.Api.csproj
COPY . .
RUN dotnet publish DatnBackend.Api/DatnBackend.Api.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/publish .
# PORT được Render inject tự động lúc runtime
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
ENTRYPOINT ["dotnet", "DatnBackend.Api.dll"]
