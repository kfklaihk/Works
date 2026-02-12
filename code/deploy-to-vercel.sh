#!/bin/bash

echo "=================================================="
echo "  Stock Portfolio App - Vercel Deployment"
echo "=================================================="
echo ""

# Check if vercel is installed
if ! command -v vercel &> /dev/null; then
    echo "❌ Vercel CLI not found"
    echo ""
    echo "Installing Vercel CLI..."
    npm install -g vercel
    echo ""
fi

echo "✅ Vercel CLI ready"
echo ""

# Check if in correct directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found"
    echo "Please run this script from the 'code/' directory"
    exit 1
fi

echo "✅ In correct directory"
echo ""

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "⚠️  Warning: .env file not found"
    echo ""
    echo "Creating .env from template..."
    cp .env.example .env
    echo ""
    echo "📝 Please edit .env and add your credentials:"
    echo "   - VITE_SUPABASE_URL"
    echo "   - VITE_SUPABASE_ANON_KEY"
    echo "   - VITE_DEEPSEEK_API_KEY"
    echo ""
    echo "After editing, run this script again."
    exit 1
fi

echo "✅ Environment file exists"
echo ""

# Run tests
echo "🧪 Running tests..."
npm test -- --run

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Tests failed!"
    echo "Please fix failing tests before deploying."
    exit 1
fi

echo ""
echo "✅ All tests passed!"
echo ""

# Build locally to verify
echo "🔨 Building application..."
npm run build

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Build failed!"
    echo "Please fix build errors before deploying."
    exit 1
fi

echo ""
echo "✅ Build successful!"
echo ""

# Deploy
echo "🚀 Deploying to Vercel..."
echo ""
echo "You will be asked to:"
echo "1. Login to Vercel (if not already)"
echo "2. Confirm project settings"
echo "3. Add environment variables in Vercel dashboard after first deploy"
echo ""
read -p "Press Enter to continue..."

vercel --prod

if [ $? -eq 0 ]; then
    echo ""
    echo "=================================================="
    echo "  ✅ Deployment Successful!"
    echo "=================================================="
    echo ""
    echo "Next steps:"
    echo "1. Add environment variables in Vercel dashboard:"
    echo "   - VITE_SUPABASE_URL"
    echo "   - VITE_SUPABASE_ANON_KEY"
    echo "   - VITE_MARKETSTACK_API_KEY"
    echo "   - VITE_DEEPSEEK_API_KEY"
    echo ""
    echo "2. Redeploy after adding variables"
    echo ""
    echo "3. Update Supabase redirect URLs with your Vercel domain"
    echo ""
    echo "4. Test your live site!"
    echo ""
else
    echo ""
    echo "❌ Deployment failed"
    echo "Check the error messages above"
fi
