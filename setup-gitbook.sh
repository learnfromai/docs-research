#!/bin/bash

# GitBook Setup Script
# This script helps set up GitBook Git Sync for this repository

echo "🚀 GitBook Git Sync Setup Guide"
echo "================================="
echo ""

echo "Prerequisites:"
echo "✅ GitHub account with access to this repository"
echo "✅ GitBook account (sign up at https://www.gitbook.com)"
echo "✅ Admin/Creator permissions in GitBook"
echo ""

echo "📋 Setup Steps:"
echo ""

echo "1. Create GitBook Space:"
echo "   - Go to https://www.gitbook.com"
echo "   - Click 'New Space' or 'Create'"
echo "   - Choose 'Import from Git' or create empty space"
echo ""

echo "2. Configure Git Sync:"
echo "   - In your GitBook space, click 'Configure' in the top-right"
echo "   - Select 'GitHub Sync' from the provider list"
echo "   - Follow authentication prompts"
echo ""

echo "3. Install GitBook GitHub App:"
echo "   - Visit: https://github.com/apps/gitbook-com"
echo "   - Click 'Install' and select this repository"
echo "   - Grant necessary permissions"
echo ""

echo "4. Repository Configuration:"
echo "   - Repository: $(git config --get remote.origin.url)"
echo "   - Branch: $(git branch --show-current)"
echo "   - Root: ./ (configured in .gitbook.yaml)"
echo ""

echo "5. Initial Sync Direction:"
echo "   - Choose 'GitHub → GitBook' to import existing content"
echo "   - Or 'GitBook → GitHub' to start fresh in GitBook"
echo ""

echo "📁 Current Repository Structure:"
tree -I 'target|.git' -L 3 2>/dev/null || find . -type d -not -path './target*' -not -path './.git*' | head -20

echo ""
echo "📄 GitBook Configuration (.gitbook.yaml):"
echo "   ✅ Root directory: ./"
echo "   ✅ README: README.md"
echo "   ✅ Table of Contents: SUMMARY.md"
echo "   ✅ Redirects configured"
echo ""

echo "🔧 Troubleshooting:"
echo "   - Can't see repository? Check GitBook app permissions"
echo "   - Sync issues? Verify branch permissions and .gitbook.yaml"
echo "   - Duplicate accounts? Use GitHub sign-in to identify conflicts"
echo ""

echo "📚 Documentation:"
echo "   - GitBook Git Sync: https://docs.gitbook.com/integrations/git-sync"
echo "   - GitHub Integration: https://docs.gitbook.com/integrations/git-sync/github"
echo ""

echo "✨ Next Steps:"
echo "   1. Run this setup in GitBook"
echo "   2. Test bi-directional sync"
echo "   3. Start editing content!"
echo ""
