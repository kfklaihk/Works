# Migration Code Examples

This document provides side-by-side comparisons of old vs. new code to illustrate the modernization changes.

---

## 1. Project File Format

### Old (.NET Framework 4.6.1)

```xml
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="14.0" DefaultTargets="Build" 
         xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <TargetFrameworkVersion>v4.6.1</TargetFrameworkVersion>
    <RootNamespace>WebApplication1</RootNamespace>
  </PropertyGroup>
  <ItemGroup>
    <Reference Include="EntityFramework, Version=6.0.0.0">
      <HintPath>..\packages\EntityFramework.6.2.0\lib\net45\EntityFramework.dll</HintPath>
    </Reference>
    <Reference Include="System.Web.Mvc, Version=5.2.3.0">
      <HintPath>..\packages\Microsoft.AspNet.Mvc.5.2.3\lib\net45\System.Web.Mvc.dll</HintPath>
    </Reference>
    <!-- Many more references... -->
  </ItemGroup>
</Project>
```

### New (.NET 8)

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.0" />
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="8.0.0" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.5.0" />
  </ItemGroup>
</Project>
```

**Improvement**: 90% less boilerplate, easier to read and maintain.

---

## 2. Configuration

### Old (Web.config)

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <connectionStrings>
    <add name="DefaultConnection" 
         connectionString="Data Source=(LocalDb)\MSSQLLocalDB;..." 
         providerName="System.Data.SqlClient" />
  </connectionStrings>
  <appSettings>
    <add key="webpages:Version" value="3.0.0.0" />
    <add key="UnobtrusiveJavaScriptEnabled" value="true" />
  </appSettings>
  <system.web>
    <compilation debug="true" targetFramework="4.6.1" />
    <httpRuntime targetFramework="4.5.2" />
  </system.web>
</configuration>
```

### New (appsettings.json)

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=ModernStockPortfolio;Trusted_Connection=True;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "JwtSettings": {
    "Secret": "your-secret-key-here",
    "Issuer": "ModernStockPortfolio",
    "Audience": "ModernStockPortfolio",
    "ExpiryMinutes": 60
  },
  "StockApiSettings": {
    "AlphaVantageApiKey": "your-api-key",
    "CacheExpiryMinutes": 15
  }
}
```

**Improvement**: JSON is easier to read, supports hierarchical configuration, can be overridden by environment variables.

---

## 3. Startup/Program.cs

### Old (Global.asax.cs + Startup.cs)

```csharp
// Global.asax.cs
public class MvcApplication : System.Web.HttpApplication
{
    protected void Application_Start()
    {
        AreaRegistration.RegisterAllAreas();
        FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
        RouteConfig.RegisterRoutes(RouteTable.Routes);
        BundleConfig.RegisterBundles(BundleTable.Bundles);
    }
}

// Startup.cs
public partial class Startup
{
    public void ConfigureAuth(IAppBuilder app)
    {
        app.CreatePerOwinContext(ApplicationDbContext.Create);
        app.CreatePerOwinContext<ApplicationUserManager>(ApplicationUserManager.Create);
        app.UseCookieAuthentication(new CookieAuthenticationOptions
        {
            AuthenticationType = DefaultAuthenticationTypes.ApplicationCookie,
            LoginPath = new PathString("/Account/Login")
        });
    }
}
```

### New (Program.cs)

```csharp
var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Database
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Identity
builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// JWT Authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["JwtSettings:Issuer"],
            ValidAudience = builder.Configuration["JwtSettings:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["JwtSettings:Secret"]))
        };
    });

// Add services
builder.Services.AddScoped<IPortfolioService, PortfolioService>();
builder.Services.AddScoped<IStockDataService, StockDataService>();
builder.Services.AddAutoMapper(typeof(MappingProfile));

// CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins("http://localhost:5173")
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

**Improvement**: Single file, clearer service registration, built-in dependency injection.

---

## 4. Controller

### Old (ASP.NET MVC 5)

```csharp
using System.Web.Mvc;
using Microsoft.AspNet.Identity;

namespace WebApplication1.Controllers
{
    [RequireHttps]
    public class HomeController : Controller
    {
        private ApplicationDbContext db = ApplicationDbContext.Create();

        [Authorize]
        public ActionResult Portfolio(string datme, Boolean first = false)
        {
            var id = User.Identity.GetUserId();
            var userid = db.Users.FirstOrDefault(x => x.Id == id).userid;
            
            var stkhldg = from x in db.StkHoldingModels
                          where x.User.userid == userid && x.datetme.CompareTo(datme) <= 0
                          group x by x.Stklist into a
                          select a.OrderByDescending(y => y.datetme).FirstOrDefault();

            var model = new ViewModel_1
            {
                stkhldg = stkhldg.ToList(),
                // ... more assignments
            };

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult CreateTransaction(txModel transaction)
        {
            if (ModelState.IsValid)
            {
                db.txModels.Add(transaction);
                db.SaveChanges();
                return RedirectToAction("Portfolio");
            }
            return View(transaction);
        }
    }
}
```

