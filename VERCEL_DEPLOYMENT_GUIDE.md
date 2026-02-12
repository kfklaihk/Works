# Vercel Deployment Guide - Complete Step-by-Step

This guide provides detailed instructions to deploy your stock portfolio application to Vercel.

---

## Prerequisites Checklist

Before starting, ensure you have:

- [x] Supabase project created and database schema set up
- [x] DeepSeek API key
- [x] Marketstack API key: `4b07745ad79b66dfd320697e5e40f596`
- [x] GitHub account
- [x] The application code (from modernize_legacy repository)

---

## Method 1: Deploy via Vercel Website (Easiest - 10 minutes)

### Step 1: Push Code to GitHub (5 minutes)

First, make sure your code is in a GitHub repository:

```bash
# If you already pushed to modernize_legacy, skip to Step 2
# Otherwise:

cd modernize_legacy
git remote add origin https://github.com/YOUR_USERNAME/modernize_legacy.git
git branch -M main
git push -u origin main
```

### Step 2: Sign Up for Vercel (2 minutes)

1. Go to: **https://vercel.com**
2. Click **"Sign Up"**
3. Choose **"Continue with GitHub"**
4. Authorize Vercel to access your GitHub account
5. You'll be redirected to Vercel dashboard

### Step 3: Import Your Repository (3 minutes)

1. Click **"Add New..."** → **"Project"**
2. You'll see "Import Git Repository"
3. Find `modernize_legacy` in the list
4. Click **"Import"**

**If you don't see your repository:**
- Click "Adjust GitHub App Permissions"
- Grant access to the repository
- Refresh the page

### Step 4: Configure Build Settings

Vercel should auto-detect it's a Vite project:

**Framework Preset:** `Vite`

**Root Directory:** `code`
- ⚠️ **IMPORTANT**: Click "Edit" next to Root Directory
- Enter: `code`
- This is because our React app is in the `code/` subfolder

**Build Command:** `npm run build` (auto-detected)

**Output Directory:** `dist` (auto-detected)

**Install Command:** `npm install` (auto-detected)

### Step 5: Add Environment Variables

Click **"Environment Variables"** section and add these:

| Name | Value | Notes |
|------|-------|-------|
| `VITE_SUPABASE_URL` | `https://xxxxx.supabase.co` | From Supabase project settings |
| `VITE_SUPABASE_ANON_KEY` | `eyJhbGci...` | From Supabase project settings → API |
| `VITE_MARKETSTACK_API_KEY` | `4b07745ad79b66dfd320697e5e40f596` | Already provided |
| `VITE_DEEPSEEK_API_KEY` | `sk-...` | From DeepSeek platform |

**How to get Supabase credentials:**
1. Go to your Supabase project
2. Click **Settings** (⚙️) → **API**
3. Copy **Project URL** (for `VITE_SUPABASE_URL`)
4. Copy **anon public** key (for `VITE_SUPABASE_ANON_KEY`)

**How to get DeepSeek API key:**
1. Go to https://platform.deepseek.com
2. Sign up / Log in
3. Go to **API Keys**
4. Click **"Create New Key"**
5. Copy the key

### Step 6: Deploy

1. Click **"Deploy"** button
2. Wait 2-3 minutes for build to complete
3. You'll see build logs in real-time

**Expected build process:**
```
Installing dependencies...
Building application...
Collecting page data...
Generating static pages...
Finalizing build...
✓ Build completed successfully
```

### Step 7: Visit Your Live Site

Once deployment succeeds:
1. Vercel shows your deployment URL
2. Click **"Visit"** or copy the URL
3. It will be something like: `https://modernize-legacy-xxx.vercel.app`

**Test your deployment:**
- ✅ Can you see the login page?
- ✅ Can you sign up/login?
- ✅ Can you see the portfolio page?

---

## Method 2: Deploy via Vercel CLI (Advanced - 15 minutes)

### Step 1: Install Vercel CLI

```bash
npm install -g vercel
```

### Step 2: Login to Vercel

```bash
vercel login
```

Choose your authentication method (Email or GitHub).

### Step 3: Navigate to Your Project

```bash
cd modernize_legacy/code
```

### Step 4: Deploy

```bash
vercel
```

**You'll be asked:**

**Question 1:** "Set up and deploy?"
```
Answer: Y (Yes)
```

