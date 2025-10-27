# Backend Deployment Walkthrough - Step by Step

This guide walks you through deploying your Marketstack API backend to Cloudflare Workers.

## What You're Doing

You're putting your backend code (the Marketstack proxy) onto Cloudflare's servers so your iOS app can call it from the internet.

---

## Step 1: Install Wrangler (Cloudflare's Tool)

**What is Wrangler?** It's the command-line tool that lets you deploy to Cloudflare.

### Open Terminal and run:
```bash
npm install -g wrangler
```

**What this does:** Installs Wrangler globally on your computer.

**Expected output:**
```
added 1 package in 3s
```

**How to verify it worked:**
```bash
wrangler --version
```
You should see something like: `wrangler 3.x.x`

---

## Step 2: Install Project Dependencies

### Navigate to the backend folder:
```bash
cd /Users/rileygibson/Documents/InvestmentResearchApp/backend
```

### Install dependencies:
```bash
npm install
```

**What this does:** Installs the packages needed for the project.

**Expected output:**
```
added 234 packages in 5s
```

---

## Step 3: Login to Cloudflare

```bash
wrangler login
```

**What this does:** Opens your browser to log into Cloudflare.

**What will happen:**
1. Your browser will open
2. You'll see a Cloudflare login page
3. Log in with your Cloudflare account
4. Click "Allow" to give Wrangler access
5. Browser shows "You may close this window"

**Expected terminal output:**
```
 ⛅️ wrangler 3.x.x
▲ Opening a link in your default browser: https://dash.cloudflare.com/...
✨ Successfully logged in.
```