### New (ASP.NET Core 8 Web API)

```csharp
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using ModernStockPortfolio.Application.DTOs;
using ModernStockPortfolio.Application.Services;

namespace ModernStockPortfolio.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PortfoliosController : ControllerBase
{
    private readonly IPortfolioService _portfolioService;
    private readonly ILogger<PortfoliosController> _logger;

    public PortfoliosController(
        IPortfolioService portfolioService,
        ILogger<PortfoliosController> logger)
    {
        _portfolioService = portfolioService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<PortfolioDto>>> GetPortfolios(
        [FromQuery] string? date = null)
    {
        try
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            var portfolios = await _portfolioService.GetUserPortfoliosAsync(
                userId, date);
            
            return Ok(portfolios);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving portfolios for user");
            return StatusCode(500, "An error occurred while retrieving portfolios");
        }
    }

    [HttpPost("{portfolioId}/transactions")]
    public async Task<ActionResult<TransactionDto>> CreateTransaction(
        Guid portfolioId,
        [FromBody] CreateTransactionDto dto)
    {
        try
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            var transaction = await _portfolioService.CreateTransactionAsync(
                portfolioId, userId, dto);
            
            return CreatedAtAction(
                nameof(GetTransaction),
                new { portfolioId, transactionId = transaction.Id },
                transaction);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating transaction");
            return StatusCode(500, "An error occurred while creating the transaction");
        }
    }
}
```

**Improvements**:
- Returns JSON instead of Views (API-first)
- Dependency injection for DbContext and services
- Async/await for better scalability
- Proper HTTP status codes
- Logging integration
- Clear separation of concerns

---

## 5. Entity Framework

### Old (EF6)

```csharp
public class ApplicationDbContext : IdentityDbContext<ApplicationUser>
{
    public ApplicationDbContext() : base("DefaultConnection", throwIfV1Schema: false)
    {
    }

    public static ApplicationDbContext Create()
    {
        return new ApplicationDbContext();
    }

    public DbSet<StkHoldingModel> StkHoldingModels { get; set; }
    public DbSet<CashholdingModel> CashHoldingModels { get; set; }
    public DbSet<txModel> txModels { get; set; }
}

// Usage in controller
var db = ApplicationDbContext.Create();
var holdings = db.StkHoldingModels.Where(x => x.User.userid == userid).ToList();
```

### New (EF Core 8)

```csharp
public class ApplicationDbContext : IdentityDbContext<ApplicationUser>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<StockHolding> StockHoldings => Set<StockHolding>();
    public DbSet<CashHolding> CashHoldings => Set<CashHolding>();
    public DbSet<Transaction> Transactions => Set<Transaction>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<StockHolding>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Date).IsRequired();
            entity.HasIndex(e => new { e.UserId, e.Date });
            
            entity.HasOne(e => e.User)
                  .WithMany(u => u.StockHoldings)
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // Global query filter
        modelBuilder.Entity<StockHolding>()
            .HasQueryFilter(s => !s.IsDeleted);
    }
}

// Usage in service (injected via DI)
public class PortfolioService : IPortfolioService
{
    private readonly ApplicationDbContext _context;

    public PortfolioService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<List<StockHolding>> GetHoldingsAsync(string userId)
    {
        return await _context.StockHoldings
            .Where(x => x.UserId == userId)
            .Include(x => x.Stock)
            .ToListAsync();
    }
}
```

**Improvements**:
- Constructor injection instead of static factory
- Fluent API configuration in OnModelCreating
- Global query filters
- Async operations
- Better performance

---

## 6. Authentication

### Old (ASP.NET Identity with OWIN)

```csharp
// Login
[HttpPost]
[ValidateAntiForgeryToken]
public async Task<ActionResult> Login(LoginViewModel model, string returnUrl)
{
    if (!ModelState.IsValid)
        return View(model);

    var result = await SignInManager.PasswordSignInAsync(
        model.Email, model.Password, model.RememberMe, 
        shouldLockout: false);

    switch (result)
    {
        case SignInStatus.Success:
            return RedirectToLocal(returnUrl);
        case SignInStatus.LockedOut:
            return View("Lockout");
        default:
            ModelState.AddModelError("", "Invalid login attempt.");
            return View(model);
    }
}
```