**Question 2:** "Which scope?"
```
Answer: Select your account
```

**Question 3:** "Link to existing project?"
```
Answer: N (No - first deployment)
```

**Question 4:** "What's your project's name?"
```
Answer: modernize-legacy (or your preferred name)
```

**Question 5:** "In which directory is your code located?"
```
Answer: ./ (current directory)
```

**Question 6:** "Want to override settings?"
```
Answer: N (No)
```

### Step 5: Add Environment Variables

After first deployment, add environment variables:

```bash
vercel env add VITE_SUPABASE_URL
# Paste your Supabase URL when prompted

vercel env add VITE_SUPABASE_ANON_KEY
# Paste your Supabase anon key

vercel env add VITE_MARKETSTACK_API_KEY
# Paste: 4b07745ad79b66dfd320697e5e40f596

vercel env add VITE_DEEPSEEK_API_KEY
# Paste your DeepSeek API key
```

For each variable, select:
- Environment: **Production**, **Preview**, **Development** (all three)

### Step 6: Redeploy with Environment Variables

```bash
vercel --prod
```

This redeploys with all environment variables.

### Step 7: Visit Your Site

Vercel will output your deployment URL:
```
✅ Production: https://modernize-legacy.vercel.app
```

---

## Method 3: Deploy from GitHub (Continuous Deployment)

This method auto-deploys whenever you push to GitHub.

### Step 1: Connect Repository to Vercel

1. Go to Vercel dashboard: https://vercel.com/dashboard
2. Click **"Add New..."** → **"Project"**
3. Import your GitHub repository: `modernize_legacy`
4. Configure as described in Method 1

### Step 2: Enable Auto-Deployment

Vercel automatically enables this. Now:
- **Every push to `main`** → Production deployment
- **Every pull request** → Preview deployment

### Step 3: Make a Change to Test

```bash
# Edit a file
echo "// Updated" >> code/src/App.tsx

# Commit and push
git add .
git commit -m "test: Trigger deployment"
git push
```

Vercel will automatically deploy! 🎉

---

## Configuration Files

### Create vercel.json (Optional but Recommended)

Create `code/vercel.json`:

```json
{
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "devCommand": "npm run dev",
  "installCommand": "npm install",
  "framework": "vite",
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
```

This ensures:
- Single Page Application routing works correctly
- All routes redirect to index.html (React Router handles routing)

### Update vite.config.ts for Production

Update `code/vite.config.ts`:

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
  },
  build: {
    outDir: 'dist',
    sourcemap: false, // Disable sourcemaps for production
    rollupOptions: {
      output: {
        manualChunks: {
          'react-vendor': ['react', 'react-dom'],
          'mui-vendor': ['@mui/material', '@emotion/react', '@emotion/styled'],
          'query-vendor': ['@tanstack/react-query'],
        },
      },
    },
  },
});
```

---

## Environment Variables Setup

### Get Your Supabase Credentials

1. **Go to Supabase Dashboard:**
   - https://app.supabase.com

2. **Select your project**

3. **Go to Settings → API:**
   - Copy **Project URL**: `https://xxxxx.supabase.co`
   - Copy **Project API keys** → **anon public**: `eyJhbGci...`

### Get DeepSeek API Key

1. **Go to DeepSeek Platform:**
   - https://platform.deepseek.com

2. **Navigate to API Keys**

3. **Create New Key:**
   - Name it: "Stock Portfolio App"
   - Copy the key: `sk-...`

### Add to Vercel (Website Method)

1. **Go to your Vercel project dashboard**
2. Click **Settings**
3. Click **Environment Variables**
4. For each variable, click **"Add New"**:

   **Variable 1:**
   - Name: `VITE_SUPABASE_URL`
   - Value: `https://your-project.supabase.co`
   - Environments: ✅ Production, ✅ Preview, ✅ Development

   **Variable 2:**
   - Name: `VITE_SUPABASE_ANON_KEY`
   - Value: `eyJhbGci...` (your anon key)
   - Environments: ✅ Production, ✅ Preview, ✅ Development

   **Variable 3:**
   - Name: `VITE_MARKETSTACK_API_KEY`
   - Value: `4b07745ad79b66dfd320697e5e40f596`
   - Environments: ✅ Production, ✅ Preview, ✅ Development

   **Variable 4:**
   - Name: `VITE_DEEPSEEK_API_KEY`
   - Value: `sk-...` (your DeepSeek key)
   - Environments: ✅ Production, ✅ Preview, ✅ Development