**Don't have a Cloudflare account?**
1. Go to https://dash.cloudflare.com/sign-up
2. Sign up (it's free)
3. Then run `wrangler login` again

---

## Step 4: Create a Storage Space (KV Namespace)

**What is KV?** It's Cloudflare's key-value storage - think of it as a cache/database for your API responses.

### Create the production namespace:
```bash
wrangler kv:namespace create "CACHE"
```

**Expected output:**
```
🌀 Creating namespace with title "stock-research-api-CACHE"
✨ Success!
Add the following to your configuration file in your kv_namespaces array:
{ binding = "CACHE", id = "abc123def456ghi789jkl012mno345" }
```

### Create the preview namespace (for testing):
```bash
wrangler kv:namespace create "CACHE" --preview
```

**Expected output:**
```
🌀 Creating namespace with title "stock-research-api-CACHE_preview"
✨ Success!
Add the following to your configuration file in your kv_namespaces array:
{ binding = "CACHE", preview_id = "xyz987wvu654tsr321qpo098nml765" }
```

### ⚠️ IMPORTANT: Copy these IDs!
You'll get two IDs that look like random letters and numbers:
- **id**: `abc123def456ghi789jkl012mno345` (for production)
- **preview_id**: `xyz987wvu654tsr321qpo098nml765` (for testing)

**Write these down or keep the terminal open!**

---

## Step 5: Update Configuration with KV IDs

Now you need to put those IDs into your config file.

### Open the config file:
```bash
open wrangler.toml
```

This will open the file in your default text editor.

### Find this section:
```toml
[[kv_namespaces]]
binding = "CACHE"
id = "your_kv_namespace_id_here"
```

### Replace it with YOUR IDs:
```toml
[[kv_namespaces]]
binding = "CACHE"
id = "abc123def456ghi789jkl012mno345"
preview_id = "xyz987wvu654tsr321qpo098nml765"
```

**Use the ACTUAL IDs from Step 4!** (not the examples above)

### Save the file and close it

---

## Step 6: Store Your API Key Securely

This stores your Marketstack API key on Cloudflare (encrypted, never visible).

```bash
wrangler secret put MARKETSTACK_API_KEY
```

**What will happen:**
```
Enter a secret value:
```

**Type this exactly:**
```
9dba12fdfa1a0d703eeec5a6123044f1
```

Then press Enter.

**Expected output:**
```
🌀 Creating the secret for the Worker "stock-research-api"
✨ Success! Uploaded secret MARKETSTACK_API_KEY
```

**What this does:** Stores your API key on Cloudflare's servers (encrypted). Your worker can use it, but no one can see it.

---

## Step 7: Test Locally (Optional but Recommended)

Before deploying to the internet, test it on your computer.

```bash
npm run dev
```

**Expected output:**
```
⛅️ wrangler 3.x.x
Your worker has access to the following bindings:
- KV Namespaces:
  - CACHE: xyz987wvu654tsr321qpo098nml765
⎔ Starting local server...
[wrangler:inf] Ready on http://localhost:8787
```

**Leave this running and open a NEW terminal window.**

### In the new terminal, test it:
```bash
curl http://localhost:8787/api/health
```

**Expected output:**
```json
{"status":"healthy","timestamp":"2024-10-26T..."}
```

### Test a real stock quote:
```bash
curl http://localhost:8787/api/quote/AAPL
```

**Expected output:**
```json
{
  "symbol": "AAPL",
  "currentPrice": 178.50,
  "change": 1.25,
  ...
}
```

**If these work, you're ready to deploy!**

Go back to the first terminal and press `Ctrl+C` to stop the local server.

---

## Step 8: Deploy to Cloudflare

This is the big moment - putting your code live on the internet!

```bash
npm run deploy
```

**Expected output:**
```
⛅️ wrangler 3.x.x
Total Upload: 2.34 KiB / gzip: 0.95 KiB
Uploaded stock-research-api (1.23 sec)
Published stock-research-api (0.45 sec)
  https://stock-research-api.YOURNAME.workers.dev
Current Deployment ID: abcd1234-5678-90ef-ghij-klmnopqrstuv
```

**Look for the URL!** It will be something like:
```
https://stock-research-api.YOURNAME.workers.dev
```

**Copy this URL - you'll need it for your iOS app!**

---

## Step 9: Test Your Live Deployment

Replace `YOUR_WORKER_URL` with the URL from Step 8:

```bash
curl https://stock-research-api.YOURNAME.workers.dev/api/health
```

**Expected output:**
```json
{"status":"healthy","timestamp":"2024-10-26T..."}
```

### Test a real quote:
```bash
curl https://stock-research-api.YOURNAME.workers.dev/api/quote/AAPL
```

**If this returns stock data, YOU'RE DONE!** 🎉

---

## Step 10: Update Your iOS App (If URL is Different)

**Only if** your worker URL is different from `https://my-stock-api.stock-research-api.workers.dev`:

### Open this file in Xcode:
`ios/Test App/MarketDataService.swift`

### Find this line (line 8):
```swift
init(apiBaseURL: String = "https://my-stock-api.stock-research-api.workers.dev") {
```

### Replace with YOUR worker URL:
```swift
init(apiBaseURL: String = "https://stock-research-api.YOURNAME.workers.dev") {
```

### Save and rebuild your iOS app.

---

## Troubleshooting

### "wrangler: command not found"
**Solution:** Install Wrangler:
```bash
npm install -g wrangler
```

### "You must be logged in"
**Solution:** Run:
```bash
wrangler login
```

### "KV namespace not found"
**Solution:** Make sure you:
1. Ran `wrangler kv:namespace create "CACHE"`
2. Copied the ID into `wrangler.toml`
3. Saved the file

### "Secret not found"
**Solution:** Run:
```bash
wrangler secret put MARKETSTACK_API_KEY
```
Enter: `9dba12fdfa1a0d703eeec5a6123044f1`

### "Cannot find module"
**Solution:** Run:
```bash
cd backend
npm install
```

### "Network error" when testing
**Solution:**
1. Check your internet connection
2. Try the deploy again: `npm run deploy`

---

## What You've Accomplished

✅ Installed Cloudflare's deployment tool (Wrangler)
✅ Created a cache storage space (KV Namespace)
✅ Configured your worker with the cache IDs
✅ Stored your API key securely
✅ Deployed your code to Cloudflare's global network
✅ Your API is now live on the internet!

Your iOS app can now call:
- `https://YOUR_WORKER_URL/api/quote/AAPL`
- `https://YOUR_WORKER_URL/api/eod/AAPL?limit=30`
- `https://YOUR_WORKER_URL/api/intraday/AAPL`

---

## Next Steps

1. **Add MarketDataService.swift to Xcode**
   - Drag `ios/Test App/MarketDataService.swift` into your Xcode project

2. **Update the URL if needed** (see Step 10)

3. **Use it in your app:**
   ```swift
   let marketData = MarketDataService()
   let quote = try await marketData.fetchQuote(symbol: "AAPL")
   ```

---

## Monitoring Your Worker

### View live requests:
```bash
cd backend
npm run tail
```

This shows you real-time logs of requests hitting your worker.

### View analytics:
1. Go to https://dash.cloudflare.com
2. Click "Workers & Pages"
3. Click "stock-research-api"
4. See graphs of requests, errors, CPU time

---

## Costs

- **Cloudflare Workers**: FREE (100,000 requests per day)
- **Cloudflare KV**: FREE (100,000 reads per day)
- **Marketstack API**: Depends on your plan

With caching, you'll likely stay in the free tier for both Cloudflare services!

---

## Need Help?

If you get stuck, tell me:
1. Which step you're on
2. The exact command you ran
3. The error message you got

I'll help you fix it!
