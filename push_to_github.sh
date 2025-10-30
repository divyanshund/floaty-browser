#!/bin/bash
# Script to push FloatyBrowser to GitHub
# Repository: https://github.com/divyanshund/floaty-browser

cd "/Users/divyanshu/Coding/Floaty Browser"

echo "🚀 Pushing FloatyBrowser to GitHub..."
echo ""

git push -u origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS! Your code is now on GitHub!"
    echo ""
    echo "🔗 View your repo at:"
    echo "   https://github.com/divyanshund/floaty-browser"
    echo ""
else
    echo ""
    echo "❌ Push failed. You may need to authenticate."
    echo ""
    echo "💡 If you're using HTTPS, you need a Personal Access Token:"
    echo "   1. Go to: https://github.com/settings/tokens"
    echo "   2. Generate new token (classic)"
    echo "   3. Select 'repo' scope"
    echo "   4. Copy the token"
    echo "   5. Use it as your password when pushing"
    echo ""
    echo "Or use SSH instead:"
    echo "   git remote set-url origin git@github.com:divyanshund/floaty-browser.git"
    echo "   git push -u origin main"
fi

