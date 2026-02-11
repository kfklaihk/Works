# Quick Start Implementation Guide

This guide will help you get a working modern version of the stock portfolio application running in under 2 hours.

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] .NET 8 SDK installed ([download](https://dotnet.microsoft.com/download/dotnet/8.0))
- [ ] Node.js 20+ LTS installed ([download](https://nodejs.org/))
- [ ] Git installed
- [ ] Visual Studio Code or Visual Studio 2022
- [ ] SQL Server or PostgreSQL (or use LocalDB/SQLite for development)
- [ ] Postman or similar API testing tool (optional)

### Verify Installation

```bash
dotnet --version   # Should show 8.x.x
node --version     # Should show 20.x.x
npm --version      # Should show 10.x.x
git --version      # Any recent version
```

---

## Phase 1: Backend Setup (30 minutes)

### Step 1: Create Project Structure (5 min)

```bash
# Create root directory
mkdir ModernStockPortfolio
cd ModernStockPortfolio

# Create solution
dotnet new sln -n ModernStockPortfolio

# Create projects
mkdir src tests
cd src

dotnet new webapi -n ModernStockPortfolio.Api -f net8.0
dotnet new classlib -n ModernStockPortfolio.Core -f net8.0
dotnet new classlib -n ModernStockPortfolio.Infrastructure -f net8.0

cd ../tests
dotnet new xunit -n ModernStockPortfolio.Tests -f net8.0

cd ..

# Add projects to solution
dotnet sln add src/ModernStockPortfolio.Api
dotnet sln add src/ModernStockPortfolio.Core
dotnet sln add src/ModernStockPortfolio.Infrastructure
dotnet sln add tests/ModernStockPortfolio.Tests

# Add project references
cd src/ModernStockPortfolio.Api
dotnet add reference ../ModernStockPortfolio.Infrastructure
dotnet add reference ../ModernStockPortfolio.Core

cd ../ModernStockPortfolio.Infrastructure
dotnet add reference ../ModernStockPortfolio.Core

cd ../../tests/ModernStockPortfolio.Tests
dotnet add reference ../../src/ModernStockPortfolio.Api
dotnet add reference ../../src/ModernStockPortfolio.Core

cd ../..
```

### Step 2: Install NuGet Packages (5 min)

```bash
cd src/ModernStockPortfolio.Api

# Core packages
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
dotnet add package Microsoft.EntityFrameworkCore.Design
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore

# Utilities
dotnet add package Swashbuckle.AspNetCore
dotnet add package AutoMapper.Extensions.Microsoft.DependencyInjection
dotnet add package FluentValidation.AspNetCore
dotnet add package Serilog.AspNetCore
dotnet add package Serilog.Sinks.Console

# For web scraping (keep from old project)
cd ../ModernStockPortfolio.Infrastructure
dotnet add package HtmlAgilityPack

cd ../..
```

### Step 3: Create Domain Models (10 min)

Create `src/ModernStockPortfolio.Core/Entities/Portfolio.cs`:

```csharp
namespace ModernStockPortfolio.Core.Entities;

public class Portfolio
{
    public Guid Id { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    
    public ICollection<Holding> Holdings { get; set; } = new List<Holding>();
    public ICollection<Transaction> Transactions { get; set; } = new List<Transaction>();
}

public class Holding
{
    public Guid Id { get; set; }
    public Guid PortfolioId { get; set; }
    public string Symbol { get; set; } = string.Empty;
    public int Shares { get; set; }
    public decimal AverageCost { get; set; }
    public DateTime LastUpdated { get; set; }
    
    public Portfolio Portfolio { get; set; } = null!;
}

public class Transaction
{
    public Guid Id { get; set; }
    public Guid PortfolioId { get; set; }
    public string Symbol { get; set; } = string.Empty;
    public TransactionType Type { get; set; }
    public int Shares { get; set; }
    public decimal Price { get; set; }
    public DateTime Date { get; set; }
    public DateTime CreatedAt { get; set; }
    
    public Portfolio Portfolio { get; set; } = null!;
}

public enum TransactionType
{
    Buy,
    Sell
}

public class Stock
{
    public Guid Id { get; set; }
    public string Symbol { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Market { get; set; } = string.Empty;
    public decimal LastPrice { get; set; }
    public DateTime LastUpdated { get; set; }
}
```

### Step 4: Create DbContext (5 min)

Create `src/ModernStockPortfolio.Infrastructure/Data/ApplicationDbContext.cs`:

```csharp
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using ModernStockPortfolio.Core.Entities;

namespace ModernStockPortfolio.Infrastructure.Data;

public class ApplicationDbContext : IdentityDbContext<ApplicationUser>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<Portfolio> Portfolios => Set<Portfolio>();
    public DbSet<Holding> Holdings => Set<Holding>();
    public DbSet<Transaction> Transactions => Set<Transaction>();
    public DbSet<Stock> Stocks => Set<Stock>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<Portfolio>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(100);
            entity.HasIndex(e => e.UserId);
            
            entity.HasMany(e => e.Holdings)
                  .WithOne(h => h.Portfolio)
                  .HasForeignKey(h => h.PortfolioId)
                  .OnDelete(DeleteBehavior.Cascade);
                  
            entity.HasMany(e => e.Transactions)
                  .WithOne(t => t.Portfolio)
                  .HasForeignKey(t => t.PortfolioId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<Stock>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Symbol).IsUnique();
            entity.Property(e => e.LastPrice).HasPrecision(18, 2);
        });

        builder.Entity<Transaction>(entity =>
        {
            entity.Property(e => e.Price).HasPrecision(18, 2);
        });
    }
}

public class ApplicationUser : Microsoft.AspNetCore.Identity.IdentityUser
{
    public string? RefreshToken { get; set; }
    public DateTime? RefreshTokenExpiry { get; set; }
}
```

### Step 5: Configure Program.cs (5 min)

Replace `src/ModernStockPortfolio.Api/Program.cs`:

```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using ModernStockPortfolio.Infrastructure.Data;
using Serilog;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Serilog
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .CreateLogger();

builder.Host.UseSerilog();

// Database
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        b => b.MigrationsAssembly("ModernStockPortfolio.Infrastructure")));

// Identity
builder.Services.AddIdentity<ApplicationUser, IdentityRole>(options =>
{
    options.Password.RequireDigit = true;
    options.Password.RequiredLength = 8;
    options.User.RequireUniqueEmail = true;
})
.AddEntityFrameworkStores<ApplicationDbContext>()
.AddDefaultTokenProviders();

// JWT Authentication
var jwtSecret = builder.Configuration["JwtSettings:Secret"] 
    ?? throw new InvalidOperationException("JWT Secret not configured");

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
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
            Encoding.UTF8.GetBytes(jwtSecret))
    };
});

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

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

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

Create `src/ModernStockPortfolio.Api/appsettings.Development.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=ModernStockPortfolio;Trusted_Connection=True;MultipleActiveResultSets=true"
  },
  "JwtSettings": {
    "Secret": "your-super-secret-key-min-32-chars-long-12345",
    "Issuer": "ModernStockPortfolio",
    "Audience": "ModernStockPortfolio",
    "ExpiryMinutes": 60
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

### Step 6: Create Initial Migration

```bash
cd src/ModernStockPortfolio.Infrastructure

dotnet ef migrations add InitialCreate \
    --startup-project ../ModernStockPortfolio.Api \
    --context ApplicationDbContext

dotnet ef database update \
    --startup-project ../ModernStockPortfolio.Api

cd ../..
```

### Step 7: Create Sample Controllers (Optional)

Create `src/ModernStockPortfolio.Api/Controllers/PortfoliosController.cs`:

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ModernStockPortfolio.Core.Entities;
using ModernStockPortfolio.Infrastructure.Data;
using System.Security.Claims;

namespace ModernStockPortfolio.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PortfoliosController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<PortfoliosController> _logger;

    public PortfoliosController(
        ApplicationDbContext context,
        ILogger<PortfoliosController> logger)
    {
        _context = context;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Portfolio>>> GetPortfolios()
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userId))
            return Unauthorized();

        var portfolios = await _context.Portfolios
            .Where(p => p.UserId == userId)
            .Include(p => p.Holdings)
            .ToListAsync();

        return Ok(portfolios);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Portfolio>> GetPortfolio(Guid id)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userId))
            return Unauthorized();

        var portfolio = await _context.Portfolios
            .Include(p => p.Holdings)
            .Include(p => p.Transactions)
            .FirstOrDefaultAsync(p => p.Id == id && p.UserId == userId);

        if (portfolio == null)
            return NotFound();

        return Ok(portfolio);
    }

    [HttpPost]
    public async Task<ActionResult<Portfolio>> CreatePortfolio([FromBody] CreatePortfolioDto dto)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userId))
            return Unauthorized();

        var portfolio = new Portfolio
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = dto.Name,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.Portfolios.Add(portfolio);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetPortfolio), new { id = portfolio.Id }, portfolio);
    }
}