### New (ASP.NET Core Identity with JWT)

```csharp
[HttpPost("login")]
public async Task<ActionResult<AuthResponseDto>> Login([FromBody] LoginDto dto)
{
    var user = await _userManager.FindByEmailAsync(dto.Email);
    if (user == null)
        return Unauthorized(new { message = "Invalid credentials" });

    var result = await _signInManager.CheckPasswordSignInAsync(
        user, dto.Password, lockoutOnFailure: false);

    if (!result.Succeeded)
        return Unauthorized(new { message = "Invalid credentials" });

    var token = await _tokenService.GenerateJwtTokenAsync(user);
    var refreshToken = _tokenService.GenerateRefreshToken();

    user.RefreshToken = refreshToken;
    user.RefreshTokenExpiry = DateTime.UtcNow.AddDays(7);
    await _userManager.UpdateAsync(user);

    return Ok(new AuthResponseDto
    {
        Token = token,
        RefreshToken = refreshToken,
        UserId = user.Id,
        Email = user.Email,
        ExpiresAt = DateTime.UtcNow.AddHours(1)
    });
}
```

**Improvements**:
- JWT tokens instead of cookies (better for SPAs and APIs)
- Refresh token mechanism
- Stateless authentication
- Works across domains

---

## 7. Frontend: View to React Component

### Old (Razor View with AngularJS)

```cshtml
@{
    ViewBag.Title = "stkana";
}

<script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>

<div ng-app="myApp" ng-controller="get_details">
    <p>Select from Stock</p>
    <select ng-model="selectedstk" 
            ng-options="x for x in stks" 
            ng-change="getdetails(1,selectedstk)">
    </select>
    
    <table class="table table-bordered">
        <thead>
            <tr>
                <th>日期</th>
                <th>分析員</th>
                <th>股票號碼</th>
            </tr>
        </thead>
        <tbody>
            <tr ng-repeat="x in details">
                <td>{{x.datetme}}</td>
                <td>{{x.name}}</td>
                <td>{{x.stk}}</td>
            </tr>
        </tbody>
    </table>
</div>

<script>
    var app = angular.module('myApp', []);
    app.controller('get_details', function ($scope, $http) {
        $http.get("/Home/initial_load_Rec")
            .then(function (response) {
                $scope.stks = response.data;
            });

        $scope.getdetails = function (typ, arg) {
            var url = "/Home/load_recommend/?typ=" + typ + "&arg=" + arg;
            $http.get(url).then(function (response) {
                $scope.details = response.data;
            });
        }
    });
</script>
```

### New (React Component with TypeScript)

```typescript
// types.ts
interface Stock {
  code: string;
  name: string;
}

interface Recommendation {
  date: string;
  analystName: string;
  stockCode: string;
  stockName: string;
  recommendation: string;
}

// StockAnalysis.tsx
import { useState, useEffect } from 'react';
import {
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow,
  FormControl, InputLabel, Select, MenuItem, Paper, Typography
} from '@mui/material';
import { useQuery } from '@tanstack/react-query';
import { stockApi } from '../api/stockApi';

export const StockAnalysis = () => {
  const [selectedStock, setSelectedStock] = useState<string>('');

  // Fetch stocks
  const { data: stocks = [] } = useQuery({
    queryKey: ['stocks'],
    queryFn: () => stockApi.getStocks()
  });

  // Fetch recommendations
  const { data: recommendations = [], isLoading } = useQuery({
    queryKey: ['recommendations', selectedStock],
    queryFn: () => stockApi.getRecommendations(selectedStock),
    enabled: !!selectedStock
  });

  return (
    <div>
      <Typography variant="h5" gutterBottom>
        Stock Analysis
      </Typography>

      <FormControl fullWidth sx={{ mb: 3 }}>
        <InputLabel>Select Stock</InputLabel>
        <Select
          value={selectedStock}
          onChange={(e) => setSelectedStock(e.target.value)}
          label="Select Stock"
        >
          {stocks.map((stock) => (
            <MenuItem key={stock.code} value={stock.code}>
              {stock.name}
            </MenuItem>
          ))}
        </Select>
      </FormControl>

      <TableContainer component={Paper}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell>Date</TableCell>
              <TableCell>Analyst</TableCell>
              <TableCell>Stock Code</TableCell>
              <TableCell>Recommendation</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {isLoading ? (
              <TableRow>
                <TableCell colSpan={4} align="center">
                  Loading...
                </TableCell>
              </TableRow>
            ) : recommendations.length === 0 ? (
              <TableRow>
                <TableCell colSpan={4} align="center">
                  No data available
                </TableCell>
              </TableRow>
            ) : (
              recommendations.map((rec, index) => (
                <TableRow key={index}>
                  <TableCell>{rec.date}</TableCell>
                  <TableCell>{rec.analystName}</TableCell>
                  <TableCell>{rec.stockCode}</TableCell>
                  <TableCell>{rec.recommendation}</TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </div>
  );
};

// api/stockApi.ts
import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';

export const stockApi = {
  getStocks: async (): Promise<Stock[]> => {
    const response = await axios.get(`${API_BASE_URL}/stocks`);
    return response.data;
  },

  getRecommendations: async (stockCode: string): Promise<Recommendation[]> => {
    const response = await axios.get(
      `${API_BASE_URL}/analysis/stocks/${stockCode}/recommendations`
    );
    return response.data;
  }
};
```

