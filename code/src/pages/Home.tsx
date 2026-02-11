import { Container, Typography, AppBar, Toolbar, Button, Box, Alert } from '@mui/material';
import { useAuth } from '../hooks/useAuth';
import { StockQuote } from '../components/StockQuote';
import { AIHelper } from '../components/AIHelper';
import { LogOut } from 'lucide-react';

export function Home() {
  const { user, signOut } = useAuth();

  return (
    <>
      {/* App Bar */}
      <AppBar position="static" elevation={2}>
        <Toolbar>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1, fontWeight: 'bold' }}>
            📊 Stock Portfolio Manager
          </Typography>
          <Typography variant="body2" sx={{ mr: 2, display: { xs: 'none', sm: 'block' } }}>
            {user?.email}
          </Typography>
          <Button
            color="inherit"
            onClick={signOut}
            startIcon={<LogOut size={18} />}
            variant="outlined"
            sx={{ borderColor: 'rgba(255, 255, 255, 0.5)' }}
          >
            Sign Out
          </Button>
        </Toolbar>
      </AppBar>

      {/* Main Content */}
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        {/* Welcome Section */}
        <Box sx={{ mb: 4 }}>
          <Typography variant="h4" gutterBottom fontWeight="bold">
            Welcome back! 👋
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Track and manage your stock portfolio across Hong Kong, China, and US markets.
          </Typography>
        </Box>

        {/* Info Alert */}
        <Alert severity="info" sx={{ mb: 3 }}>
          <Typography variant="body2">
            <strong>End-of-Day (EOD) Data:</strong> Stock prices shown are from the previous trading day's close.
            Data is sourced from Marketstack API and updated daily.
          </Typography>
        </Alert>

        {/* Stock Quote Section */}
        <StockQuote />

        {/* Features Preview */}
        <Box sx={{ mt: 4, p: 3, bgcolor: 'grey.50', borderRadius: 2 }}>
          <Typography variant="h6" gutterBottom fontWeight="bold">
            ✨ Available Features
          </Typography>
          <Box component="ul" sx={{ pl: 2 }}>
            <Typography component="li" variant="body2" sx={{ mb: 1 }}>
              📈 <strong>Real-time Stock Quotes:</strong> Get end-of-day prices for HK, CN, and US stocks
            </Typography>
            <Typography component="li" variant="body2" sx={{ mb: 1 }}>
              🤖 <strong>AI Stock Assistant:</strong> Click the chat icon to ask questions about stocks and investing
            </Typography>
            <Typography component="li" variant="body2" sx={{ mb: 1 }}>
              🔒 <strong>Secure Authentication:</strong> Your data is protected with Supabase authentication
            </Typography>
            <Typography component="li" variant="body2" sx={{ mb: 1 }}>
              💾 <strong>Data Caching:</strong> Efficient caching reduces API calls and improves performance
            </Typography>
          </Box>
        </Box>

        {/* How to Use */}
        <Box sx={{ mt: 3, p: 3, bgcolor: 'primary.50', borderRadius: 2, border: 1, borderColor: 'primary.200' }}>
          <Typography variant="h6" gutterBottom fontWeight="bold" color="primary.main">
            🚀 How to Use
          </Typography>
          <Box component="ol" sx={{ pl: 2 }}>
            <Typography component="li" variant="body2" sx={{ mb: 1 }}>
              Enter a stock symbol (e.g., <code>0005</code> for HSBC, <code>AAPL</code> for Apple)
            </Typography>
            <Typography component="li" variant="body2" sx={{ mb: 1 }}>
              Select the market (Hong Kong, China, or US)
            </Typography>
            <Typography component="li" variant="body2" sx={{ mb: 1 }}>
              Click "Get Quote" to fetch the latest end-of-day data
            </Typography>
            <Typography component="li" variant="body2" sx={{ mb: 1 }}>
              Click the floating chat icon (bottom right) to ask the AI assistant questions
            </Typography>
          </Box>
        </Box>

        {/* Market Info */}
        <Box sx={{ mt: 3, display: 'flex', gap: 2, flexWrap: 'wrap' }}>
          <Box sx={{ flex: 1, minWidth: 250, p: 2, bgcolor: 'error.50', borderRadius: 1 }}>
            <Typography variant="subtitle2" fontWeight="bold" color="error.main">
              🇭🇰 Hong Kong Market
            </Typography>
            <Typography variant="caption" display="block" sx={{ mt: 1 }}>
              Use 4-digit codes (e.g., 0005, 0700, 0941)
            </Typography>
          </Box>
          <Box sx={{ flex: 1, minWidth: 250, p: 2, bgcolor: 'warning.50', borderRadius: 1 }}>
            <Typography variant="subtitle2" fontWeight="bold" color="warning.main">
              🇨🇳 China Market
            </Typography>
            <Typography variant="caption" display="block" sx={{ mt: 1 }}>
              Use 6-digit codes (e.g., 600000, 601398)
            </Typography>
          </Box>
          <Box sx={{ flex: 1, minWidth: 250, p: 2, bgcolor: 'success.50', borderRadius: 1 }}>
            <Typography variant="subtitle2" fontWeight="bold" color="success.main">
              🇺🇸 US Market
            </Typography>
            <Typography variant="caption" display="block" sx={{ mt: 1 }}>
              Use ticker symbols (e.g., AAPL, MSFT, GOOGL)
            </Typography>
          </Box>
        </Box>
      </Container>

      {/* AI Helper Chatbot */}
      <AIHelper />
    </>
  );
}