public record CreatePortfolioDto(string Name);
```

### Step 8: Test Backend

```bash
cd src/ModernStockPortfolio.Api
dotnet run
```

Visit: `https://localhost:7xxx/swagger`

You should see the Swagger UI with your API endpoints!

---

## Phase 2: Frontend Setup (30 minutes)

### Step 1: Create React App (5 min)

```bash
# From project root
cd src
npm create vite@latest ModernStockPortfolio.Client -- --template react-ts
cd ModernStockPortfolio.Client
npm install
```

### Step 2: Install Dependencies (5 min)

```bash
# UI Framework
npm install @mui/material @emotion/react @emotion/styled @mui/icons-material

# Routing
npm install react-router-dom

# State Management
npm install zustand

# API & Data Fetching
npm install axios @tanstack/react-query

# Forms
npm install react-hook-form @hookform/resolvers zod

# Charts
npm install recharts

# Utilities
npm install date-fns clsx

# Dev Dependencies
npm install -D @types/node
```

### Step 3: Configure Vite (2 min)

Update `vite.config.ts`:

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'https://localhost:7xxx', // Your API port
        changeOrigin: true,
        secure: false,
      },
    },
  },
});
```

### Step 4: Create API Client (5 min)

Create `src/api/client.ts`:

```typescript
import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://localhost:7xxx/api';

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add auth token to requests
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Handle auth errors
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);
```

Create `src/api/portfolioApi.ts`:

```typescript
import { apiClient } from './client';