**Improvements**:
- Type safety with TypeScript
- Modern React hooks
- Separation of concerns (API layer, types, components)
- Loading states
- Empty states
- Material-UI for professional design
- React Query for caching and automatic refetching
- Environment variables for configuration

---

## 8. Data Validation

### Old (Data Annotations)

```csharp
public class txModel
{
    [Required(ErrorMessage = "Number of Shares cannot be blank")]
    public int shares { get; set; }

    [Required(ErrorMessage = "Price cannot be blank")]
    [Range(0, 100000, ErrorMessage = "Price must be greater than 0")]
    public decimal price { get; set; }
}

// Controller
[HttpPost]
[ValidateAntiForgeryToken]
public ActionResult CreateTransaction(txModel transaction)
{
    if (ModelState.IsValid)
    {
        db.txModels.Add(transaction);
        db.SaveChanges();
        return RedirectToAction("Portfolio");
    }
    return View(transaction);
}
```

### New (FluentValidation + Zod)

**Backend (FluentValidation)**:

```csharp
public class CreateTransactionDto
{
    public Guid StockId { get; set; }
    public string Type { get; set; } = string.Empty;
    public int Shares { get; set; }
    public decimal Price { get; set; }
    public DateTime Date { get; set; }
}

public class CreateTransactionValidator : AbstractValidator<CreateTransactionDto>
{
    public CreateTransactionValidator()
    {
        RuleFor(x => x.StockId)
            .NotEmpty()
            .WithMessage("Stock is required");

        RuleFor(x => x.Type)
            .NotEmpty()
            .Must(t => t == "buy" || t == "sell")
            .WithMessage("Type must be 'buy' or 'sell'");

        RuleFor(x => x.Shares)
            .GreaterThan(0)
            .WithMessage("Shares must be greater than 0");

        RuleFor(x => x.Price)
            .GreaterThan(0)
            .LessThanOrEqualTo(1000000)
            .WithMessage("Price must be between 0 and 1,000,000");

        RuleFor(x => x.Date)
            .LessThanOrEqualTo(DateTime.Today)
            .WithMessage("Date cannot be in the future");
    }
}

// Controller
[HttpPost]
public async Task<ActionResult> CreateTransaction(
    [FromBody] CreateTransactionDto dto)
{
    // FluentValidation runs automatically if configured
    // No need to check ModelState manually in simple cases
    
    var transaction = await _transactionService.CreateAsync(dto);
    return CreatedAtAction(nameof(GetTransaction), 
        new { id = transaction.Id }, transaction);
}
```

**Frontend (Zod + React Hook Form)**:

```typescript
import { z } from 'zod';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';

const transactionSchema = z.object({
  stockId: z.string().uuid('Invalid stock selected'),
  type: z.enum(['buy', 'sell']),
  shares: z.number().int().positive('Shares must be greater than 0'),
  price: z.number().positive().max(1000000, 'Price too high'),
  date: z.date().max(new Date(), 'Date cannot be in the future')
});

type TransactionFormData = z.infer<typeof transactionSchema>;

export const TransactionForm = () => {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting }
  } = useForm<TransactionFormData>({
    resolver: zodResolver(transactionSchema)
  });

  const onSubmit = async (data: TransactionFormData) => {
    try {
      await transactionApi.create(data);
      // Show success message
    } catch (error) {
      // Handle error
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <TextField
        label="Shares"
        type="number"
        {...register('shares', { valueAsNumber: true })}
        error={!!errors.shares}
        helperText={errors.shares?.message}
      />

      <TextField
        label="Price"
        type="number"
        {...register('price', { valueAsNumber: true })}
        error={!!errors.price}
        helperText={errors.price?.message}
      />

      <Button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Creating...' : 'Create Transaction'}
      </Button>
    </form>
  );
};
```