5. Click **Save**

### Redeploy After Adding Variables

1. Go to **Deployments** tab
2. Find the latest deployment
3. Click **⋮** (three dots)
4. Click **"Redeploy"**
5. Check **"Use existing Build Cache"**
6. Click **"Redeploy"**

---

## Configure Supabase for Vercel Domain

### Add Vercel URL to Supabase

After deployment, you need to allow your Vercel domain in Supabase:

1. **Go to Supabase Dashboard**
2. **Authentication** → **URL Configuration**
3. **Add Site URL:**
   - Add your Vercel URL: `https://modernize-legacy-xxx.vercel.app`
4. **Add Redirect URLs:**
   - Add: `https://modernize-legacy-xxx.vercel.app/**`
   - Add: `http://localhost:5173/**` (for local dev)
5. Click **Save**

**Without this step, Google OAuth won't work in production!**

---

## Custom Domain (Optional)

### Step 1: Buy a Domain

Purchase a domain from:
- Namecheap
- Google Domains
- Cloudflare
- GoDaddy

Example: `stockportfolio.com`

### Step 2: Add Domain to Vercel

1. **In Vercel Dashboard**, go to your project
2. Click **Settings** → **Domains**
3. Enter your domain: `stockportfolio.com`
4. Click **Add**

### Step 3: Configure DNS

Vercel will show you DNS records to add:

**Option A: Using Nameservers (Easiest)**
1. Vercel provides nameservers
2. Update your domain's nameservers at your registrar
3. Wait for DNS propagation (2-48 hours)

**Option B: Using A/CNAME Records**
1. Add these DNS records at your registrar:

   **For root domain (stockportfolio.com):**
   ```
   Type: A
   Name: @
   Value: 76.76.21.21
   ```

   **For www subdomain:**
   ```
   Type: CNAME
   Name: www
   Value: cname.vercel-dns.com
   ```

2. Wait for DNS propagation (15-60 minutes)

### Step 4: Enable SSL (Automatic)

Vercel automatically provisions SSL certificates. Your site will be accessible via:
- `https://stockportfolio.com` ✅
- `https://www.stockportfolio.com` ✅

### Step 5: Update Supabase URLs

Add your custom domain to Supabase:
1. Supabase → Authentication → URL Configuration
2. Add: `https://stockportfolio.com`
3. Add: `https://stockportfolio.com/**`

---

## Troubleshooting

### Issue 1: Build Fails - "Cannot find module"

**Error:**
```
Error: Cannot find module '@mui/material'
```

**Solution:**
1. Check `package.json` has all dependencies
2. Ensure `Root Directory` is set to `code` in Vercel settings
3. Redeploy with cleared cache:
   - Deployments → ⋮ → Redeploy
   - Uncheck "Use existing Build Cache"

### Issue 2: Environment Variables Not Working

**Symptoms:**
- Login doesn't work
- "Missing Supabase environment variables" error
- Stock quotes fail

**Solution:**
1. **Verify variables are added:**
   - Settings → Environment Variables
   - All 4 variables should be there

2. **Check variable names:**
   - Must start with `VITE_`
   - Exact names: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, etc.

3. **Redeploy after adding variables:**
   - Deployments → Latest → ⋮ → Redeploy

### Issue 3: "404 Not Found" on Refresh

**Symptoms:**
- App works fine when navigating
- Page refresh shows 404 error

**Solution:**

Create `code/vercel.json`:
```json
{
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
```

Then redeploy:
```bash
git add code/vercel.json
git commit -m "fix: Add SPA routing support"
git push
```

### Issue 4: Google OAuth Not Working

**Symptoms:**
- Email login works
- Google login redirects but fails

**Solution:**

1. **Update Supabase Redirect URLs:**
   - Supabase → Authentication → URL Configuration
   - Site URL: `https://your-app.vercel.app`
   - Redirect URLs: `https://your-app.vercel.app/**`

2. **Check Google OAuth Settings:**
   - Google Cloud Console
   - Authorized redirect URIs should include:
     - `https://your-project.supabase.co/auth/v1/callback`
     - `https://your-app.vercel.app`

### Issue 5: Stock Quotes Not Loading

