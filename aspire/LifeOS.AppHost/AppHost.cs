var builder = DistributedApplication.CreateBuilder(args);

var postgres = builder.AddPostgres("postgres")
    .WithDataVolume("postgres-data")
    .WithLifetime(ContainerLifetime.Persistent);

var moneyDb = postgres.AddDatabase("money-db");

var money = builder.AddProject<Projects.LifeOS_Money_Api>("money")
    .WithReference(moneyDb);

var gateway = builder.AddProject<Projects.LifeOS_Gateway>("gateway")
    .WithReference(money)
    .WithExternalHttpEndpoints();

builder.Build().Run();