export interface Portfolio {
  id: string;
  name: string;
  userId: string;
  createdAt: string;
  updatedAt: string;
  holdings: Holding[];
}

export interface Holding {
  id: string;
  symbol: string;
  shares: number;
  averageCost: number;
}

export const portfolioApi = {
  getAll: async (): Promise<Portfolio[]> => {
    const response = await apiClient.get('/portfolios');
    return response.data;
  },

  getById: async (id: string): Promise<Portfolio> => {
    const response = await apiClient.get(`/portfolios/${id}`);
    return response.data;
  },

  create: async (name: string): Promise<Portfolio> => {
    const response = await apiClient.post('/portfolios', { name });
    return response.data;
  },
};
```

### Step 5: Create Auth Store (5 min)

Create `src/stores/authStore.ts`:

```typescript
import { create } from 'zustand';

interface User {
  id: string;
  email: string;
}

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: localStorage.getItem('token'),
  isAuthenticated: !!localStorage.getItem('token'),

  login: async (email: string, password: string) => {
    // TODO: Call API
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });

    if (!response.ok) throw new Error('Login failed');

    const data = await response.json();
    localStorage.setItem('token', data.token);
    set({ user: data.user, token: data.token, isAuthenticated: true });
  },

  logout: () => {
    localStorage.removeItem('token');
    set({ user: null, token: null, isAuthenticated: false });
  },
}));
```

### Step 6: Create Simple UI (8 min)

Update `src/App.tsx`:

```typescript
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ThemeProvider, createTheme, CssBaseline } from '@mui/material';
import { Dashboard } from './pages/Dashboard';
import { Login } from './pages/Login';
import { useAuthStore } from './stores/authStore';

const queryClient = new QueryClient();