**Symptoms:**
- "Failed to fetch stock data" error

**Solution:**

1. **Check Marketstack API key:**
   - Verify: `VITE_MARKETSTACK_API_KEY=4b07745ad79b66dfd320697e5e40f596`

2. **Check API quota:**
   - Free tier: 100 calls/month
   - Go to https://marketstack.com/dashboard
   - Check remaining calls

3. **Check browser console:**
   - F12 → Console
   - Look for detailed error messages

### Issue 6: AI Chatbot Not Responding

**Symptoms:**
- Chat window opens
- Messages sent but no response

**Solution:**

1. **Check DeepSeek API key:**
   - Settings → Environment Variables
   - Verify `VITE_DEEPSEEK_API_KEY` is set

2. **Check API quota:**
   - Go to https://platform.deepseek.com
   - Check usage limits

3. **Check browser console:**
   - Look for 401 (auth error) or 429 (rate limit)

### Issue 7: CORS Errors

**Symptoms:**
- "CORS policy" errors in console

**Solution:**

This usually happens with Marketstack API. Add this to your code:

Create `code/src/lib/proxy.ts`:
```typescript
// If CORS issues, consider using Vercel serverless function as proxy

// api/marketstack.ts
export default async function handler(req, res) {
  const { symbol, market } = req.query;
  
  const response = await fetch(
    `http://api.marketstack.com/v1/eod/latest?access_key=${process.env.MARKETSTACK_API_KEY}&symbols=${symbol}`
  );
  
  const data = await response.json();
  res.status(200).json(data);
}
```

---

## Vercel Serverless Functions (Optional)

If you want to add backend API endpoints in Vercel:

### Create API Route

Create `code/api/stock-quote.ts`:

```typescript
import type { VercelRequest, VercelResponse } from '@vercel/node';
import axios from 'axios';