**Improvements**:
- More powerful validation rules
- Client and server validation with same logic
- Type-safe
- Better error messages
- Composable validators

---

## 9. Dependency Injection

### Old (Manual instantiation)

```csharp
public class HomeController : Controller
{
    private ApplicationDbContext db = ApplicationDbContext.Create();
    
    public ActionResult Index()
    {
        var service = new StockService(db);
        var data = service.GetStocks();
        return View(data);
    }
    
    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            db.Dispose();
        }
        base.Dispose(disposing);
    }
}
```

### New (Constructor injection)

```csharp
public class PortfoliosController : ControllerBase
{
    private readonly IPortfolioService _portfolioService;
    private readonly IStockDataService _stockDataService;
    private readonly ILogger<PortfoliosController> _logger;

    public PortfoliosController(
        IPortfolioService portfolioService,
        IStockDataService stockDataService,
        ILogger<PortfoliosController> logger)
    {
        _portfolioService = portfolioService;
        _stockDataService = stockDataService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<PortfolioDto>>> Get()
    {
        var portfolios = await _portfolioService.GetAllAsync();
        return Ok(portfolios);
    }
    
    // No need for Dispose - handled by DI container
}

// Service registration in Program.cs
builder.Services.AddScoped<IPortfolioService, PortfolioService>();
builder.Services.AddScoped<IStockDataService, StockDataService>();
builder.Services.AddDbContext<ApplicationDbContext>(options => 
    options.UseSqlServer(connectionString));
```

**Improvements**:
- Automatic disposal
- Easier to test (can inject mocks)
- Clearer dependencies
- Lifetime management (Singleton, Scoped, Transient)

---

## 10. Background Jobs

### Old (Manual implementation or Windows Service)

```csharp
// Manual background task in Global.asax
public class MvcApplication : System.Web.HttpApplication
{
    private static Timer _timer;

    protected void Application_Start()
    {
        // ... other startup code
        
        _timer = new Timer(UpdateStockPrices, null, 
            TimeSpan.Zero, TimeSpan.FromMinutes(15));
    }

    private static void UpdateStockPrices(object state)
    {
        try
        {
            using (var db = ApplicationDbContext.Create())
            {
                var service = new StockService(db);
                service.UpdateAllPrices();
            }
        }
        catch (Exception ex)
        {
            // Log error
        }
    }
}
```

### New (Hangfire)

```csharp
// Program.cs
builder.Services.AddHangfire(config => config
    .SetDataCompatibilityLevel(CompatibilityLevel.Version_180)
    .UseSimpleAssemblyNameTypeSerializer()
    .UseRecommendedSerializerSettings()
    .UseSqlServerStorage(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddHangfireServer();

var app = builder.Build();

app.UseHangfireDashboard();

// Schedule recurring jobs
RecurringJob.AddOrUpdate<IStockDataService>(
    "update-stock-prices",
    service => service.UpdateAllPricesAsync(),
    Cron.Every15Minutes);

// Background job service
public interface IStockDataService
{
    Task UpdateAllPricesAsync();
}

public class StockDataService : IStockDataService
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<StockDataService> _logger;

    public StockDataService(
        ApplicationDbContext context,
        ILogger<StockDataService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task UpdateAllPricesAsync()
    {
        _logger.LogInformation("Starting stock price update");
        
        var stocks = await _context.Stocks.ToListAsync();
        
        foreach (var stock in stocks)
        {
            try
            {
                var price = await FetchLatestPrice(stock.Symbol);
                stock.LastPrice = price;
                stock.LastUpdated = DateTime.UtcNow;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating price for {Symbol}", 
                    stock.Symbol);
            }
        }
        
        await _context.SaveChangesAsync();
        
        _logger.LogInformation("Stock price update completed");
    }
}
```

**Improvements**:
- Built-in dashboard
- Retry logic
- Job persistence
- Distributed execution
- Monitoring and logging

---

## Summary

These examples show the dramatic improvements in:

1. **Code clarity**: Less boilerplate, clearer intent
2. **Performance**: Async/await, better resource management
3. **Testability**: Dependency injection, separation of concerns
4. **Type safety**: TypeScript on frontend, nullable reference types on backend
5. **Developer experience**: Hot reload, better tooling, modern frameworks
6. **Maintainability**: Smaller files, clear structure, modern patterns

The modernization effort pays dividends in productivity, performance, and maintainability.