const theme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#1976d2',
    },
  },
});

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  return isAuthenticated ? <>{children}</> : <Navigate to="/login" />;
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route
              path="/"
              element={
                <PrivateRoute>
                  <Dashboard />
                </PrivateRoute>
              }
            />
          </Routes>
        </BrowserRouter>
      </ThemeProvider>
    </QueryClientProvider>
  );
}

export default App;
```

Create `src/pages/Dashboard.tsx`:

```typescript
import { Container, Typography, Card, CardContent, Button } from '@mui/material';
import { useQuery } from '@tanstack/react-query';
import { portfolioApi } from '../api/portfolioApi';
import { useAuthStore } from '../stores/authStore';

export const Dashboard = () => {
  const logout = useAuthStore((state) => state.logout);

  const { data: portfolios, isLoading } = useQuery({
    queryKey: ['portfolios'],
    queryFn: portfolioApi.getAll,
  });

  return (
    <Container maxWidth="lg" sx={{ mt: 4 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 20 }}>
        <Typography variant="h3">Stock Portfolio</Typography>
        <Button variant="outlined" onClick={logout}>
          Logout
        </Button>
      </div>

      {isLoading ? (
        <Typography>Loading...</Typography>
      ) : (
        <div>
          <Typography variant="h5" gutterBottom>
            Your Portfolios ({portfolios?.length || 0})
          </Typography>
          {portfolios?.map((portfolio) => (
            <Card key={portfolio.id} sx={{ mb: 2 }}>
              <CardContent>
                <Typography variant="h6">{portfolio.name}</Typography>
                <Typography color="text.secondary">
                  {portfolio.holdings.length} holdings
                </Typography>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </Container>
  );
};
```

Create `src/pages/Login.tsx`:

```typescript
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Container, TextField, Button, Typography, Card, CardContent } from '@mui/material';
import { useAuthStore } from '../stores/authStore';

export const Login = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const login = useAuthStore((state) => state.login);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await login(email, password);
      navigate('/');
    } catch (error) {
      alert('Login failed');
    }
  };

  return (
    <Container maxWidth="sm" sx={{ mt: 8 }}>
      <Card>
        <CardContent>
          <Typography variant="h4" gutterBottom align="center">
            Stock Portfolio Login
          </Typography>
          <form onSubmit={handleSubmit}>
            <TextField
              fullWidth
              label="Email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              margin="normal"
              required
            />
            <TextField
              fullWidth
              label="Password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              margin="normal"
              required
            />
            <Button
              fullWidth
              variant="contained"
              type="submit"
              sx={{ mt: 2 }}
              size="large"
            >
              Login
            </Button>
          </form>
        </CardContent>
      </Card>
    </Container>
  );
};
```

### Step 7: Run Frontend

```bash
npm run dev
```

Visit: `http://localhost:5173`

---

## Phase 3: Connect Everything (15 minutes)

### Step 1: Create Auth Controller

Create `src/ModernStockPortfolio.Api/Controllers/AuthController.cs`:

```csharp
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using ModernStockPortfolio.Infrastructure.Data;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace ModernStockPortfolio.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly IConfiguration _configuration;

    public AuthController(
        UserManager<ApplicationUser> userManager,
        SignInManager<ApplicationUser> signInManager,
        IConfiguration configuration)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _configuration = configuration;
    }

    [HttpPost("register")]
    public async Task<ActionResult> Register([FromBody] RegisterDto dto)
    {
        var user = new ApplicationUser
        {
            UserName = dto.Email,
            Email = dto.Email
        };

        var result = await _userManager.CreateAsync(user, dto.Password);

        if (!result.Succeeded)
            return BadRequest(result.Errors);

        return Ok(new { message = "Registration successful" });
    }

    [HttpPost("login")]
    public async Task<ActionResult> Login([FromBody] LoginDto dto)
    {
        var user = await _userManager.FindByEmailAsync(dto.Email);
        if (user == null)
            return Unauthorized(new { message = "Invalid credentials" });

        var result = await _signInManager.CheckPasswordSignInAsync(
            user, dto.Password, lockoutOnFailure: false);

        if (!result.Succeeded)
            return Unauthorized(new { message = "Invalid credentials" });

        var token = GenerateJwtToken(user);

        return Ok(new
        {
            token,
            user = new
            {
                id = user.Id,
                email = user.Email
            }
        });
    }

    private string GenerateJwtToken(ApplicationUser user)
    {
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id),
            new Claim(ClaimTypes.Email, user.Email!),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var key = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(_configuration["JwtSettings:Secret"]!));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _configuration["JwtSettings:Issuer"],
            audience: _configuration["JwtSettings:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddHours(1),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}

public record RegisterDto(string Email, string Password);
public record LoginDto(string Email, string Password);
```

### Step 2: Update Frontend Auth Store

Update `src/stores/authStore.ts`:

```typescript
import { create } from 'zustand';
import axios from 'axios';

const API_URL = 'https://localhost:7xxx/api'; // Update with your port

interface User {
  id: string;
  email: string;
}

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: JSON.parse(localStorage.getItem('user') || 'null'),
  token: localStorage.getItem('token'),
  isAuthenticated: !!localStorage.getItem('token'),

  login: async (email: string, password: string) => {
    const response = await axios.post(`${API_URL}/auth/login`, {
      email,
      password,
    });

    const { token, user } = response.data;
    
    localStorage.setItem('token', token);
    localStorage.setItem('user', JSON.stringify(user));
    
    set({ user, token, isAuthenticated: true });
  },

  logout: () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    set({ user: null, token: null, isAuthenticated: false });
  },
}));
```

### Step 3: Test End-to-End

1. **Start Backend**:
   ```bash
   cd src/ModernStockPortfolio.Api
   dotnet run
   ```

2. **Start Frontend** (in new terminal):
   ```bash
   cd src/ModernStockPortfolio.Client
   npm run dev
   ```

3. **Test Flow**:
   - Visit `http://localhost:5173`
   - Register a new user via Swagger or create test user
   - Login with credentials
   - See dashboard with portfolios

---

## Common Issues & Solutions

### Issue: CORS Error

**Solution**: Ensure backend `Program.cs` has correct frontend URL in CORS policy.

### Issue: Database Connection Failed

**Solution**: Check connection string in `appsettings.json`. Try using SQLite for quick start:

```bash
dotnet add package Microsoft.EntityFrameworkCore.Sqlite
```

Change connection string to:
```json
"DefaultConnection": "Data Source=stockportfolio.db"
```

And in `Program.cs`:
```csharp
options.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection"))
```

### Issue: Port Conflicts

**Solution**: Change ports in `vite.config.ts` and `launchSettings.json`.

---

## Next Steps

Now that you have a working skeleton:

1. **Add more API endpoints** (transactions, stocks, analytics)
2. **Implement proper validation** with FluentValidation
3. **Add more UI pages** (portfolio details, charts)
4. **Set up proper error handling**
5. **Add tests**
6. **Configure logging properly**
7. **Add background jobs** for stock price updates
8. **Implement caching**
9. **Add charts** with Recharts
10. **Deploy to Azure/AWS**

---

## Useful Commands

### Backend

```bash
# Run migrations
dotnet ef migrations add <MigrationName> --startup-project ../ModernStockPortfolio.Api

# Update database
dotnet ef database update --startup-project ../ModernStockPortfolio.Api

# Run tests
dotnet test

# Build
dotnet build

# Publish
dotnet publish -c Release
```

### Frontend

```bash
# Development
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Lint
npm run lint
```

---

## Resources

- [.NET Documentation](https://learn.microsoft.com/dotnet/)
- [React Documentation](https://react.dev/)
- [Material-UI](https://mui.com/)
- [Entity Framework Core](https://learn.microsoft.com/ef/core/)
- [ASP.NET Core Identity](https://learn.microsoft.com/aspnet/core/security/authentication/identity)

---

**Congratulations!** You now have a modern, working stock portfolio application with:

✅ .NET 8 backend with JWT authentication  
✅ React 18 frontend with TypeScript  
✅ Material-UI for professional design  
✅ Entity Framework Core for database  
✅ Clean architecture foundation  
✅ Ready for feature development  

Start building features and iterate from here!