export default async function handler(
  req: VercelRequest,
  res: VercelResponse
) {
  const { symbol, market } = req.query;

  if (!symbol || !market) {
    return res.status(400).json({ error: 'Missing symbol or market' });
  }

  try {
    let marketstackSymbol = symbol as string;
    
    if (market === 'HK') {
      marketstackSymbol = `${(symbol as string).padStart(4, '0')}.XHKG`;
    } else if (market === 'CN') {
      marketstackSymbol = `${symbol}.XSHG`;
    }

    const response = await axios.get(
      'http://api.marketstack.com/v1/eod/latest',
      {
        params: {
          access_key: process.env.MARKETSTACK_API_KEY,
          symbols: marketstackSymbol,
        },
      }
    );

    return res.status(200).json(response.data);
  } catch (error: any) {
    return res.status(500).json({ error: error.message });
  }
}
```

**Install Vercel types:**
```bash
npm install -D @vercel/node
```

**Usage in frontend:**
```typescript
// Instead of calling Marketstack directly
const response = await fetch(`/api/stock-quote?symbol=AAPL&market=US`);
```

---

## Production Checklist

Before going live, verify:

### Pre-Deployment ✅

- [ ] All environment variables set in Vercel
- [ ] Supabase database schema created
- [ ] Supabase redirect URLs configured
- [ ] Google OAuth configured (if using)
- [ ] API keys valid and have quota
- [ ] Code pushed to GitHub
- [ ] Tests passing locally (`npm test`)

### Post-Deployment ✅

- [ ] Site loads without errors
- [ ] Can sign up / log in
- [ ] Can create portfolio
- [ ] Can buy stock
- [ ] Can sell stock
- [ ] Portfolio value displays
- [ ] Transaction history works
- [ ] Stock quotes load (HK, CN, US)
- [ ] AI chatbot responds
- [ ] No console errors (F12 → Console)
- [ ] Mobile responsive (test on phone)

### Performance ✅

- [ ] Lighthouse score > 90
- [ ] First Contentful Paint < 1.5s
- [ ] Time to Interactive < 3s
- [ ] No layout shifts

---

## Optimizations for Production

### 1. Enable Vercel Analytics (Free)

In your Vercel project:
1. Click **Analytics**
2. Click **Enable**

Automatically tracks:
- Page views
- Unique visitors
- Performance metrics

### 2. Enable Vercel Speed Insights

```bash
npm install @vercel/speed-insights
```

Add to `code/src/main.tsx`:
```typescript
import { SpeedInsights } from '@vercel/speed-insights/react';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
    <SpeedInsights />
  </React.StrictMode>
);
```

### 3. Enable Image Optimization

If you add images later, use Vercel's Image component:

```bash
npm install next/image
```

Or use Vite's built-in image optimization.

### 4. Configure Caching Headers

Create `code/vercel.json`:
```json
{
  "headers": [
    {
      "source": "/assets/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    }
  ]
}
```

---

## Monitoring & Logs

### View Deployment Logs

1. **Go to Vercel Dashboard**
2. **Click your project**
3. **Click "Deployments"**
4. **Click on a deployment**
5. **View logs:**
   - Build logs
   - Function logs
   - Runtime logs

### Monitor Errors

Vercel shows real-time errors in the dashboard:
1. Project → **Logs** tab
2. Filter by error level
3. See stack traces

### Add Error Tracking (Recommended)

**Option A: Vercel Web Analytics** (Built-in)
- Already enabled with Speed Insights

**Option B: Sentry** (More detailed)

```bash
npm install @sentry/react
```

```typescript
// src/main.tsx
import * as Sentry from '@sentry/react';

Sentry.init({
  dsn: 'your-sentry-dsn',
  environment: 'production',
});
```

---

## Scaling Considerations

### Vercel Free Tier Limits

- ✅ 100 GB bandwidth/month
- ✅ 100 deployments/day
- ✅ Unlimited static sites
- ✅ Serverless function executions: 100 GB-hours

**For this app:** Free tier is sufficient for 1,000-10,000 monthly users.

### If You Outgrow Free Tier

**Vercel Pro:** $20/month
- 1 TB bandwidth
- Unlimited deployments
- Better analytics
- Priority support

### Database Scaling

**Supabase Free Tier:**
- 500 MB database
- 2 GB bandwidth
- Up to 50,000 monthly active users

**If you need more:**
- Supabase Pro: $25/month (8 GB database)

---

## Security Checklist

### Before Production

- [ ] **Environment variables are secret**
  - Never commit `.env` to git
  - Only in Vercel dashboard

- [ ] **HTTPS enabled**
  - Vercel auto-enables SSL
  - All traffic encrypted

- [ ] **Supabase RLS enabled**
  - Row Level Security policies active
  - Users can only see their own data

- [ ] **API keys secured**
  - All keys in environment variables
  - Not exposed in client code

- [ ] **CORS configured**
  - Supabase allows your Vercel domain
  - No open CORS policies

- [ ] **Dependencies updated**
  - Run `npm audit`
  - Fix any vulnerabilities

### Run Security Audit

```bash
cd code
npm audit

# Fix issues automatically
npm audit fix
```

---

## Deployment Checklist Summary

### Initial Setup (One-time)

1. [ ] Create Vercel account
2. [ ] Connect GitHub repository
3. [ ] Configure build settings (root directory: `code`)
4. [ ] Add environment variables (4 variables)
5. [ ] Configure Supabase redirect URLs
6. [ ] Deploy

### Every Deployment

1. [ ] Code tested locally (`npm test`)
2. [ ] Environment variables verified
3. [ ] Push to GitHub (or run `vercel --prod`)
4. [ ] Monitor build logs
5. [ ] Test production site
6. [ ] Check for errors in logs

---

## Alternative: Deploy to Netlify

If you prefer Netlify instead:

### Quick Deploy

```bash
npm install -g netlify-cli
cd code
netlify deploy --prod
```

**Configure:**
- Build command: `npm run build`
- Publish directory: `dist`
- Add environment variables in Netlify dashboard

---

## Post-Deployment Steps

### 1. Test Everything

Visit your deployed site and test:
- [ ] Sign up with email
- [ ] Sign up with Google
- [ ] Create portfolio
- [ ] Buy stock (AAPL)
- [ ] Check holdings
- [ ] Sell stock
- [ ] View transaction history
- [ ] Get stock quote
- [ ] Ask AI question
- [ ] Test on mobile

### 2. Update Documentation

Update your README with:
- Production URL
- Any special deployment notes
- Known issues

### 3. Monitor Performance

- Check Vercel Analytics
- Monitor Supabase usage
- Monitor API quota (Marketstack, DeepSeek)

### 4. Set Up Alerts

Configure alerts for:
- Deployment failures
- High error rates
- API quota exceeded

---

## Complete Deployment Commands

Here's everything in one script:

```bash
#!/bin/bash

# Complete Deployment Script

echo "🚀 Deploying to Vercel..."
echo ""

# Step 1: Navigate to project
cd code

# Step 2: Install Vercel CLI (if not already)
npm install -g vercel

# Step 3: Login to Vercel
vercel login

# Step 4: Deploy to production
vercel --prod

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Add environment variables in Vercel dashboard"
echo "2. Redeploy after adding variables"
echo "3. Update Supabase redirect URLs"
echo "4. Test your live site"
echo ""
```

Save as `deploy.sh` and run:
```bash
chmod +x deploy.sh
./deploy.sh
```

---

## Quick Reference

### Vercel Dashboard URLs

- **Dashboard**: https://vercel.com/dashboard
- **Projects**: https://vercel.com/dashboard/projects
- **Settings**: Click project → Settings
- **Environment Variables**: Settings → Environment Variables
- **Domains**: Settings → Domains
- **Deployments**: Click project → Deployments

### Important URLs to Bookmark

- **Your Production Site**: `https://your-app.vercel.app`
- **Vercel Dashboard**: https://vercel.com/dashboard
- **Supabase Dashboard**: https://app.supabase.com
- **Marketstack Dashboard**: https://marketstack.com/dashboard
- **DeepSeek Dashboard**: https://platform.deepseek.com

---

## Advanced: CI/CD with GitHub Actions (Optional)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Vercel

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
          
      - name: Install dependencies
        run: cd code && npm install
        
      - name: Run tests
        run: cd code && npm test
        
      - name: Build
        run: cd code && npm run build
        
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v20
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.ORG_ID }}
          vercel-project-id: ${{ secrets.PROJECT_ID }}
          working-directory: ./code
