# Copy this file to approval.local.ps1 and adjust the values for your machine.
# This machine stores only the approval service settings and approver identity.
# Keep the MFA/TOTP seed on your phone authenticator only, not on your PCs.
$env:PERSONAL_TOOLS_APPROVAL_MODE = 'required'
$env:PERSONAL_TOOLS_SUPABASE_URL = 'https://YOUR_PROJECT_REF.supabase.co'
$env:PERSONAL_TOOLS_SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY'
$env:PERSONAL_TOOLS_APPROVER_EMAIL = 'you@example.com'
# Optional hosted page, for example GitHub Pages with SSL. If omitted, the local HTML page is used.
$env:PERSONAL_TOOLS_APPROVAL_PAGE_URL = 'https://YOURNAME.github.io/personal-tools/'
$env:PERSONAL_TOOLS_APPROVAL_TIMEOUT_SEC = '300'