```

---

## Cost Breakdown

### Free Tier (Recommended for MVP)

| Service | Free Tier | Cost |
|---------|-----------|------|
| Vercel Hosting | 100 GB bandwidth | $0 |
| Supabase Database | 500 MB, 2 GB bandwidth | $0 |
| Marketstack API | 100 calls/month | $0 |
| DeepSeek API | Check your plan | $0-5 |
| Custom Domain | N/A | $12/year |
| **Total** | | **$0-1/month** |

### If You Scale

| Service | Paid Tier | Cost |
|---------|-----------|------|
| Vercel Pro | 1 TB bandwidth | $20/month |
| Supabase Pro | 8 GB database | $25/month |
| Marketstack Standard | 10,000 calls/month | $49/month |
| DeepSeek (if needed) | Varies | $10-20/month |
| **Total** | | **$104-114/month** |

Still cheaper than old Windows hosting! ($200+/month)

---

## Success! 🎉

After completing this guide, you'll have:

✅ **Live production application** at Vercel URL  
✅ **Automatic deployments** on every push  
✅ **Environment variables** configured  
✅ **Custom domain** (if desired)  
✅ **SSL certificate** (automatic)  
✅ **Monitoring** with Vercel Analytics  
✅ **Global CDN** for fast loading worldwide  

Your stock portfolio application is now **live and accessible to users globally**!

---

## Quick Links

### Essential Links

**Deployment:**
- Vercel Signup: https://vercel.com/signup
- Vercel CLI Docs: https://vercel.com/docs/cli

**API Credentials:**
- Supabase Dashboard: https://app.supabase.com
- Marketstack Dashboard: https://marketstack.com/dashboard
- DeepSeek Platform: https://platform.deepseek.com

**Documentation:**
- Vercel Docs: https://vercel.com/docs
- Vite Deployment: https://vitejs.dev/guide/static-deploy.html
- Supabase Auth: https://supabase.com/docs/guides/auth

---

## Support

If you encounter issues:

1. **Check Vercel Deployment Logs**
   - Most issues are visible in build logs

2. **Check Browser Console**
   - F12 → Console tab
   - Look for red errors

3. **Review Environment Variables**
   - Verify all 4 variables are set
   - Check for typos

4. **Consult Documentation**
   - Vercel: https://vercel.com/docs
   - This guide: `VERCEL_DEPLOYMENT_GUIDE.md`

---

**You're ready to deploy!** 🚀

Follow Method 1 (Website) for the easiest deployment experience. Your application will be live in under 10 minutes!
